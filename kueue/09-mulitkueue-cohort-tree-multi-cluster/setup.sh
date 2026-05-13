#!/usr/bin/env bash
# setup.sh
# Creates three Kind clusters (kueue-manager + kueue-worker-1 + kueue-worker-2)
# and installs cert-manager + Kueue + all job-framework CRDs on all clusters.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUEUE_VERSION="0.17.0"
JOBSET_VERSION="v0.11.1"

install_kueue() {
  local context="$1"
  local values_file="$2"
  # Install cert-manager first, wait for it, then install Kueue via Helm
  helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
    --version v1.20.2 --namespace cert-manager --create-namespace \
    --set crds.enabled=true --kube-context "${context}"
  kubectl wait deploy/cert-manager            -n cert-manager --for=condition=available --timeout=5m --context "${context}"
  kubectl wait deploy/cert-manager-cainjector  -n cert-manager --for=condition=available --timeout=5m --context "${context}"
  kubectl wait deploy/cert-manager-webhook    -n cert-manager --for=condition=available --timeout=5m --context "${context}"
  helm install kueue oci://registry.k8s.io/kueue/charts/kueue \
    --version="${KUEUE_VERSION}" --namespace kueue-system --create-namespace \
    --wait --timeout 300s --values "${values_file}" --kube-context "${context}"
}

install_crds() {
  local context="$1"
  helm install jobset oci://registry.k8s.io/jobset/charts/jobset \
    --version "${JOBSET_VERSION#v}" --namespace jobset-system --create-namespace \
    --wait --timeout 300s --kube-context "${context}"
}

create_worker_secret() {
  local worker_name="$1"
  local secret_name="$2"
  local manager_context="kind-kueue-manager"
  local cp_container="${worker_name}-control-plane"
  local worker_cp_ip
  worker_cp_ip=$(docker inspect "${cp_container}" \
    --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
  local tmp_file="/tmp/${secret_name}.yaml"
  kind get kubeconfig --name "${worker_name}" --internal | \
    sed "s|https://${worker_name}-control-plane:6443|https://${worker_cp_ip}:6443|g" \
    > "${tmp_file}"
  kubectl create secret generic "${secret_name}" \
    --from-file=kubeconfig="${tmp_file}" \
    --namespace kueue-system --context "${manager_context}" \
    --dry-run=client -o yaml | kubectl apply -f - --context "${manager_context}"
  rm -f "${tmp_file}"
}

# ── 1. Create clusters ────────────────────────────────────────────────────────
echo "==> Creating kueue-manager cluster..."
kind create cluster --name kueue-manager --config "${SCRIPT_DIR}/kind-manager.yaml"
kubectl wait deploy/coredns -n kube-system --for=condition=available --timeout=5m --context kind-kueue-manager

echo "==> Creating kueue-worker-1 cluster..."
kind create cluster --name kueue-worker-1 --config "${SCRIPT_DIR}/kind-worker-1.yaml"
kubectl wait deploy/coredns -n kube-system --for=condition=available --timeout=5m --context kind-kueue-worker-1

echo "==> Creating kueue-worker-2 cluster..."
kind create cluster --name kueue-worker-2 --config "${SCRIPT_DIR}/kind-worker-2.yaml"
kubectl wait deploy/coredns -n kube-system --for=condition=available --timeout=5m --context kind-kueue-worker-2

# ── 2. Install job-framework CRDs on all clusters ────────────────────────────
echo "==> Installing JobSet CRDs on all clusters..."
install_crds "kind-kueue-manager"
install_crds "kind-kueue-worker-1"
install_crds "kind-kueue-worker-2"

# ── 3. Install Kueue on all clusters ─────────────────────────────────────────
echo "==> Installing Kueue on all clusters..."
install_kueue "kind-kueue-manager"  "${SCRIPT_DIR}/values.yaml"
install_kueue "kind-kueue-worker-1" "${SCRIPT_DIR}/values.yaml"
install_kueue "kind-kueue-worker-2" "${SCRIPT_DIR}/values.yaml"

# ── 4. Extract worker kubeconfigs and store as Secrets on manager ─────────────
echo "==> Creating worker kubeconfig secrets on manager..."
create_worker_secret "kueue-worker-1" "kueue-worker-1-kubeconfig"
create_worker_secret "kueue-worker-2" "kueue-worker-2-kubeconfig"

echo ""
echo "==> Setup complete! Three clusters are ready:"
echo "    kind-kueue-manager  (policy + MultiKueue)"
echo "    kind-kueue-worker-1 (team-ml primary capacity)"
echo "    kind-kueue-worker-2 (team-platform primary capacity)"
echo ""
echo "Next steps:"
echo "  kubectl apply -f 01-multikueue-objects.yaml   --context kind-kueue-manager"
echo "  kubectl apply -f 02-manager-clusterqueues.yaml --context kind-kueue-manager"
echo "  kubectl apply -f 03-worker-1-clusterqueues.yaml --context kind-kueue-worker-1"
echo "  kubectl apply -f 04-worker-2-clusterqueues.yaml --context kind-kueue-worker-2"
echo "  for ctx in kind-kueue-manager kind-kueue-worker-1 kind-kueue-worker-2; do"
echo "    kubectl apply -f 05-namespaces-localqueues.yaml --context \$ctx"
echo "  done"
