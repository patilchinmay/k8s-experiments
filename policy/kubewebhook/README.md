# 1. Kubewebhook

- [1. Kubewebhook](#1-kubewebhook)
  - [1.1. Create Cluster](#11-create-cluster)
  - [1.2. Install cert manager](#12-install-cert-manager)
  - [1.3. Key and Certificate creation (For local testing)](#13-key-and-certificate-creation-for-local-testing)
  - [1.4. Build Image and Load Into Kind](#14-build-image-and-load-into-kind)
  - [1.5. Run Webhook in Kind](#15-run-webhook-in-kind)
  - [1.6. Verify](#16-verify)
  - [1.7. Cleanup](#17-cleanup)


Create a kind cluster.

Create mutating admission controllers webhook with [kubewebhook](https://github.com/slok/kubewebhook).

1. Add 2 labels on each pod (`src/app/mutating/addlabel`)
2. Change the pod image tag to latest (`src/app/mutating/imagetags`)

Ref: https://github.com/slok/kubewebhook

## 1.1. Create Cluster

`kind create cluster --config kind.yaml`

## 1.2. Install cert manager

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
## 1.3. Key and Certificate creation (For local testing)

This is useful for local testing with `make run`.

```bash
cd certs

# Generate private key
openssl genrsa -out server.key 2048

# Generate public key (certificate) using the private key
openssl req -new -x509 -sha256 -key server.key -out server.crt -days 3650

# Run locally
go mod tidy

make run
```

## 1.4. Build Image and Load Into Kind

```bash
# Build
make build

# Load image into Kind
make load
```


## 1.5. Run Webhook in Kind

```bash
kubectl apply -k k8s
```

## 1.6. Verify

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

## 1.7. Cleanup

Delete Cluster

`kind delete cluster`