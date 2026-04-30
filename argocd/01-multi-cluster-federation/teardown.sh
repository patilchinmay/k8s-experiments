#!/usr/bin/env bash
# teardown.sh
# Deletes all three kind clusters created by setup.sh.
# Run from within this directory: bash teardown.sh

set -euo pipefail

echo "==> Deleting kind cluster: argocd-master..."
kind delete cluster --name argocd-master || true

echo "==> Deleting kind cluster: argocd-worker-1..."
kind delete cluster --name argocd-worker-1 || true

echo "==> Deleting kind cluster: argocd-worker-2..."
kind delete cluster --name argocd-worker-2 || true

echo ""
echo "✅ All clusters deleted."
