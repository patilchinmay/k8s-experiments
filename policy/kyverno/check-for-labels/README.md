# 1. Check for labels

- [1. Check for labels](#1-check-for-labels)
  - [1.1. Create Cluster](#11-create-cluster)
  - [1.2. Install Kyverno](#12-install-kyverno)
  - [1.3. Verify Kyverno Installation](#13-verify-kyverno-installation)
  - [1.4. Apply Policy](#14-apply-policy)
  - [1.5. Verify policy](#15-verify-policy)
  - [1.6. Cleanup](#16-cleanup)


Create a cluster.

Install Kyverno.

Validate that each pod has a label `app.kubernetes.io/name` with some value.

Prevent pods that do not have labels.

Ref: https://kyverno.io/docs/introduction/#quick-start

## 1.1. Create Cluster

`kind create cluster --config kind.yaml`

## 1.2. Install Kyverno

```bash
# Add the Helm repository
helm repo add kyverno https://kyverno.github.io/kyverno/

# Scan your Helm repositories to fetch the latest available charts.
helm repo update

# Install the Kyverno Helm chart into a new namespace called "kyverno"
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
```

## 1.3. Verify Kyverno Installation

```bash
❯ kg all -n kyverno
NAME                                             READY   STATUS    RESTARTS   AGE
pod/kyverno-756866545f-4g2h7                     1/1     Running   0          55s
pod/kyverno-cleanup-controller-89d978b7c-tw6tq   1/1     Running   0          55s

NAME                                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/kyverno-cleanup-controller           ClusterIP   10.96.231.212   <none>        443/TCP    55s
service/kyverno-cleanup-controller-metrics   ClusterIP   10.96.206.26    <none>        8000/TCP   55s
service/kyverno-svc                          ClusterIP   10.96.128.251   <none>        443/TCP    55s
service/kyverno-svc-metrics                  ClusterIP   10.96.1.195     <none>        8000/TCP   55s

NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/kyverno                      1/1     1            1           55s
deployment.apps/kyverno-cleanup-controller   1/1     1            1           55s

NAME                                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/kyverno-756866545f                     1         1         1       55s
replicaset.apps/kyverno-cleanup-controller-89d978b7c   1         1         1       55s
```

## 1.4. Apply Policy

`kubectl apply -f check-for-labels.policy.yaml`

## 1.5. Verify policy

Create a pod without required label. It should block.

```bash
❯ kubectl run -i --tty --rm debugpod --image=alpine:latest --restart=Never -- sh
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:

policy Pod/default/debugpod for resource violation:

require-labels:
  check-for-labels: 'validation error: label ''app.kubernetes.io/name'' is required.
    rule check-for-labels failed at path /metadata/labels/app.kubernetes.io/name/'
```

Create a pod with required label. It should work.

```bash
❯ kubectl run -i --tty --rm debugpod --image=alpine:latest --restart=Never --labels app.kubernetes.io/name=alpine -- sh
If you don't see a command prompt, try pressing enter.
/ #
/ #
/ # whoami
root
```

## 1.6. Cleanup

Delete all cluster policies.

`kubectl delete cpol --all`

Delete Cluster

`kind delete cluster`