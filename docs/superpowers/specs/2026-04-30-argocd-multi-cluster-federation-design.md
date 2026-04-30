# ArgoCD Multi-Cluster Federation Experiment — Design Spec

**Date:** 2026-04-30  
**Branch:** feat/argocd-multi-cluster-federation  
**Experiment path:** `argocd/01-multi-cluster-federation/`

---

## Overview

This experiment demonstrates GitOps-driven multi-cluster federation using ArgoCD. Three local kind clusters are created (1 master, 2 workers). ArgoCD runs exclusively on the master cluster and manages all three clusters via a hub-spoke model. A single `ApplicationSet` with a `clusters` generator fans out a set of Kubernetes resources (Namespace, ServiceAccounts, RBAC, ConfigMap) to all registered clusters automatically.

**Primary learning outcome:** Observe that committing resources to a Git path causes ArgoCD to sync those resources to all three clusters simultaneously, without any direct `kubectl apply` to the worker clusters.

---

## Cluster Architecture

```
┌────────────────────────────────────────────────────────────────┐
│  Master Cluster  (kind-argocd-master)                           │
│                                                                 │
│  ArgoCD (argocd namespace)                                      │
│    - Manages itself via in-cluster destination                  │
│    - Manages argocd-worker-1 (external cluster Secret)          │
│    - Manages argocd-worker-2 (external cluster Secret)          │
│                                                                 │
│  ApplicationSet (cluster generator, label selector)             │
│    → Application: federation-demo-argocd-master                 │
│    → Application: federation-demo-argocd-worker-1               │
│    → Application: federation-demo-argocd-worker-2               │
└────────────────────────────────────────────────────────────────┘
         │                              │
   kubeconfig Secret              kubeconfig Secret
   (argocd namespace,             (argocd namespace,
    secret-type: cluster)          secret-type: cluster)
         │                              │
         ▼                              ▼
┌──────────────────────┐    ┌──────────────────────┐
│  Worker 1             │    │  Worker 2             │
│  (kind-argocd-        │    │  (kind-argocd-        │
│   worker-1)           │    │   worker-2)           │
│                       │    │                       │
│  Synced by ArgoCD:    │    │  Synced by ArgoCD:    │
│  - Namespace          │    │  - Namespace          │
│  - ServiceAccounts    │    │  - ServiceAccounts    │
│  - Role + RoleBinding │    │  - Role + RoleBinding │
│  - ConfigMap          │    │  - ConfigMap          │
└──────────────────────┘    └──────────────────────┘
```

All three kind clusters share the Docker `kind` bridge network. The kubeconfig for each worker is extracted and rewritten from `127.0.0.1:<host-port>` to the container's Docker bridge IP, so that ArgoCD's controller pod can reach the worker API servers from inside the master cluster.

---

## File Structure

```
argocd/
└── 01-multi-cluster-federation/
    ├── setup.sh                            # Orchestrates full setup
    ├── teardown.sh                         # Deletes all 3 kind clusters
    ├── README.md                           # Experiment walkthrough
    ├── kind-master.yaml                    # Kind config: master cluster
    ├── kind-worker-1.yaml                  # Kind config: worker-1
    ├── kind-worker-2.yaml                  # Kind config: worker-2
    ├── argocd/
    │   └── applicationset.yaml             # ApplicationSet with cluster generator
    └── gitops/
        └── base/
            ├── namespace.yaml              # Namespace: federation-demo
            ├── serviceaccounts.yaml        # ServiceAccounts: app-sa, monitoring-sa
            ├── rbac.yaml                   # Role + RoleBinding for app-sa
            └── configmap.yaml             # ConfigMap: app-config (sample data)
```

---

## Setup Flow (`setup.sh`)

1. **Create kind clusters** — `kind-argocd-master`, `kind-argocd-worker-1`, `kind-argocd-worker-2` using minimal single-node kind configs. Master gets an extra port mapping for the ArgoCD UI (port 30080 → NodePort 30080).
2. **Install ArgoCD on master** — `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml` then wait for all ArgoCD deployments to be Ready.
3. **Patch ArgoCD server service** — change `argocd-server` service to `NodePort` so the UI is accessible on `localhost:30080`.
4. **Register worker clusters** — for each worker:
   - Inspect the worker control-plane container to get its Docker bridge IP
   - Extract `kind get kubeconfig --name <worker> --internal` and rewrite the server address to the Docker IP
   - Create a Secret in `argocd` namespace with labels `argocd.argoproj.io/secret-type: cluster` and `argocd.argoproj.io/federation-demo: "true"` so the ApplicationSet cluster generator picks it up
