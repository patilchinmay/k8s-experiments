#!/usr/bin/env bash
# setup.sh
# Creates a Kind cluster and installs cert-manager + Kueue for the
# borrowing-with-distinct-flavors experiment.
# Run from within this directory: bash setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Create cluster
# ---------------------------------------------------------------------------
kind create cluster --name kueue-cluster --config "${SCRIPT_DIR}/kind.yaml"

# Set context and confirm cluster is reachable
kubectl cluster-info --context kind-kueue-cluster

# Wait for CoreDNS to be available before proceeding with any installs
kubectl wait deploy/coredns -n kube-system --for=condition=available --timeout=5m

# Show node/pod state now that the cluster is confirmed ready
kubectl get nodes
kubectl get pod -n kube-system

# ---------------------------------------------------------------------------
# Install cert-manager
# ---------------------------------------------------------------------------
helm install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.20.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

# cert-manager has 3 deployments; the webhook must be fully ready before
# Kueue's Helm install runs (Kueue registers ValidatingWebhookConfigurations
# that cert-manager's cainjector needs to patch).
kubectl wait deploy/cert-manager -n cert-manager --for=condition=available --timeout=5m
kubectl wait deploy/cert-manager-cainjector -n cert-manager --for=condition=available --timeout=5m
kubectl wait deploy/cert-manager-webhook -n cert-manager --for=condition=available --timeout=5m

# ---------------------------------------------------------------------------
# Install Kueue
# https://github.com/kubernetes-sigs/kueue/blob/main/charts/kueue/README.md
# ---------------------------------------------------------------------------
helm install kueue oci://registry.k8s.io/kueue/charts/kueue \
  --version=0.17.0 \
  --namespace kueue-system \
  --create-namespace \
  --wait --timeout 300s \
  --values "${SCRIPT_DIR}/values.yaml"

echo ""
echo "✅ Cluster and Kueue are ready."
echo "   Context: kind-kueue-cluster"
echo "   Run the experiment: see kueue/04-borrowing-with-distinct-flavors/README.md"
