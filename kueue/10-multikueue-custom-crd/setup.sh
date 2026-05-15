#!/usr/bin/env bash
# setup.sh
# Creates two Kind clusters (kueue-manager + kueue-worker-1), installs
# cert-manager + Kueue, builds the ComputeTask controller image, loads it
# into the worker cluster, and wires MultiKueue.
#
# Prerequisites:
#   kind, kubectl, helm, docker, go (1.23+) must be on PATH.
#
# Usage:
#   bash setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTROLLER_DIR="${SCRIPT_DIR}/controller"
KUEUE_VERSION="0.17.2"
IMAGE_NAME="computetask-controller"
IMAGE_TAG="latest"

# ── Helper: install cert-manager + Kueue via Helm ────────────────────────────
install_kueue() {
  local context="$1"
  local values_file="$2"
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

# ── Helper: extract worker kubeconfig and store as Secret on manager ─────────
# Kind writes 127.0.0.1 in kubeconfigs for local access, but the Kueue
# controller pod inside the manager cluster needs the worker's Docker bridge IP.
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
kind create cluster --name kueue-worker-1 --config "${SCRIPT_DIR}/kind-worker.yaml"
kubectl wait deploy/coredns -n kube-system --for=condition=available --timeout=5m --context kind-kueue-worker-1

# ── 2. Apply the ComputeTask CRD to both clusters ────────────────────────────
echo "==> Installing ComputeTask CRD on both clusters..."
for ctx in kind-kueue-manager kind-kueue-worker-1; do
  kubectl apply -f "${SCRIPT_DIR}/00-computetask-crd.yaml" --context "${ctx}"
done

# ── 3. Install Kueue on both clusters ────────────────────────────────────────
echo "==> Installing Kueue on both clusters..."
install_kueue "kind-kueue-manager"  "${SCRIPT_DIR}/values.yaml"
install_kueue "kind-kueue-worker-1" "${SCRIPT_DIR}/values.yaml"

# ── 4. Build the ComputeTask controller image ─────────────────────────────────
echo "==> Building ComputeTask controller image..."
# go mod tidy is run first to ensure go.sum is complete.
(cd "${CONTROLLER_DIR}" && go mod tidy)
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" "${CONTROLLER_DIR}"

# ── 5. Load the controller image into the worker Kind cluster ─────────────────
# The manager cluster runs no Pods, so we only need the image on the worker.
echo "==> Loading controller image into kueue-worker-1..."
kind load docker-image "${IMAGE_NAME}:${IMAGE_TAG}" --name kueue-worker-1

# ── 6. Extract worker kubeconfig and store as Secret on manager ───────────────
echo "==> Creating worker kubeconfig secret on manager..."
create_worker_secret "kueue-worker-1" "kueue-worker-1-kubeconfig"

echo ""
echo "==> Setup complete! Two clusters are ready:"
echo "    kind-kueue-manager  (policy + MultiKueue + CRD)"
echo "    kind-kueue-worker-1 (compute capacity + controller)"
echo ""
echo "Next steps:"
echo ""
echo "  # 1. Apply MultiKueue wiring (manager only)"
echo "  kubectl apply -f 01-multikueue-objects.yaml --context kind-kueue-manager"
echo ""
echo "  # 2. Apply ClusterQueues (each to their own cluster)"
echo "  kubectl apply -f 02-manager-clusterqueue.yaml --context kind-kueue-manager"
echo "  kubectl apply -f 03-worker-clusterqueue.yaml  --context kind-kueue-worker-1"
echo ""
echo "  # 3. Apply Namespace + LocalQueue to both clusters"
echo "  for ctx in kind-kueue-manager kind-kueue-worker-1; do"
echo "    kubectl apply -f 04-namespace-localqueue.yaml --context \$ctx"
echo "  done"
echo ""
echo "  # 4. Deploy the ComputeTask controller on the worker"
echo "  kubectl apply -f 05-controller-worker.yaml --context kind-kueue-worker-1"
echo "  kubectl wait deploy/computetask-controller -n computetask-system \\"
echo "    --for=condition=available --timeout=3m --context kind-kueue-worker-1"
echo ""
echo "  # 5. Submit a ComputeTask to the manager cluster"
echo "  kubectl create -f 06-computetask.yaml --context kind-kueue-manager"
echo ""
echo "  See README.md for the full walkthrough."