5. **Label the in-cluster Secret** — ArgoCD creates a built-in Secret for `in-cluster` on first startup. Label it with `argocd.argoproj.io/federation-demo: "true"` so the ApplicationSet also targets the master itself.
6. **Detect remote Git URL** — `git remote get-url origin` from the repo root; substitute into the ApplicationSet manifest before applying.
7. **Apply the ApplicationSet** — `kubectl apply -f argocd/applicationset.yaml --context kind-argocd-master`. ArgoCD generates 3 Applications and syncs `gitops/base/` to all three clusters.

---

## ApplicationSet

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: federation-demo
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            argocd.argoproj.io/federation-demo: "true"
  template:
    metadata:
      name: 'federation-demo-{{name}}'
    spec:
      project: default
      source:
        repoURL: <DETECTED_FROM_GIT_REMOTE>   # substituted by setup.sh
        targetRevision: HEAD
        path: argocd/01-multi-cluster-federation/gitops/base
      destination:
        server: '{{server}}'
        namespace: federation-demo
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

The `clusters` generator discovers all ArgoCD cluster Secrets matching the label selector and creates one Application per cluster. The `{{name}}` and `{{server}}` template variables are populated by ArgoCD from the Secret metadata.

---

## GitOps Manifests (`gitops/base/`)

### `namespace.yaml`
- `Namespace: federation-demo`

### `serviceaccounts.yaml`
- `ServiceAccount: app-sa` — intended for application workloads
- `ServiceAccount: monitoring-sa` — intended for monitoring agents

### `rbac.yaml`
- `Role: app-role` — grants `get/list/watch` on Pods and ConfigMaps in `federation-demo`
- `RoleBinding: app-sa-binding` — binds `app-role` to `app-sa`

### `configmap.yaml`
- `ConfigMap: app-config` — sample key/value data to demonstrate GitOps sync. The README experiment step has the reader modify a value in this ConfigMap and push to Git to observe ArgoCD syncing the change across all clusters.

---

## Kind Cluster Configs

All three clusters use minimal single-node (control-plane only) configs. The master exposes port 30080 for the ArgoCD UI. Workers have no extra port mappings.

---

## Experiment Steps (README outline)

1. **Prerequisites** — kind, kubectl, docker installed; repo cloned and on branch `feat/argocd-multi-cluster-federation` (or merged to main)
2. **Run setup** — `bash setup.sh` from `argocd/01-multi-cluster-federation/`
3. **Verify ArgoCD Applications** — `kubectl get applications -n argocd --context kind-argocd-master` → 3 Applications, all `Synced/Healthy`
4. **Verify resources on master** — namespace, SAs, RBAC, ConfigMap present
5. **Verify resources on workers** — same resources on both workers without any direct `kubectl apply`
6. **Demonstrate GitOps sync** — edit `configmap.yaml`, commit and push; watch ArgoCD sync all 3 clusters
7. **Access ArgoCD UI** — `http://localhost:30080` (admin / auto-generated password via `argocd-initial-admin-secret`)
8. **Cleanup** — `bash teardown.sh`

---

## Constraints and Decisions

- **ArgoCD version:** A specific stable version tag (e.g., `v2.14.x`) will be pinned in `setup.sh` for reproducibility — not the floating `stable` tag. The exact version will be chosen at implementation time based on latest stable release.
- **No Helm for ArgoCD install:** Raw manifest install is simpler for a learning experiment and avoids a Helm dependency.
- **repoURL detection:** `setup.sh` reads the remote URL from `git remote get-url origin` and substitutes it into the ApplicationSet at apply time using `sed`. This avoids hardcoding a URL in the checked-in `applicationset.yaml`.
- **Label selector on cluster generator:** Prevents accidental targeting of unrelated registered clusters.
- **No ArgoCD CLI required:** Worker cluster registration is done by manually creating the ArgoCD cluster Secret, avoiding an `argocd login` prerequisite.
- **targetRevision: HEAD:** Always syncs the latest commit on the branch that was pushed, consistent with the GitOps demo intent.
