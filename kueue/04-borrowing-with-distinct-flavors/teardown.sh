#!/usr/bin/env bash
# teardown.sh
# Cleans up all resources created during the borrowing-with-distinct-flavors experiment.
# Run this after you are done with the experiment.

set -euo pipefail

for TEAM in team-a team-b; do
  echo "==> Deleting all Jobs in namespace ${TEAM}..."
  kubectl delete jobs --all -n "${TEAM}" --ignore-not-found

  echo "==> Deleting all Workloads in namespace ${TEAM}..."
  kubectl delete workloads --all -n "${TEAM}" --ignore-not-found

  echo "==> Deleting LocalQueue in namespace ${TEAM}..."
  kubectl delete localqueue "${TEAM}-queue" -n "${TEAM}" --ignore-not-found

  echo "==> Deleting namespace ${TEAM}..."
  kubectl delete namespace "${TEAM}" --ignore-not-found
done

echo "==> Deleting ClusterQueues..."
kubectl delete clusterqueue --all

echo "==> Deleting ResourceFlavors..."
kubectl delete resourceflavor --all

echo "==> Deleting PriorityClasses..."
kubectl delete priorityclass high-priority low-priority --ignore-not-found

echo ""
echo "✅ Experiment teardown complete."
echo ""
echo "Kueue itself is still installed. To remove the entire cluster run:"
echo "  kind delete cluster --name kueue-cluster"
