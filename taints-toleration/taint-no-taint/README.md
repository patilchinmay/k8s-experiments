# 1. Taints and Toleration

- [1. Taints and Toleration](#1-taints-and-toleration)
  - [1.1. Create a multinode cluster using KinD](#11-create-a-multinode-cluster-using-kind)
  - [1.2. Create both deployment](#12-create-both-deployment)
  - [1.3. Check which pods are scheduled](#13-check-which-pods-are-scheduled)
  - [1.4. Cleanup](#14-cleanup)


Create a 3 node cluster. Each node should have taint `nvidia.com/gpu=true:NoSchedule` on it.

Create 2 deployments. One with and one without toleration.

The toleration is:
```yaml
tolerations:
  - effect: NoSchedule
    key: nvidia.com/gpu
    operator: Exists
```

Determine the behaviour.

## 1.1. Create a multinode cluster using KinD

```
kind create cluster --config kind.yaml

kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints[*].key'
```

## 1.2. Create both deployment

```
kubectl apply -f deploy-tolerations.yaml

kubectl apply -f deploy-no-tolerations.yaml
```

## 1.3. Check which pods are scheduled

```
❯ kubectl get pods
NAME                                      READY   STATUS    RESTARTS   AGE
whoami-555ff55675-shh6b                   0/1     Pending   0          24s
whoami-555ff55675-zh6vl                   0/1     Pending   0          24s
whoami-with-tolerations-9b9c4fd59-68dks   1/1     Running   0          29s
whoami-with-tolerations-9b9c4fd59-7stgg   1/1     Running   0          29s

❯ kdc po whoami-555ff55675-shh6b
<...>
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  2m4s  default-scheduler  0/4 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 3 node(s) had untolerated taint {nvidia.com/gpu: true}. preemption: 0/4 nodes are available: 4 Preemption is not helpful for scheduling..

```

**This clears that if a node has a taint, a pod/deployment must have the matching toleration defined to be scheduled on that node.**

**If there is no matching toleration, the pod/deployment will not get scheduled on the node with taint.**

## 1.4. Cleanup

Delete all cluster policies.

`kubectl delete deploy --all`

Delete Cluster

`kind delete cluster`