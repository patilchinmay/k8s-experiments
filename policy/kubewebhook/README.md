# Kubewebhook

Create a kind cluster.

Create mutating admission controllers webhook with [kubewebhook](https://github.com/slok/kubewebhook).

1. Add 2 labels on each pod (`src/app/mutating/addlabel`)
2. Change the pod image tag to latest (`src/app/mutating/imagetags`)

Ref: https://github.com/slok/kubewebhook

# Create Cluster

`kind create cluster --config kind.yaml`

# Install cert manager

This is useful for testing inside Kind cluster.

Ref: https://cert-manager.io/docs/installation/helm/

```bash
helm repo add jetstack https://charts.jetstack.io

helm repo update

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.11.0 \
  --set installCRDs=true

# Verify
# https://cert-manager.io/docs/installation/verify/
kubectl get pods --namespace cert-manager
```
# Key and Certificate creation (For local testing)

This is useful for local testing with `make run`.

```bash
cd certs

# Generate private key
openssl genrsa -out server.key 2048

# Generate public key (certificate) using the private key
openssl req -new -x509 -sha256 -key server.key -out server.crt -days 3650

# Run locally
make run
```

# Build Image and Load Into Kind

```bash
# Build
make build

# Load image into Kind
make load
```


# Run Webhook in Kind

```bash
kubectl apply -k k8s
```

# Verify

```bash
# Logs
kubectl logs -f deploy/kubewebhook

# In new terminal tab
kubectl run -i --tty --rm debugpod --image=alpine:3.17 --restart=Never -- sh

# Verify
# labels are added
# image tag is changed
kubectl get po debugpod -o yaml

---<truncated>---:
    mutated: "true"
    mutator: pod-annotate
---<truncated>---
image: alpine:latest
---<truncated>---

```

# Cleanup

Delete Cluster

`kind delete cluster`