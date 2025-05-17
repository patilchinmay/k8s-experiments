# Working Together with Taints, Toleration, Affinity and Preference

- [Working Together with Taints, Toleration, Affinity and Preference](#working-together-with-taints-toleration-affinity-and-preference)
  - [1. Create Cluster](#1-create-cluster)
  - [2. Create Pods](#2-create-pods)
  - [3. Observations](#3-observations)
    - [Pod to Node Mapping](#pod-to-node-mapping)
    - [Scheduling Logic Details](#scheduling-logic-details)
      - [Node Constraints](#node-constraints)
      - [Key Scheduling Factors](#key-scheduling-factors)
      - [Fallback Scenarios](#fallback-scenarios)

This experiment demonstrates Kubernetes' powerful scheduling mechanisms using a combination of node affinity (to attract pods to specific nodes), scheduling preference and taints/tolerations (to repel pods from nodes unless they have specific permissions).

## 1. Create Cluster

```bash
kind create cluster --config kind.yaml
```

## 2. Create Pods

```bash
kubectl apply -f deploy.yaml
```

## 3. Observations

### Pod to Node Mapping

| Deployment | Pod | Likely Node(s) | Explanation |
|------------|-----|----------------|-------------|
| consume-reservation-1 | consume-reservation-1-xxx-1 | reservation-1-node-1 or reservation-1-node-2 | This pod has **required** nodeAffinity for `allocation=reserved` AND `node.kubernetes.io/instance-type=kind-node-1`. It also has **preferred** nodeAffinity with weight 50 for `reservation-id=reservation-1`. Additionally, it has tolerations for both `reservation-1` and `reservation-2` tainted nodes. With the higher weight preference for reservation-1 nodes, it will likely schedule on these nodes first. |
| consume-reservation-1 | consume-reservation-1-xxx-2 | reservation-1-node-1 or reservation-1-node-2 | Same reasoning as above. The second replica will also prefer reservation-1 nodes. |
| consume-reservation-2 | consume-reservation-2-xxx-1 | reservation-2-node-1 or reservation-2-node-2 | This pod has **required** nodeAffinity for `allocation=reserved` AND `node.kubernetes.io/instance-type=kind-node-1`. It also has **preferred** nodeAffinity with weight 50 for `reservation-id=reservation-2`. Additionally, it has tolerations for both `reservation-1` and `reservation-2` tainted nodes. With the higher weight preference for reservation-2 nodes, it will likely schedule on these nodes first. |
| consume-reservation-2 | consume-reservation-2-xxx-2 | reservation-2-node-1 or reservation-2-node-2 | Same reasoning as above. The second replica will also prefer reservation-2 nodes. |
| consume-ondemand | consume-ondemand-xxx-1 | ondemand-node-1 | This pod has **required** nodeAffinity for `allocation=on-demand` AND `node.kubernetes.io/instance-type=kind-node-1`. It doesn't have any tolerations for the tainted reserved nodes. It will only schedule on the on-demand node. |
| consume-ondemand | consume-ondemand-xxx-2 | ondemand-node-1 | Same reasoning as above. The second replica will also only schedule on the on-demand node. |

### Scheduling Logic Details

#### Node Constraints

- **ondemand-node-1**: Has labels `allocation=on-demand` and `node.kubernetes.io/instance-type=kind-node-1`. No taints.
- **reservation-1-node-1, reservation-1-node-2**: Both have labels `allocation=reserved`, `node.kubernetes.io/instance-type=kind-node-1`, and `reservation-id=reservation-1`. Both have taint `reservation-id=reservation-1:NoSchedule`.
- **reservation-2-node-1, reservation-2-node-2**: Both have labels `allocation=reserved`, `node.kubernetes.io/instance-type=kind-node-1`, and `reservation-id=reservation-2`. Both have taint `reservation-id=reservation-2:NoSchedule`.

#### Key Scheduling Factors

1. **consume-reservation-1**:
   - Requires nodes with `allocation=reserved` AND `node.kubernetes.io/instance-type=kind-node-1`
   - Prefers nodes with `reservation-id=reservation-1` (weight 50)
   - Prefers nodes with `reservation-id=reservation-2` (weight 25) as a fallback
   - Has tolerations for both reservation-1 and reservation-2 tainted nodes
   - Result: Will be scheduled on reservation-1 nodes due to higher preference weight

2. **consume-reservation-2**:
   - Requires nodes with `allocation=reserved` AND `node.kubernetes.io/instance-type=kind-node-1`
   - Prefers nodes with `reservation-id=reservation-2` (weight 50)
   - Prefers nodes with `reservation-id=reservation-1` (weight 25) as a fallback
   - Has tolerations for both reservation-1 and reservation-2 tainted nodes
   - Result: Will be scheduled on reservation-2 nodes due to higher preference weight

3. **consume-ondemand**:
   - Requires nodes with `allocation=on-demand` AND `node.kubernetes.io/instance-type=kind-node-1`
   - Has no tolerations for reserved nodes
   - Result: Will only be scheduled on the on-demand node

#### Fallback Scenarios

In the unlikely event that the preferred nodes are fully occupied:

- **consume-reservation-1** pods could fall back to reservation-2 nodes since they have a lower-weight preference and the necessary tolerations
- **consume-reservation-2** pods could fall back to reservation-1 nodes since they have a lower-weight preference and the necessary tolerations
- **consume-ondemand** pods have no fallback and would remain pending if the on-demand node is full
