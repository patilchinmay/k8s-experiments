# Pod Anti Affinity

Create a cluster with 3 worker nodes.

Deploy an app with 3 replicas/pods.

Each pod should get scheduled on separate worker node. In other words, no 2 pods should be scheduled on the same worker node.

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
The 2 new pods should not get scheduled since there are no nodes to schedule them.

## Monitoring

```
kubectl get nodes --show-labels
kubectl get pod -o wide
```