# Horizontal Pod Autoscaler


  - Create an EKS cluster
  - Install the Metrics Server
  - Deploy a sample application
  - Install Horizontal Pod Autoscaler
  - Increase Load
  - Monitor HPA events
  - Decrease the load

Reference: 
- https://www.kubecost.com/kubernetes-autoscaling/kubernetes-hpa/
- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale

## Create an EKS cluster

```
kind create cluster --config kind.yaml
kubectl get pods --all-namespaces
```

## Install the Metrics Server

```
Install:

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install --set args={--kubelet-insecure-tls} metrics-server metrics-server/metrics-server --namespace kube-system

Verify:
kubectl get apiservice | grep -i metrics
kubectl get svc -n kube-system
kubectl get --raw /apis/metrics.k8s.io/v1beta1 | jq
```

## Deploy a sample application

```
kubectl apply -f app-deploy-svc.yaml
```

## Install Horizontal Pod Autoscaler

```
kubectl apply -f hpa.yaml
kubectl get hpa
```

## Increase Load

```
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://hpa-demo-deployment; done"
```

## Monitor HPA events

```
kubectl get hpa
kubectl describe deploy hpa-demo-deployment
kubectl get events
```

## Decrease the load

Run Cmd/Ctr + C to terminate load generation in the window where load-generator pod is running.

Now observe the deployment and hpa. Replica count should decrease.