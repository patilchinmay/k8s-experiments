#!/usr/bin/env bash
# teardown.sh
# Cleans up all resources created during the MultiKueue experiment.
# Run this after you are done with the experiment.

set -euo pipefail

MANAGER_CTX="kind-kueue-manager"
WORKER_CTX="kind-kueue-worker"

# ---------------------------------------------------------------------------
# Clean up manager cluster resources
# ---------------------------------------------------------------------------
echo "==> [manager] Deleting Jobs and Workloads in namespace team-a..."
kubectl delete jobs --all -n team-a --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete workloads --all -n team-a --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting LocalQueue..."
kubectl delete localqueue team-a-queue -n team-a --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting namespace team-a..."
kubectl delete namespace team-a --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting ClusterQueues..."
kubectl delete clusterqueue --all --context "${MANAGER_CTX}" --ignore-not-found

echo "==> [manager] Deleting ResourceFlavors..."
kubectl delete resourceflavor --all --context "${MANAGER_CTX}" --ignore-not-found

echo "==> [manager] Deleting AdmissionCheck..."
kubectl delete admissioncheck multikueue-check --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting MultiKueueConfig..."
kubectl delete multikueueconfig multikueue-config --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting MultiKueueCluster..."
kubectl delete multikueuecluster kueue-worker --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting worker kubeconfig Secret from kueue-system..."
kubectl delete secret kueue-worker-kubeconfig -n kueue-system --ignore-not-found --context "${MANAGER_CTX}"

# ---------------------------------------------------------------------------
# Clean up worker cluster resources
# ---------------------------------------------------------------------------
echo ""
echo "==> [worker] Deleting Jobs and Workloads in namespace team-a..."
kubectl delete jobs --all -n team-a --ignore-not-found --context "${WORKER_CTX}"
kubectl delete workloads --all -n team-a --ignore-not-found --context "${WORKER_CTX}"

echo "==> [worker] Deleting LocalQueue..."
kubectl delete localqueue team-a-queue -n team-a --ignore-not-found --context "${WORKER_CTX}"

echo "==> [worker] Deleting namespace team-a..."
kubectl delete namespace team-a --ignore-not-found --context "${WORKER_CTX}"

echo "==> [worker] Deleting ClusterQueues..."
kubectl delete clusterqueue --all --context "${WORKER_CTX}" --ignore-not-found

echo "==> [worker] Deleting ResourceFlavors..."
kubectl delete resourceflavor --all --context "${WORKER_CTX}" --ignore-not-found

echo ""
echo "✅ Experiment teardown complete."
echo ""
echo "Kueue is still installed on both clusters. To remove the clusters entirely:"
echo "  kind delete cluster --name kueue-manager"
echo "  kind delete cluster --name kueue-worker"
