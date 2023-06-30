# Sealed Secrets

Create sealed secret in the cluster. Attach it to a pod.

# Process

## 1. Create Cluster

```bash
kind create cluster --config kind.yaml
```

## 2. Sealed Secret Installation

This involves 2 steps. Cluster side and client side installation.
Ref: [helm](https://artifacthub.io/packages/helm/bitnami-labs/sealed-secrets), [github](https://github.com/bitnami-labs/sealed-secrets).

### 2.1 Cluster Side

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets

helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets
```
The above commands should install the sealed secrets controller and create a TLS secret.

Verify it as below:

```bash
kubectl get po -n kube-system | grep sealed

kubectl get secrets -n kube-system | grep sealed
```

### 2.2 Client Side

```bash
brew install kubeseal
```

## 3. Configuration

### 3.1 Set certificate

Fetch the certificate created by the sealed secrets controller so that we can use it to encrypt the secrets.

```bash
kubeseal --fetch-cert > pub-cert.pem
```

## 4. Create sealed secret

### 4.1 Create a normal secret

We are going to create a secret with the key value pair of `password=mysecretpassword`.
We will work in default namespace to keep things simple.

```bash
kubectl create secret generic my-password --from-literal=password='mysecretpassword' --dry-run=client -n default -o yaml > my-password.yaml
```

The generated file `my-password.yaml` should **NOT** be committed to git.

### 4.2 Convert normal secret to sealed secret

```bash
kubeseal --scope namespace-wide --cert pub-cert.pem --format yaml < my-password.yaml > my-password-encrypted.yaml
```

The generated file `my-password-encrypted.yaml` is safe to be committed to git.

### 4.3. Deploy sealed secret to cluster

```bash
kubectl apply -f my-password-encrypted.yaml -n default
```

Verify the creation:

```bash
> kubectl get sealedsecret -n default
NAME          STATUS   SYNCED   AGE
my-password            True     45s

> kubectl get secret -n default
NAME          TYPE     DATA   AGE
my-password   Opaque   1      83s
```

# 5. Use the secret

Run a debug pod (`pod.yaml`):

```bash
kubectl apply -f pod.yaml
```

Verify that the secret is actually attached to the pod:

```bash
kubectl exec -it debugpod -- sh

$ ls /etc/mypassword
password

$ cat /etc/mypassword/password
mysecretpassword

$ exit
```

# 6. Cleanup

Delete Cluster

`kind delete cluster`