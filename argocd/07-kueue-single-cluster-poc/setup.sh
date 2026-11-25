#!/usr/bin/env bash
# setup.sh
# Creates a Kind cluster and installs Kueue + the kueue-resources chart for the
# single-cluster borrowing / lending / preemption experiment.
# Run from within this directory: bash setup.sh
#
# Idempotent: re-run it after editing any values file to apply the change
# (the Kueue controller is restarted so config changes always take effect).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="kueue-poc"
CTX="kind-${CLUSTER_NAME}"
KUEUE_DIR="${SCRIPT_DIR}/kueue"
KUEUE_VERSION="$(sed -n 's/^kueueVersion: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "${KUEUE_DIR}/controller/values.yaml")"

for bin in kind kubectl docker helm; do
  command -v "${bin}" >/dev/null || { echo "ERROR: ${bin} not found"; exit 1; }
done

# ---------------------------------------------------------------------------
# Create cluster (skipped if it already exists)
# ---------------------------------------------------------------------------
CLUSTER_EXISTED=true
if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  CLUSTER_EXISTED=false
  kind create cluster --name "${CLUSTER_NAME}" --config "${SCRIPT_DIR}/kind.yaml"
fi

kubectl cluster-info --context "${CTX}"

# Wait for CoreDNS to be available before proceeding with any installs
kubectl wait deploy/coredns -n kube-system --for=condition=available --timeout=5m --context "${CTX}"

kubectl get nodes --context "${CTX}"

# ---------------------------------------------------------------------------
# Prepare nodes and namespaces
# ---------------------------------------------------------------------------
# Node label matched by the `default` ResourceFlavor
# (kueue/resources/overlays/dev/kueue-poc/values.yaml).
kubectl label node "${CLUSTER_NAME}-worker" karpenter.sh/nodepool=cpu-nodes --overwrite --context "${CTX}"

# Team namespaces are created outside the kueue-resources chart (as in the real clusters).
for ns in team-a team-b; do
  kubectl create namespace "${ns}" --dry-run=client -o yaml --context "${CTX}" | \
    kubectl apply -f - --context "${CTX}"
done

# ---------------------------------------------------------------------------
# Install Kueue controller
# https://github.com/kubernetes-sigs/kueue/blob/main/charts/kueue/README.md
# ---------------------------------------------------------------------------
helm upgrade --install kueue oci://registry.k8s.io/kueue/charts/kueue \
  --version "${KUEUE_VERSION}" \
  --namespace kueue-system \
  --create-namespace \
  --wait --timeout 300s \
  --kube-context "${CTX}" \
  --values "${KUEUE_DIR}/controller/values.yaml"

# Config lives in a ConfigMap; restart so a changed config is picked up on re-runs.
if [ "${CLUSTER_EXISTED}" = true ]; then
  kubectl rollout restart deploy/kueue-controller-manager -n kueue-system --context "${CTX}"
fi
kubectl rollout status deploy/kueue-controller-manager -n kueue-system --timeout=5m --context "${CTX}"

# ---------------------------------------------------------------------------
# Install Kueue resources (cohort, priority classes, flavors, ClusterQueues, LocalQueues)
# Values: base/values.yaml + overlays/dev/kueue-poc/values.yaml (experiment knobs)
# ---------------------------------------------------------------------------
# The Kueue webhooks may need a moment after the controller (re)starts, so retry.
for _ in $(seq 1 15); do
  if helm upgrade --install kueue-resources "${KUEUE_DIR}/resources/charts/kueue-resources" \
    --namespace kueue-system \
    --kube-context "${CTX}" \
    --values "${KUEUE_DIR}/resources/base/values.yaml" \
    --values "${KUEUE_DIR}/resources/overlays/dev/kueue-poc/values.yaml"; then
    RESOURCES_OK=true
    break
  fi
  sleep 4
done
[ "${RESOURCES_OK:-false}" = true ] || { echo "ERROR: could not install kueue-resources"; exit 1; }

kubectl get clusterqueue,localqueue -A --context "${CTX}"

echo ""
echo "✅ Cluster, Kueue and queues are ready."
echo "   Context: ${CTX}"
echo "   Run the experiment: see argocd/07-kueue-single-cluster-poc/README.md"
