# ArgoCD Multi-Cluster Federation

A hands-on experiment demonstrating GitOps-driven multi-cluster federation using ArgoCD.

**What you will see:**
- ArgoCD installed on a single master kind cluster managing itself and two worker clusters
- A single `ApplicationSet` with a `clusters` generator creating one Application per cluster automatically
- Kubernetes resources (Namespace, ServiceAccounts, RBAC, ConfigMap) synced to all three clusters from a single Git path — with no direct `kubectl apply` to the workers
- GitOps in action: edit a manifest, push to Git, watch ArgoCD sync the change to all three clusters simultaneously

---

## Prerequisites

- `kind` installed
- `kubectl` installed
- `docker` running
- Repo pushed to a remote (ArgoCD inside the kind cluster pulls manifests from Git over HTTPS)

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│  Master Cluster  (kind-argocd-master)                           │
│                                                                 │
│  ArgoCD (argocd namespace)                                      │
│    Manages: master (in-cluster) + worker-1 + worker-2           │
│                                                                 │
│  ApplicationSet (clusters generator, label selector)            │
│    → Application: federation-demo-argocd-master                 │
│    → Application: federation-demo-argocd-worker-1               │
│    → Application: federation-demo-argocd-worker-2               │
└─────────────────────────────┬──────────────────┬───────────────┘
                               │                  │
                     cluster Secret          cluster Secret
                     (Docker bridge IP)      (Docker bridge IP)
                               │                  │
                               ▼                  ▼
            ┌──────────────────────┐  ┌──────────────────────┐
            │  Worker 1             │  │  Worker 2             │
            │  (kind-argocd-        │  │  (kind-argocd-        │
            │   worker-1)           │  │   worker-2)           │
            │                       │  │                       │
            │  Synced by ArgoCD:    │  │  Synced by ArgoCD:    │
            │  - Namespace          │  │  - Namespace          │
            │  - ServiceAccounts    │  │  - ServiceAccounts    │
            │  - Role + RoleBinding │  │  - Role + RoleBinding │
            │  - ConfigMap          │  │  - ConfigMap          │
            └──────────────────────┘  └──────────────────────┘
```

All three kind clusters share the Docker `kind` bridge network. Worker cluster API server addresses are rewritten from `127.0.0.1` to the container's Docker bridge IP so that ArgoCD's controller pod (running inside the master cluster) can reach the worker API servers.

---

## Setup

```bash
cd argocd/01-multi-cluster-federation
bash setup.sh
```

`setup.sh` does the following automatically:

1. Creates `kind-argocd-master`, `kind-argocd-worker-1`, `kind-argocd-worker-2`
2. Installs ArgoCD `v2.14.10` on the master cluster
3. Patches `argocd-server` service to `NodePort` on port `30080` for UI access
4. Creates a dedicated `argocd-manager` ServiceAccount + long-lived token on each worker, then registers each worker as an ArgoCD external cluster Secret (using the worker's Docker bridge IP as the API server address)
5. Labels the built-in `in-cluster` Secret so the ApplicationSet also targets the master
6. Detects the Git remote URL and current branch, substitutes them into the ApplicationSet, and applies it

---

## Experiment Steps

### Step 1 — Verify the three ArgoCD Applications are Synced

```bash
kubectl get applications -n argocd --context kind-argocd-master
```

Expected output (after ~3 minutes for initial sync):

```
NAME                              SYNC STATUS   HEALTH STATUS
federation-demo-argocd-master     Synced        Healthy
federation-demo-argocd-worker-1   Synced        Healthy
federation-demo-argocd-worker-2   Synced        Healthy
```

If applications show `OutOfSync` or `Progressing`, ArgoCD may still be performing its initial sync. Wait a moment and re-run.

### Step 2 — Verify resources on the master cluster

```bash
kubectl get namespace federation-demo --context kind-argocd-master
kubectl get serviceaccounts -n federation-demo --context kind-argocd-master
kubectl get role,rolebinding -n federation-demo --context kind-argocd-master
kubectl get configmap app-config -n federation-demo --context kind-argocd-master -o yaml
```

### Step 3 — Verify resources on worker-1 (no direct `kubectl apply` was used)

```bash
kubectl get namespace federation-demo --context kind-argocd-worker-1
kubectl get serviceaccounts -n federation-demo --context kind-argocd-worker-1
kubectl get role,rolebinding -n federation-demo --context kind-argocd-worker-1
kubectl get configmap app-config -n federation-demo --context kind-argocd-worker-1 -o yaml
```

### Step 4 — Verify resources on worker-2

```bash
kubectl get namespace federation-demo --context kind-argocd-worker-2
kubectl get serviceaccounts -n federation-demo --context kind-argocd-worker-2
kubectl get configmap app-config -n federation-demo --context kind-argocd-worker-2 -o yaml
```

> **Key observation:** The same resources are present on all three clusters. No `kubectl apply` was ever run against the worker clusters directly — ArgoCD applied them all from the Git source.

### Step 5 — Demonstrate GitOps sync (edit + push)

Edit `gitops/base/configmap.yaml` — change the `demo-message` value:

```yaml
data:
  demo-message: "Updated by GitOps — all clusters will sync!"
```

Commit and push:

```bash
git add argocd/01-multi-cluster-federation/gitops/base/configmap.yaml
git commit -m "demo: update configmap to trigger argocd sync"
git push
```

Wait ~3 minutes (ArgoCD's default repository poll interval), then verify on all three clusters:

```bash
for ctx in kind-argocd-master kind-argocd-worker-1 kind-argocd-worker-2; do
  echo "=== ${ctx} ==="
  kubectl get configmap app-config -n federation-demo --context "${ctx}" \
    -o jsonpath='{.data.demo-message}{"\n"}'
done
```

Expected: all three clusters return `Updated by GitOps — all clusters will sync!`

### Step 6 — Access the ArgoCD UI

```bash
# Get the admin password
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  --context kind-argocd-master \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Open in browser
open http://localhost:30080
```

Login with username `admin` and the password printed above.

You will see all three Applications (`federation-demo-argocd-master`, `federation-demo-argocd-worker-1`, `federation-demo-argocd-worker-2`) and can browse the synced resources per cluster.

---

## Key Observations

| What to observe | Where to look |
|---|---|
| 3 Applications created automatically by ApplicationSet | `kubectl get applications -n argocd --context kind-argocd-master` |
| Resources on master (no manual apply) | `kubectl get all -n federation-demo --context kind-argocd-master` |
| Resources on worker-1 (no manual apply) | `kubectl get all -n federation-demo --context kind-argocd-worker-1` |
| Resources on worker-2 (no manual apply) | `kubectl get all -n federation-demo --context kind-argocd-worker-2` |
| ConfigMap updated after Git push | `kubectl get cm app-config -n federation-demo -o yaml --context kind-argocd-worker-1` |
| Registered ArgoCD cluster Secrets | `kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster --context kind-argocd-master` |

---

## How It Works

```
Git repo (gitops/base/) ──── ArgoCD polls every 3min ────▶ ApplicationSet
                                                                │
                                         ┌──────────────────────┼──────────────────────┐
                                         ▼                      ▼                      ▼
                                  Application              Application              Application
                                  (master)                 (worker-1)               (worker-2)
                                         │                      │                      │
                                         ▼                      ▼                      ▼
                                  kubectl apply          kubectl apply          kubectl apply
                                  (in-cluster)        (via cluster Secret)   (via cluster Secret)
```

The ApplicationSet `clusters` generator discovers Secrets in the `argocd` namespace with label `argocd.argoproj.io/secret-type=cluster` that also match the `argocd.argoproj.io/federation-demo=true` label selector. For each matching Secret, it creates one `Application`. The `{{name}}` and `{{server}}` template variables are populated from the Secret's `data.name` and `data.server` fields.

The label selector (`argocd.argoproj.io/federation-demo=true`) ensures this ApplicationSet only targets clusters registered for this experiment, not any other clusters you may have registered in ArgoCD.

---

## File Structure

```
argocd/01-multi-cluster-federation/
├── setup.sh                        # Orchestrates full setup (run this first)
├── teardown.sh                     # Deletes all 3 kind clusters
├── kind-master.yaml                # Kind config: master cluster (NodePort 30080)
├── kind-worker-1.yaml              # Kind config: worker-1
├── kind-worker-2.yaml              # Kind config: worker-2
├── argocd/
│   └── applicationset.yaml         # ApplicationSet with cluster generator
└── gitops/
    └── base/
        ├── namespace.yaml          # Namespace: federation-demo
        ├── serviceaccounts.yaml    # ServiceAccounts: app-sa, monitoring-sa
        ├── rbac.yaml               # Role + RoleBinding for app-sa
        └── configmap.yaml          # ConfigMap: app-config (edit this for the GitOps demo)
```

---

## Cleanup

```bash
bash teardown.sh
```

---

## References

- [ArgoCD ApplicationSet docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [ArgoCD Cluster Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/)
- [ArgoCD Declarative Setup — cluster Secrets](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters)
- [kind documentation](https://kind.sigs.k8s.io/)
