#!/usr/bin/env bash
# teardown.sh
# Cleans up all resources created during the Kueue experiment.
# Run this after you are done with the experiment.

set -euo pipefail

echo "==> Deleting all Jobs in namespace team-a..."
kubectl delete jobs --all -n team-a --ignore-not-found

echo "==> Deleting all Workloads in namespace team-a..."
kubectl delete workloads --all -n team-a --ignore-not-found

echo "==> Deleting LocalQueue..."
kubectl delete localqueue team-a-queue -n team-a --ignore-not-found

echo "==> Deleting namespace team-a..."
kubectl delete namespace team-a --ignore-not-found

echo "==> Deleting ClusterQueue..."
kubectl delete clusterqueue cluster-queue --ignore-not-found

echo "==> Deleting ResourceFlavors..."
kubectl delete resourceflavor type-1-flavor type-2-flavor type-3-flavor --ignore-not-found

echo ""
echo "✅ Experiment teardown complete."
echo ""
echo "Kueue itself is still installed. To remove the entire cluster run:"
echo "  kind delete cluster --name kueue-cluster"
