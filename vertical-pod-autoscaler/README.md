# 1. Vertical Pod Autoscaler

- [1. Vertical Pod Autoscaler](#1-vertical-pod-autoscaler)
- [2. Process](#2-process)
  - [2.1. Create basic resources](#21-create-basic-resources)
  - [2.2. Install Metrics Server](#22-install-metrics-server)
  - [2.3. Install VPA](#23-install-vpa)
  - [2.4. Deploy VPA](#24-deploy-vpa)
  - [2.5. Create load. Watch usage.](#25-create-load-watch-usage)
  - [2.6. References](#26-references)


Create a deployment in a kind cluster.

Deploy Metrics Server and Vertical Pod Autoscaler.

Observe that the VPA has changed the resource request/limit in the pod.

# 2. Process

## 2.1. Create basic resources

```
kind create cluster --config kind.yaml
kubectl apply -f deployment.yaml
```

## 2.2. Install Metrics Server

```
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install --set args={--kubelet-insecure-tls} metrics-server metrics-server/metrics-server --namespace kube-system
```
## 2.3. Install VPA

https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler#installation

## 2.4. Deploy VPA

```
kubectl apply -f vpa.yaml
```

## 2.5. Create load. Watch usage.

```
watch -n 1 kubectl get pod
watch -n 1 kubectl top pod
```

After about 5 minutes, VPA recreates the pods while increasing the values under requests' cpu and memory fields.

## 2.6. References

- https://www.kubecost.com/kubernetes-autoscaling/kubernetes-vpa/
- https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler

