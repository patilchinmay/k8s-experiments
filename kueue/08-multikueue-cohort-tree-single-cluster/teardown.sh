#!/usr/bin/env bash
# teardown.sh
# Cleans up all resources created during the MultiKueue + Cohort Tree +
# Single Cluster experiment.
# Run this after you are done with the experiment.

set -euo pipefail

MANAGER_CTX="kind-kueue-manager"
WORKER1_CTX="kind-kueue-worker-1"

# ---------------------------------------------------------------------------
# Clean up manager cluster resources
# ---------------------------------------------------------------------------
echo "==> [manager] Deleting JobSets and Workloads in namespace team-ml..."
kubectl delete jobsets --all -n team-ml --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete workloads --all -n team-ml --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting LocalQueue in namespace team-ml..."
kubectl delete localqueue ml-queue -n team-ml --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting namespace team-ml..."
kubectl delete namespace team-ml --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting JobSets and Workloads in namespace team-platform..."
kubectl delete jobsets --all -n team-platform --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete workloads --all -n team-platform --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting LocalQueue in namespace team-platform..."
kubectl delete localqueue platform-queue -n team-platform --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting namespace team-platform..."
kubectl delete namespace team-platform --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting WorkloadPriorityClasses..."
kubectl delete workloadpriorityclass high-priority low-priority --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting ClusterQueues..."
kubectl delete clusterqueue team-ml-cq team-platform-cq --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting Cohorts..."
kubectl delete cohort org-root team-ml-cohort team-platform-cohort --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting ResourceFlavors..."
kubectl delete resourceflavor default-flavor --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting AdmissionCheck..."
kubectl delete admissioncheck multikueue-check --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting MultiKueueConfig..."
kubectl delete multikueueconfig multikueue-config --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting MultiKueueCluster..."
kubectl delete multikueuecluster kueue-worker-1 --ignore-not-found --context "${MANAGER_CTX}"

echo "==> [manager] Deleting worker kubeconfig Secret from kueue-system..."
kubectl delete secret kueue-worker-1-kubeconfig \
  -n kueue-system --ignore-not-found --context "${MANAGER_CTX}"

# ---------------------------------------------------------------------------
# Clean up worker cluster
# ---------------------------------------------------------------------------
echo ""
echo "==> [kueue-worker-1] Deleting JobSets and Workloads in namespace team-ml..."
kubectl delete jobsets --all -n team-ml --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete workloads --all -n team-ml --ignore-not-found --context "${WORKER1_CTX}"

echo "==> [kueue-worker-1] Deleting LocalQueue in namespace team-ml..."
kubectl delete localqueue ml-queue -n team-ml --ignore-not-found --context "${WORKER1_CTX}"

echo "==> [kueue-worker-1] Deleting namespace team-ml..."
kubectl delete namespace team-ml --ignore-not-found --context "${WORKER1_CTX}"

echo "==> [kueue-worker-1] Deleting JobSets and Workloads in namespace team-platform..."
kubectl delete jobsets --all -n team-platform --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete workloads --all -n team-platform --ignore-not-found --context "${WORKER1_CTX}"

echo "==> [kueue-worker-1] Deleting LocalQueue in namespace team-platform..."
kubectl delete localqueue platform-queue -n team-platform --ignore-not-found --context "${WORKER1_CTX}"

echo "==> [kueue-worker-1] Deleting namespace team-platform..."
kubectl delete namespace team-platform --ignore-not-found --context "${WORKER1_CTX}"

echo "==> [kueue-worker-1] Deleting ClusterQueues..."
kubectl delete clusterqueue team-ml-cq team-platform-cq --ignore-not-found --context "${WORKER1_CTX}"

echo "==> [kueue-worker-1] Deleting ResourceFlavors..."
kubectl delete resourceflavor default-flavor --ignore-not-found --context "${WORKER1_CTX}"

echo ""
echo "✅ Experiment teardown complete."
echo ""
echo "Kueue is still installed on both clusters. To remove the clusters entirely:"
echo "  kind delete cluster --name kueue-manager"
echo "  kind delete cluster --name kueue-worker-1"
