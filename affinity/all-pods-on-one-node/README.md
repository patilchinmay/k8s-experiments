# Pod Anti Affinity

- [Pod Anti Affinity](#pod-anti-affinity)
  - [Create a multinode EKS cluster using KinD](#create-a-multinode-eks-cluster-using-kind)
  - [Create deployment](#create-deployment)
  - [Manipulate Deployment](#manipulate-deployment)
  - [Monitoring](#monitoring)


Create a cluster with 3 worker nodes.

Deploy an app with 3 replicas/pods.

All 3 pods should get scheduled on the same node.

## Create a multinode EKS cluster using KinD

```
kind create cluster --config kind.yaml
kubectl get pods --all-namespaces
```

## Create deployment

```
kubectl apply -f deploy.yaml
```

## Manipulate Deployment

```
kubectl scale --replicas=5 deploy/whoami
```
The 2 new pods should get scheduled on the same node as previous 3 pods.

## Monitoring

```
kubectl get nodes --show-labels
kubectl get pod -o wide
```