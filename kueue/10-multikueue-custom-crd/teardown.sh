#!/usr/bin/env bash
# teardown.sh — removes all experiment resources from both clusters.
# Leaves the clusters running and Kueue installed.

set -euo pipefail

MANAGER_CTX="kind-kueue-manager"
WORKER1_CTX="kind-kueue-worker-1"

echo "==> Cleaning up manager cluster..."
kubectl delete computetasks --all -n team-compute     --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete workloads    --all -n team-compute     --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete localqueue compute-queue -n team-compute --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete namespace team-compute                 --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete clusterqueue compute-cq                --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete resourceflavor default-flavor          --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete admissioncheck multikueue-check        --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete multikueueconfig multikueue-config     --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete multikueuecluster kueue-worker-1       --ignore-not-found --context "${MANAGER_CTX}"
kubectl delete secret kueue-worker-1-kubeconfig \
  -n kueue-system --ignore-not-found --context "${MANAGER_CTX}"

echo "==> Cleaning up worker-1 cluster..."
kubectl delete pods         --all -n team-compute     --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete computetasks --all -n team-compute     --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete workloads    --all -n team-compute     --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete localqueue compute-queue -n team-compute --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete namespace team-compute                 --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete namespace computetask-system           --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete clusterqueue compute-cq                --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete resourceflavor default-flavor          --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete clusterrole    computetask-controller  --ignore-not-found --context "${WORKER1_CTX}"
kubectl delete clusterrolebinding computetask-controller --ignore-not-found --context "${WORKER1_CTX}"

echo "==> Teardown complete. Kueue and the controller image are still installed."
echo ""
echo "To also delete the Kind clusters:"
echo "  kind delete cluster --name kueue-manager"
echo "  kind delete cluster --name kueue-worker-1"
