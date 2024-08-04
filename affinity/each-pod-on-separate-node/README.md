# 1. Pod Anti Affinity

- [1. Pod Anti Affinity](#1-pod-anti-affinity)
  - [1.1. Create a multinode cluster using KinD](#11-create-a-multinode-cluster-using-kind)
  - [1.2. Create deployment](#12-create-deployment)
  - [1.3. Manipulate Deployment](#13-manipulate-deployment)
  - [1.4. Monitoring](#14-monitoring)


Create a cluster with 3 worker nodes.

Deploy an app with 3 replicas/pods.

Each pod should get scheduled on separate worker node. In other words, no 2 pods should be scheduled on the same worker node.

## 1.1. Create a multinode cluster using KinD

```
kind create cluster --config kind.yaml
kubectl get pods --all-namespaces
```

## 1.2. Create deployment

```
kubectl apply -f deploy.yaml
```

## 1.3. Manipulate Deployment

```
kubectl scale --replicas=5 deploy/whoami
```
The 2 new pods should not get scheduled since there are no nodes to schedule them.

## 1.4. Monitoring

```
kubectl get nodes --show-labels
kubectl get pod -o wide
```