# Vertical Pod Autoscaler

- [Vertical Pod Autoscaler](#vertical-pod-autoscaler)
- [Process](#process)
  - [Create basic resources](#create-basic-resources)
  - [Install Metrics Server](#install-metrics-server)
  - [Install VPA](#install-vpa)
  - [Deploy VPA](#deploy-vpa)
  - [Create load. Watch usage.](#create-load-watch-usage)


Create a deployment in a kind cluster.

Deploy Metrics Server and Vertical Pod Autoscaler.

Observe that the VPA has changed the resource request/limit in the pod.

Reference:
- https://www.kubecost.com/kubernetes-autoscaling/kubernetes-vpa/
- https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler


# Process

## Create basic resources

```
kind create cluster --config kind.yaml
kubectl apply -f deployment.yaml
```

## Install Metrics Server

```
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install --set args={--kubelet-insecure-tls} metrics-server metrics-server/metrics-server --namespace kube-system
```
## Install VPA

https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler#installation

## Deploy VPA

```
kubectl apply -f vpa.yaml
```

## Create load. Watch usage.

```
watch -n 1 kubectl get pod
watch -n 1 kubectl top pod
```

After about 5 minutes, VPA recreates the pods while increasing the values under requests' cpu and memory fields.

