#!/usr/bin/env bash
# teardown.sh
# Cleans up all resources created during the MultiKueue + JobSet + Priority experiment.
# Run this after you are done with the experiment.

set -euo pipefail

MANAGER_CTX="kind-kueue-manager"
WORKER1_CTX="kind-kueue-worker-1"
WORKER2_CTX="kind-kueue-worker-2"

# ---------------------------------------------------------------------------
# Clean up manager cluster resources
# ---------------------------------------------------------------------------
echo "==> [manager] Deleting JobSets and Workloads in namespace team-a..."
kubectl delete jobsets --all -n team-a --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete workloads --all -n team-a --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting LocalQueue..."
kubectl delete localqueue team-a-queue -n team-a --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting namespace team-a..."
kubectl delete namespace team-a --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting WorkloadPriorityClasses..."
kubectl delete workloadpriorityclass high-priority low-priority --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting ClusterQueues..."
kubectl delete clusterqueue --all --context "${MANAGER_CTX}" --ignore-not-found

echo "==> [manager] Deleting ResourceFlavors..."
kubectl delete resourceflavor --all --context "${MANAGER_CTX}" --ignore-not-found

echo "==> [manager] Deleting AdmissionCheck..."
kubectl delete admissioncheck multikueue-check --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting MultiKueueConfig..."
kubectl delete multikueueconfig multikueue-config --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting MultiKueueClusters..."
kubectl delete multikueuecluster kueue-worker-1 kueue-worker-2 --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting worker kubeconfig Secrets from kueue-system..."
kubectl delete secret kueue-worker-1-kubeconfig kueue-worker-2-kubeconfig \
  -n kueue-system --ignore-not-found --context "${MANAGER_CTX}"

# ---------------------------------------------------------------------------
# Clean up worker cluster 1 resources
# ---------------------------------------------------------------------------
echo ""
echo "==> [worker-1] Deleting JobSets and Workloads in namespace team-a..."
kubectl delete jobsets --all -n team-a --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete workloads --all -n team-a --ignore-not-found --context "${WORKER1_CTX}"

echo "==> [worker-1] Deleting LocalQueue..."
kubectl delete localqueue team-a-queue -n team-a --ignore-not-found --context "${WORKER1_CTX}"

echo "==> [worker-1] Deleting namespace team-a..."
kubectl delete namespace team-a --ignore-not-found --context "${WORKER1_CTX}"

echo "==> [worker-1] Deleting ClusterQueues..."
kubectl delete clusterqueue --all --context "${WORKER1_CTX}" --ignore-not-found

echo "==> [worker-1] Deleting ResourceFlavors..."
kubectl delete resourceflavor --all --context "${WORKER1_CTX}" --ignore-not-found

# ---------------------------------------------------------------------------
# Clean up worker cluster 2 resources
# ---------------------------------------------------------------------------
echo ""
echo "==> [worker-2] Deleting JobSets and Workloads in namespace team-a..."
kubectl delete jobsets --all -n team-a --ignore-not-found --context "${WORKER2_CTX}"
kubectl delete workloads --all -n team-a --ignore-not-found --context "${WORKER2_CTX}"

echo "==> [worker-2] Deleting LocalQueue..."
kubectl delete localqueue team-a-queue -n team-a --ignore-not-found --context "${WORKER2_CTX}"

echo "==> [worker-2] Deleting namespace team-a..."
kubectl delete namespace team-a --ignore-not-found --context "${WORKER2_CTX}"

echo "==> [worker-2] Deleting ClusterQueues..."
kubectl delete clusterqueue --all --context "${WORKER2_CTX}" --ignore-not-found

echo "==> [worker-2] Deleting ResourceFlavors..."
kubectl delete resourceflavor --all --context "${WORKER2_CTX}" --ignore-not-found

echo ""
echo "✅ Experiment teardown complete."
echo ""
echo "Kueue is still installed on all three clusters. To remove the clusters entirely:"
echo "  kind delete cluster --name kueue-manager"
echo "  kind delete cluster --name kueue-worker-1"
echo "  kind delete cluster --name kueue-worker-2"
