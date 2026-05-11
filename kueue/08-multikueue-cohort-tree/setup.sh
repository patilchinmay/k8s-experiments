#!/usr/bin/env bash
# setup.sh
# Creates three Kind clusters (kueue-manager + kueue-worker-1 + kueue-worker-2)
# and installs cert-manager + Kueue + JobSet CRDs on all clusters
# for the MultiKueue + Cohort Tree + Quotas in Cohorts + Borrowing/Preemption experiment.
# Run from within this directory: bash setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUEUE_VERSION="0.17.0"
JOBSET_VERSION="v0.11.1"

# ---------------------------------------------------------------------------
# Helper: install cert-manager + Kueue on a given context
# ---------------------------------------------------------------------------
install_kueue() {
  local context="$1"
  local values_file="$2"
  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "  Installing cert-manager + Kueue on context: ${context}"
  echo "══════════════════════════════════════════════════════════════════"

  helm install \
    cert-manager oci://quay.io/jetstack/charts/cert-manager \
    --version v1.20.2 \
    --namespace cert-manager \
    --create-namespace \
    --set crds.enabled=true \
    --kube-context "${context}"

  kubectl wait deploy/cert-manager           -n cert-manager --for=condition=available --timeout=5m --context "${context}"
  kubectl wait deploy/cert-manager-cainjector -n cert-manager --for=condition=available --timeout=5m --context "${context}"
  kubectl wait deploy/cert-manager-webhook   -n cert-manager --for=condition=available --timeout=5m --context "${context}"

  helm install kueue oci://registry.k8s.io/kueue/charts/kueue \
    --version="${KUEUE_VERSION}" \
    --namespace kueue-system \
    --create-namespace \
    --wait --timeout 300s \
    --values "${values_file}" \
    --kube-context "${context}"
}

# ---------------------------------------------------------------------------
# Helper: install JobSet CRDs on a given context.
# MultiKueue requires the JobSet CRD to exist on all clusters.
# ---------------------------------------------------------------------------
install_crds() {
  local context="$1"
  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "  Installing job-framework CRDs on context: ${context}"
  echo "══════════════════════════════════════════════════════════════════"

  echo "  -> JobSet ${JOBSET_VERSION}"
  helm install jobset oci://registry.k8s.io/jobset/charts/jobset \
    --version "${JOBSET_VERSION#v}" \
    --namespace jobset-system \
    --create-namespace \
    --wait --timeout 300s \
    --kube-context "${context}"

  echo "  CRDs installed on ${context}"
}

# ---------------------------------------------------------------------------
# Helper: extract a worker cluster's kubeconfig, rewrite the API server
# address from 127.0.0.1 to the container's Docker bridge IP, and store it
# as a Secret in kueue-system on the manager cluster.
# ---------------------------------------------------------------------------
create_worker_secret() {
  local worker_name="$1"        # e.g. kueue-worker-1
  local secret_name="$2"        # e.g. kueue-worker-1-kubeconfig
  local manager_context="kind-kueue-manager"

  echo ""
  echo "==> Extracting kubeconfig for ${worker_name} and creating Secret on manager..."

  local cp_container="${worker_name}-control-plane"
  local worker_cp_ip
  worker_cp_ip=$(docker inspect "${cp_container}" \
    --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

  echo "   ${worker_name} control-plane IP: ${worker_cp_ip}"

  local tmp_file="/tmp/${secret_name}.yaml"

  kind get kubeconfig --name "${worker_name}" --internal | \
    sed "s|https://${worker_name}-control-plane:6443|https://${worker_cp_ip}:6443|g" \
    > "${tmp_file}"

  kubectl create secret generic "${secret_name}" \
    --from-file=kubeconfig="${tmp_file}" \
    --namespace kueue-system \
    --context "${manager_context}" \
    --dry-run=client -o yaml | \
    kubectl apply -f - --context "${manager_context}"

  rm -f "${tmp_file}"
  echo "   Secret ${secret_name} created in kueue-system on manager"
}

# ---------------------------------------------------------------------------
# 1. Create the manager cluster
# ---------------------------------------------------------------------------
echo "==> Creating manager cluster (kueue-manager)..."
kind create cluster --name kueue-manager --config "${SCRIPT_DIR}/kind-manager.yaml"
kubectl cluster-info --context kind-kueue-manager
kubectl wait deploy/coredns -n kube-system --for=condition=available --timeout=5m --context kind-kueue-manager

# ---------------------------------------------------------------------------
# 2. Create worker cluster 1 (GPU)
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating worker cluster 1 (kueue-worker-1, GPU)..."
kind create cluster --name kueue-worker-1 --config "${SCRIPT_DIR}/kind-worker-1.yaml"
kubectl cluster-info --context kind-kueue-worker-1
kubectl wait deploy/coredns -n kube-system --for=condition=available --timeout=5m --context kind-kueue-worker-1

# ---------------------------------------------------------------------------
# 3. Create worker cluster 2 (CPU)
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating worker cluster 2 (kueue-worker-2, CPU)..."
kind create cluster --name kueue-worker-2 --config "${SCRIPT_DIR}/kind-worker-2.yaml"
kubectl cluster-info --context kind-kueue-worker-2
kubectl wait deploy/coredns -n kube-system --for=condition=available --timeout=5m --context kind-kueue-worker-2

# ---------------------------------------------------------------------------
# 4. Install job-framework CRDs on ALL clusters
# ---------------------------------------------------------------------------
install_crds "kind-kueue-manager"
install_crds "kind-kueue-worker-1"
install_crds "kind-kueue-worker-2"

# ---------------------------------------------------------------------------
# 5. Install Kueue on all clusters
# ---------------------------------------------------------------------------
install_kueue "kind-kueue-manager"  "${SCRIPT_DIR}/values.yaml"
install_kueue "kind-kueue-worker-1" "${SCRIPT_DIR}/values.yaml"
install_kueue "kind-kueue-worker-2" "${SCRIPT_DIR}/values.yaml"

# ---------------------------------------------------------------------------
# 6. Extract worker kubeconfigs and store as Secrets on the manager
# ---------------------------------------------------------------------------
create_worker_secret "kueue-worker-1" "kueue-worker-1-kubeconfig"
create_worker_secret "kueue-worker-2" "kueue-worker-2-kubeconfig"

echo ""
echo "All three clusters and Kueue are ready."
echo ""
echo "   Manager context  : kind-kueue-manager"
echo "   Worker 1 context : kind-kueue-worker-1  (gpu node: node-type=gpu)"
echo "   Worker 2 context : kind-kueue-worker-2  (cpu node: node-type=cpu)"
echo ""
echo "   Worker kubeconfig Secrets created in kueue-system on manager:"
echo "     kueue-worker-1-kubeconfig"
echo "     kueue-worker-2-kubeconfig"
echo ""
echo "   Next: follow the experiment README.md"
