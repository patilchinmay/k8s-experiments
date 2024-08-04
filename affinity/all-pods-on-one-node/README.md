# 1. Pod Anti Affinity

- [1. Pod Anti Affinity](#1-pod-anti-affinity)
  - [1.1. Create a multinode cluster using KinD](#11-create-a-multinode-cluster-using-kind)
  - [1.2. Create deployment](#12-create-deployment)
  - [1.3. Manipulate Deployment](#13-manipulate-deployment)
  - [1.4. Monitoring](#14-monitoring)


Create a cluster with 3 worker nodes.

Deploy an app with 3 replicas/pods.

All 3 pods should get scheduled on the same node.

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
The 2 new pods should get scheduled on the same node as previous 3 pods.

## 1.4. Monitoring

```
kubectl get nodes --show-labels
kubectl get pod -o wide
```