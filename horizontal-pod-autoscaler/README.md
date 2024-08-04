# 1. Horizontal Pod Autoscaler

- [1. Horizontal Pod Autoscaler](#1-horizontal-pod-autoscaler)
  - [1.1. Create a cluster](#11-create-a-cluster)
  - [1.2. Install the Metrics Server](#12-install-the-metrics-server)
  - [1.3. Deploy a sample application (deployment + service)](#13-deploy-a-sample-application-deployment--service)
  - [1.4. Install Horizontal Pod Autoscaler](#14-install-horizontal-pod-autoscaler)
  - [1.5. Increase Load](#15-increase-load)
  - [1.6. Monitor HPA events](#16-monitor-hpa-events)
  - [1.7. Decrease the load](#17-decrease-the-load)


## 1.1. Create a cluster

```
kind create cluster --config kind.yaml
kubectl get pods --all-namespaces
```

## 1.2. Install the Metrics Server

```bash
# Install:

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install --set args={--kubelet-insecure-tls} metrics-server metrics-server/metrics-server --namespace kube-system

# Verify:

kubectl get apiservice | grep -i metrics
kubectl get svc -n kube-system
kubectl get --raw /apis/metrics.k8s.io/v1beta1 | jq
```

## 1.3. Deploy a sample application (deployment + service)

```
kubectl apply -f app-deploy-svc.yaml
```

## 1.4. Install Horizontal Pod Autoscaler

```
kubectl apply -f hpa.yaml
kubectl get hpa
```

## 1.5. Increase Load

```
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://hpa-demo-deployment; done"
```

## 1.6. Monitor HPA events

```
kubectl get hpa
kubectl describe deploy hpa-demo-deployment
kubectl get events
```

## 1.7. Decrease the load

Run Cmd/Ctrl + C to terminate load generation in the window where load-generator pod is running.

Now observe the deployment and hpa. Replica count should decrease.

Reference: 
- https://www.kubecost.com/kubernetes-autoscaling/kubernetes-hpa/
- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale