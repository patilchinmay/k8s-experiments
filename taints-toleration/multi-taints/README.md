# 1. Multiple Taints and Tolerations

- [1. Multiple Taints and Tolerations](#1-multiple-taints-and-tolerations)
  - [1.1. Create a multinode cluster using KinD](#11-create-a-multinode-cluster-using-kind)
  - [1.2. Create deployments](#12-create-deployments)
  - [1.3. Results](#13-results)
  - [1.4. Cleanup](#14-cleanup)


Create a 3 node cluster. Each node should have 2 taints on it:
- `taint/one=true:NoSchedule` 
- `taint/two=true:NoSchedule`

Create 4 deployments with varying tolerations.

| Deployment Name |               Tolerations               |
| :-------------: | :-------------------------------------: |
|     match-1     |            Matches one taint            |
|     match-2     |           Matches both taints           |
| match-1-extra-1 | Matches one taint, Has one extra taint  |
| match-2-extra-1 | Matches two taints, Has one extra taint |


Determine the behavior.

## 1.1. Create a multinode cluster using KinD

```
kind create cluster --config kind.yaml

kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints[*].key,VALUE:.spec.taints[*].value,EFFECT:.spec.taints[*].effect'
```

## 1.2. Create deployments

```
kubectl apply -f match-1.yaml

kubectl apply -f match-2.yaml

kubectl apply -f match-1-extra-1.yaml

kubectl apply -f match-2-extra-1.yaml
```

## 1.3. Results

| Deployment Name |               Tolerations               |        Results         |
| :-------------: | :-------------------------------------: | :--------------------: |
|     match-1     |            Matches one taint            | Pods weren't scheduled |
|     match-2     |           Matches both taints           |  Pods WERE scheduled   |
| match-1-extra-1 | Matches one taint, Has one extra taint  | Pods weren't scheduled |
| match-2-extra-1 | Matches two taints, Has one extra taint |  Pods WERE scheduled   |

**Pods are only scheduled when ALL taints have matching tolerations.**

**If pods have extra tolerations that are not present on the nodes, pods are still scheduled.**

**If there are any lacking tolerations, pods are not scheduled.**

## 1.4. Cleanup

Delete all cluster policies.

`kubectl delete deploy --all`

Delete Cluster

`kind delete cluster`