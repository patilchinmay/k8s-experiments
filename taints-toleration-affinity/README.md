# Working Together with Taints, Toleration And Affinity

- [Working Together with Taints, Toleration And Affinity](#working-together-with-taints-toleration-and-affinity)
  - [1. Create Cluster](#1-create-cluster)
  - [2. Create Pods](#2-create-pods)
  - [3. Observations](#3-observations)
    - [Node Overview](#node-overview)
    - [Pod to Node Scheduling Matrix](#pod-to-node-scheduling-matrix)
    - [Scheduling Logic Explanation](#scheduling-logic-explanation)

This experiment demonstrates Kubernetes' powerful scheduling mechanisms using a combination of node affinity (to attract pods to specific nodes) and taints/tolerations (to repel pods from nodes unless they have specific permissions).

## 1. Create Cluster

```bash
kind create cluster --config kind.yaml
```

## 2. Create Pods

```bash
kubectl apply -f pods.yaml
```

## 3. Observations

### Node Overview

| Node Name | Role | Labels | Taints |
|-----------|------|--------|--------|
| control-plane | control-plane | N/A | N/A |
| ondemand-1 | worker | allocation=on-demand, node.kubernetes.io/instance-type=kind-node-1 | None |
| ondemand-2 | worker | allocation=on-demand, node.kubernetes.io/instance-type=kind-node-1 | None |
| ondemand-3 | worker | allocation=on-demand, node.kubernetes.io/instance-type=kind-node-2 | None |
| ondemand-4 | worker | allocation=on-demand, node.kubernetes.io/instance-type=kind-node-3 | None |
| reserved-1 | worker | allocation=reserved, node.kubernetes.io/instance-type=kind-node-1 | reservation-id=reservation-id-1:NoSchedule |
| reserved-2 | worker | allocation=reserved, node.kubernetes.io/instance-type=kind-node-1 | reservation-id=reservation-id-2:NoSchedule |
| reserved-3 | worker | allocation=reserved, node.kubernetes.io/instance-type=kind-node-2 | reservation-id=reservation-id-1:NoSchedule |
| reserved-4 | worker | allocation=reserved, node.kubernetes.io/instance-type=kind-node-2 | reservation-id=reservation-id-2:NoSchedule |

### Pod to Node Scheduling Matrix

| Pod Name/Node name | control-plane | ondemand-1 | ondemand-2 | ondemand-3 | ondemand-4 | reserved-1 | reserved-2 | reserved-3 | reserved-4 | Reason |
|----------|---------------|------------|------------|------------|------------|------------|------------|------------|------------|--------|
| ondemand-pod-1 | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Requires nodes with label `allocation=on-demand` and `node.kubernetes.io/instance-type=kind-node-1`. Will be scheduled on either ondemand-1 or ondemand-2. |
| ondemand-pod-2 | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Requires nodes with label `allocation=on-demand` and `node.kubernetes.io/instance-type=kind-node-1`. Will be scheduled on either ondemand-1 or ondemand-2. |
| no-toleration-unschedulable | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Requires nodes with label `allocation=reserved` and `node.kubernetes.io/instance-type=kind-node-1` but lacks the tolerations for the taints on reserved-1 and reserved-2. Cannot be scheduled anywhere. |
| reserved-pod-1 | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | Requires nodes with label `allocation=reserved` and `node.kubernetes.io/instance-type=kind-node-1`, and has toleration only for reservation-id-1. Will only be scheduled on reserved-1. |
| reserved-pod-2 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | Requires nodes with label `allocation=reserved` and `node.kubernetes.io/instance-type=kind-node-1`, and has toleration only for reservation-id-2. Will only be scheduled on reserved-2. |
| reserved-pod-3 | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | Requires nodes with label `allocation=reserved` and `node.kubernetes.io/instance-type=kind-node-1`, and has tolerations for both reservation-id-1 and reservation-id-2. Can be scheduled on either reserved-1 or reserved-2. |

### Scheduling Logic Explanation

1. **Node Affinity**: Determines which nodes are candidates for pod scheduling based on node labels.
   - Pods with `allocation=on-demand` affinity can only be scheduled on `ondemand-1`, `ondemand-2`, `ondemand-3` and `ondemand-4` nodes.
   - Pods with `allocation=reserved` affinity can only be scheduled on `reserved-1`, `reserved-2`, `reserved-3` and `reserved-4` nodes.
   - Similarly for the label `node.kubernetes.io/instance-type=xxx`.

2. **Taints and Tolerations**: Further restrict scheduling based on node taints.
   - Reserved nodes have taints with `reservation-id` keys.
   - Only pods with matching tolerations can be scheduled on these tainted nodes.
   - Pods without proper tolerations will remain unschedulable even if they match node affinity requirements.
