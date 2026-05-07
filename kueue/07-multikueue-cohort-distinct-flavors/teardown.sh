#!/usr/bin/env bash
# teardown.sh
# Cleans up all resources created during the MultiKueue + Cohort +
# Distinct Flavors + Preemption experiment.
# Run this after you are done with the experiment.

set -euo pipefail

MANAGER_CTX="kind-kueue-manager"
WORKER1_CTX="kind-kueue-worker-1"
WORKER2_CTX="kind-kueue-worker-2"

# ---------------------------------------------------------------------------
# Clean up manager cluster resources
# ---------------------------------------------------------------------------
for TEAM in team-a team-b; do
  echo "==> [manager] Deleting JobSets and Workloads in namespace ${TEAM}..."
  kubectl delete jobsets --all -n "${TEAM}" --ignore-not-found --context "${MANAGER_CTX}"
  kubectl delete workloads --all -n "${TEAM}" --ignore-not-found --context "${MANAGER_CTX}"

  echo "==> [manager] Deleting LocalQueue in namespace ${TEAM}..."
  kubectl delete localqueue "${TEAM}-queue" -n "${TEAM}" --ignore-not-found --context "${MANAGER_CTX}"

  echo "==> [manager] Deleting namespace ${TEAM}..."
  kubectl delete namespace "${TEAM}" --ignore-not-found --context "${MANAGER_CTX}"
done

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
# Clean up worker clusters
# ---------------------------------------------------------------------------
for CTX in "${WORKER1_CTX}" "${WORKER2_CTX}"; do
  LABEL="${CTX#kind-}"

  for TEAM in team-a team-b; do
    echo "==> [${LABEL}] Deleting JobSets and Workloads in namespace ${TEAM}..."
    kubectl delete jobsets --all -n "${TEAM}" --ignore-not-found --context "${CTX}"
    kubectl delete workloads --all -n "${TEAM}" --ignore-not-found --context "${CTX}"

    echo "==> [${LABEL}] Deleting LocalQueue in namespace ${TEAM}..."
    kubectl delete localqueue "${TEAM}-queue" -n "${TEAM}" --ignore-not-found --context "${CTX}"

    echo "==> [${LABEL}] Deleting namespace ${TEAM}..."
    kubectl delete namespace "${TEAM}" --ignore-not-found --context "${CTX}"
  done

  echo "==> [${LABEL}] Deleting ClusterQueues..."
  kubectl delete clusterqueue --all --context "${CTX}" --ignore-not-found

  echo "==> [${LABEL}] Deleting ResourceFlavors..."
  kubectl delete resourceflavor --all --context "${CTX}" --ignore-not-found
done

echo ""
echo "✅ Experiment teardown complete."
echo ""
echo "Kueue is still installed on all three clusters. To remove the clusters entirely:"
echo "  kind delete cluster --name kueue-manager"
echo "  kind delete cluster --name kueue-worker-1"
echo "  kind delete cluster --name kueue-worker-2"
