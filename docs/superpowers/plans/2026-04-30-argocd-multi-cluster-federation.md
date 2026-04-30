# ArgoCD Multi-Cluster Federation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a working ArgoCD multi-cluster federation experiment under `argocd/01-multi-cluster-federation/` that spins up 3 kind clusters, installs ArgoCD on the master, registers worker clusters, and uses an ApplicationSet to sync Namespace/ServiceAccounts/RBAC/ConfigMap to all three clusters via GitOps.

**Architecture:** ArgoCD runs exclusively on `kind-argocd-master`. Worker clusters (`kind-argocd-worker-1`, `kind-argocd-worker-2`) are registered as external ArgoCD clusters via Secrets with the ArgoCD cluster Secret format. A single `ApplicationSet` (cluster generator with label selector) creates one Application per cluster, all pointing to `argocd/01-multi-cluster-federation/gitops/base/` in this repo. `setup.sh` detects the Git remote URL at runtime and substitutes it into the ApplicationSet before applying.

**Tech Stack:** kind, kubectl, ArgoCD v2.14.x (raw manifests), bash, YAML

**Branch:** `feat/argocd-multi-cluster-federation`

---

## File Map

Files to create (all under `argocd/01-multi-cluster-federation/`):

| File | Purpose |
|------|---------|
| `kind-master.yaml` | Kind cluster config for master — single control-plane, NodePort 30080 for ArgoCD UI |
| `kind-worker-1.yaml` | Kind cluster config for worker-1 — single control-plane only |
| `kind-worker-2.yaml` | Kind cluster config for worker-2 — single control-plane only |
| `argocd/applicationset.yaml` | ApplicationSet with cluster generator + label selector |
| `gitops/base/namespace.yaml` | Namespace: `federation-demo` |
| `gitops/base/serviceaccounts.yaml` | ServiceAccounts: `app-sa`, `monitoring-sa` |
| `gitops/base/rbac.yaml` | Role `app-role` + RoleBinding `app-sa-binding` |
| `gitops/base/configmap.yaml` | ConfigMap `app-config` with sample data |
| `setup.sh` | Orchestrates cluster creation, ArgoCD install, cluster registration, ApplicationSet apply |
| `teardown.sh` | Deletes all 3 kind clusters |
| `README.md` | Experiment walkthrough |

---

## Task 1: Create directory structure and kind cluster configs

**Files:**
- Create: `argocd/01-multi-cluster-federation/kind-master.yaml`
- Create: `argocd/01-multi-cluster-federation/kind-worker-1.yaml`
- Create: `argocd/01-multi-cluster-federation/kind-worker-2.yaml`

- [ ] **Step 1: Create the experiment directory**

```bash
mkdir -p argocd/01-multi-cluster-federation/argocd
mkdir -p argocd/01-multi-cluster-federation/gitops/base
```

Run from repo root. Expected: directories created, no output.

- [ ] **Step 2: Create `kind-master.yaml`**

Create `argocd/01-multi-cluster-federation/kind-master.yaml`:

```yaml
---
# Master cluster — runs ArgoCD and manages all three clusters (including itself).
# Exposes NodePort 30080 on the host for the ArgoCD UI.
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: argocd-master
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        listenAddress: "0.0.0.0"
        protocol: TCP
---
```

- [ ] **Step 3: Create `kind-worker-1.yaml`**

Create `argocd/01-multi-cluster-federation/kind-worker-1.yaml`:

```yaml
---
# Worker cluster 1 — receives resources synced by ArgoCD from the master.
# No extra port mappings needed; ArgoCD on master reaches it via Docker bridge network.
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: argocd-worker-1
nodes:
  - role: control-plane
---
```

- [ ] **Step 4: Create `kind-worker-2.yaml`**

Create `argocd/01-multi-cluster-federation/kind-worker-2.yaml`:

```yaml
---
# Worker cluster 2 — receives resources synced by ArgoCD from the master.
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: argocd-worker-2
nodes:
  - role: control-plane
---
```

- [ ] **Step 5: Commit**

```bash
git add argocd/01-multi-cluster-federation/kind-master.yaml \
        argocd/01-multi-cluster-federation/kind-worker-1.yaml \
        argocd/01-multi-cluster-federation/kind-worker-2.yaml
git commit -m "feat(argocd-federation): add kind cluster configs"
```

---

## Task 2: Create the GitOps manifests

**Files:**
- Create: `argocd/01-multi-cluster-federation/gitops/base/namespace.yaml`
- Create: `argocd/01-multi-cluster-federation/gitops/base/serviceaccounts.yaml`
- Create: `argocd/01-multi-cluster-federation/gitops/base/rbac.yaml`
- Create: `argocd/01-multi-cluster-federation/gitops/base/configmap.yaml`

- [ ] **Step 1: Create `namespace.yaml`**

Create `argocd/01-multi-cluster-federation/gitops/base/namespace.yaml`:

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: federation-demo
  labels:
    managed-by: argocd
    experiment: argocd-multi-cluster-federation
```

- [ ] **Step 2: Create `serviceaccounts.yaml`**

Create `argocd/01-multi-cluster-federation/gitops/base/serviceaccounts.yaml`:

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: federation-demo
  labels:
    managed-by: argocd
    experiment: argocd-multi-cluster-federation
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitoring-sa
  namespace: federation-demo
  labels:
    managed-by: argocd
    experiment: argocd-multi-cluster-federation
```

- [ ] **Step 3: Create `rbac.yaml`**

Create `argocd/01-multi-cluster-federation/gitops/base/rbac.yaml`:

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: federation-demo
  labels:
    managed-by: argocd
    experiment: argocd-multi-cluster-federation
rules:
  - apiGroups: [""]
    resources: ["pods", "configmaps"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-sa-binding
  namespace: federation-demo
  labels:
    managed-by: argocd
    experiment: argocd-multi-cluster-federation
subjects:
  - kind: ServiceAccount
    name: app-sa
    namespace: federation-demo
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
```

- [ ] **Step 4: Create `configmap.yaml`**

Create `argocd/01-multi-cluster-federation/gitops/base/configmap.yaml`:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: federation-demo
  labels:
    managed-by: argocd
    experiment: argocd-multi-cluster-federation
data:
  environment: "multi-cluster"
  federation-mode: "hub-spoke"
  managed-by: "argocd"
  # Edit this value and push to Git to demonstrate ArgoCD syncing the change
  # across all three clusters simultaneously.
  demo-message: "Hello from GitOps federation!"
```

- [ ] **Step 5: Commit**

```bash
git add argocd/01-multi-cluster-federation/gitops/
git commit -m "feat(argocd-federation): add gitops base manifests (namespace, SA, RBAC, configmap)"
```

---

## Task 3: Create the ApplicationSet

**Files:**
- Create: `argocd/01-multi-cluster-federation/argocd/applicationset.yaml`

The `repoURL` field uses a placeholder `__REPO_URL__` that `setup.sh` substitutes with the live Git remote URL at apply time. The `targetRevision` uses `__TARGET_REVISION__` which `setup.sh` substitutes with the current branch name.

- [ ] **Step 1: Create `argocd/applicationset.yaml`**

Create `argocd/01-multi-cluster-federation/argocd/applicationset.yaml`:

```yaml
---
# ApplicationSet: federation-demo
#
# Uses the `clusters` generator with a label selector so it only targets
# clusters explicitly labelled with argocd.argoproj.io/federation-demo=true.
# This prevents accidental targeting of unrelated registered clusters.
#
# __REPO_URL__ and __TARGET_REVISION__ are substituted by setup.sh at apply time
# using the repo's actual Git remote URL and current branch name.
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
        repoURL: __REPO_URL__
        targetRevision: __TARGET_REVISION__
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

- [ ] **Step 2: Commit**

```bash
git add argocd/01-multi-cluster-federation/argocd/applicationset.yaml
git commit -m "feat(argocd-federation): add ApplicationSet with cluster generator"
```

---

## Task 4: Create `teardown.sh`

**Files:**
- Create: `argocd/01-multi-cluster-federation/teardown.sh`

- [ ] **Step 1: Create `teardown.sh`**

Create `argocd/01-multi-cluster-federation/teardown.sh`:

```bash
#!/usr/bin/env bash
# teardown.sh
# Deletes all three kind clusters created by setup.sh.
# Run from within this directory: bash teardown.sh

set -euo pipefail

echo "==> Deleting kind cluster: argocd-master..."
kind delete cluster --name argocd-master || true

echo "==> Deleting kind cluster: argocd-worker-1..."
kind delete cluster --name argocd-worker-1 || true

echo "==> Deleting kind cluster: argocd-worker-2..."
kind delete cluster --name argocd-worker-2 || true

echo ""
echo "✅ All clusters deleted."
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x argocd/01-multi-cluster-federation/teardown.sh
git add argocd/01-multi-cluster-federation/teardown.sh
git commit -m "feat(argocd-federation): add teardown.sh"
```

---

## Task 5: Create `setup.sh`

**Files:**
- Create: `argocd/01-multi-cluster-federation/setup.sh`

This is the core orchestration script. It has five logical sections:
1. Create clusters
2. Install ArgoCD on master
3. Register worker clusters as ArgoCD external cluster Secrets
4. Label the in-cluster (master) Secret
5. Substitute Git remote URL + branch into ApplicationSet and apply it

**Important implementation notes:**
- The ArgoCD cluster Secret format requires: label `argocd.argoproj.io/secret-type: cluster`, annotation `managed-by: argocd.argoproj.io`, and a `data.config` JSON field. For unauthenticated bearer token access inside a kind cluster, the config is `{"tlsClientConfig":{"insecure":false},"bearerToken":"<token>"}`.
- ArgoCD creates a built-in Secret named `in-cluster` for `https://kubernetes.default.svc` on first startup. We label it rather than creating a new one.
- Worker cluster API server address must be the Docker bridge IP (not `127.0.0.1`), same technique as the kueue experiment.
- `setup.sh` must be run from within the `argocd/01-multi-cluster-federation/` directory (the script uses `SCRIPT_DIR` for relative paths).
- The Git remote URL is read via `git remote get-url origin`. If no remote exists the script exits with a helpful error.

- [ ] **Step 1: Create `setup.sh`**

Create `argocd/01-multi-cluster-federation/setup.sh`:

```bash
#!/usr/bin/env bash
# setup.sh
# Creates three Kind clusters (argocd-master + argocd-worker-1 + argocd-worker-2),
# installs ArgoCD on the master, registers both workers as ArgoCD external clusters,
# and applies an ApplicationSet that syncs gitops/base/ to all three clusters.
#
# Run from within this directory: bash setup.sh
#
# Prerequisites: kind, kubectl, docker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_VERSION="v2.14.10"
MASTER_CTX="kind-argocd-master"

# ---------------------------------------------------------------------------
# Helper: wait for all deployments in a namespace to be Available
# ---------------------------------------------------------------------------
wait_for_deployments() {
  local ctx="$1"
  local ns="$2"
  echo "  Waiting for all deployments in ${ns} on ${ctx}..."
  kubectl wait deploy --all -n "${ns}" \
    --for=condition=Available \
    --timeout=5m \
    --context "${ctx}"
}

# ---------------------------------------------------------------------------
# Helper: register a worker cluster as an ArgoCD external cluster Secret.
#
# ArgoCD discovers external clusters by looking for Secrets in the argocd
# namespace that have the label argocd.argoproj.io/secret-type=cluster.
# Each Secret must contain:
#   data.name       — display name shown in the ArgoCD UI
#   data.server     — API server URL (must be reachable from inside the master pod)
#   data.config     — JSON with TLS and auth configuration
#
# We extract a service-account token from the worker cluster and use it as
# the bearerToken so ArgoCD can authenticate to the worker API server.
# ---------------------------------------------------------------------------
register_worker_cluster() {
  local worker_name="$1"     # e.g. argocd-worker-1
  local secret_name="$2"     # e.g. argocd-worker-1-cluster-secret
  local worker_ctx="kind-${worker_name}"

  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "  Registering ${worker_name} as ArgoCD external cluster"
  echo "══════════════════════════════════════════════════════════════════"

  # Get the Docker bridge IP of the worker control-plane container
  local cp_container="${worker_name}-control-plane"
  local worker_ip
  worker_ip=$(docker inspect "${cp_container}" \
    --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
  echo "  ${worker_name} control-plane Docker IP: ${worker_ip}"

  local server_url="https://${worker_ip}:6443"

  # Create a dedicated ServiceAccount + ClusterRoleBinding in the worker
  # for ArgoCD to use. ArgoCD needs cluster-admin to manage arbitrary resources.
  kubectl apply --context "${worker_ctx}" -f - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-manager
  namespace: kube-system
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-manager-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: argocd-manager
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-manager-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: argocd-manager
    namespace: kube-system
EOF

  # Wait for token to be populated
  echo "  Waiting for argocd-manager-token to be populated..."
  for i in $(seq 1 30); do
    local token
    token=$(kubectl get secret argocd-manager-token \
      -n kube-system \
      --context "${worker_ctx}" \
      -o jsonpath='{.data.token}' 2>/dev/null || true)
    if [ -n "${token}" ]; then
      break
    fi
    sleep 2
  done

  local bearer_token
  bearer_token=$(kubectl get secret argocd-manager-token \
    -n kube-system \
    --context "${worker_ctx}" \
    -o jsonpath='{.data.token}' | base64 -d)

  # Get the CA cert from the worker cluster
  local ca_data
  ca_data=$(kubectl get secret argocd-manager-token \
    -n kube-system \
    --context "${worker_ctx}" \
    -o jsonpath='{.data.ca\.crt}')

  # Build the ArgoCD cluster config JSON
  local config_json
  config_json=$(cat <<EOF
{"tlsClientConfig":{"insecure":false,"caData":"${ca_data}"},"bearerToken":"${bearer_token}"}
EOF
)

  # Create the ArgoCD cluster Secret on the master
  kubectl create secret generic "${secret_name}" \
    --namespace argocd \
    --context "${MASTER_CTX}" \
    --from-literal=name="${worker_name}" \
    --from-literal=server="${server_url}" \
    --from-literal=config="${config_json}" \
    --dry-run=client -o yaml | \
  kubectl annotate --local -f - \
    "managed-by=argocd.argoproj.io" \
    --dry-run=client -o yaml | \
  kubectl label --local -f - \
    "argocd.argoproj.io/secret-type=cluster" \
    "argocd.argoproj.io/federation-demo=true" \
    --dry-run=client -o yaml | \
  kubectl apply -f - --context "${MASTER_CTX}"

  echo "  ✅ Registered ${worker_name} (${server_url}) as ArgoCD cluster"
}

# ---------------------------------------------------------------------------
# 1. Create the three kind clusters
# ---------------------------------------------------------------------------
echo "==> Creating master cluster (argocd-master)..."
kind create cluster --name argocd-master --config "${SCRIPT_DIR}/kind-master.yaml"
kubectl cluster-info --context "${MASTER_CTX}"
kubectl wait deploy/coredns -n kube-system --for=condition=Available --timeout=5m --context "${MASTER_CTX}"

echo ""
echo "==> Creating worker cluster 1 (argocd-worker-1)..."
kind create cluster --name argocd-worker-1 --config "${SCRIPT_DIR}/kind-worker-1.yaml"
kubectl wait deploy/coredns -n kube-system --for=condition=Available --timeout=5m --context kind-argocd-worker-1

echo ""
echo "==> Creating worker cluster 2 (argocd-worker-2)..."
kind create cluster --name argocd-worker-2 --config "${SCRIPT_DIR}/kind-worker-2.yaml"
kubectl wait deploy/coredns -n kube-system --for=condition=Available --timeout=5m --context kind-argocd-worker-2

# ---------------------------------------------------------------------------
# 2. Install ArgoCD on the master cluster
# ---------------------------------------------------------------------------
echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Installing ArgoCD ${ARGOCD_VERSION} on ${MASTER_CTX}"
echo "══════════════════════════════════════════════════════════════════"

kubectl create namespace argocd --context "${MASTER_CTX}" || true
kubectl apply -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
  --context "${MASTER_CTX}"

wait_for_deployments "${MASTER_CTX}" "argocd"

# ---------------------------------------------------------------------------
# 3. Expose ArgoCD UI via NodePort on port 30080
# ---------------------------------------------------------------------------
echo ""
echo "==> Patching argocd-server service to NodePort on port 30080..."
kubectl patch svc argocd-server \
  -n argocd \
  --context "${MASTER_CTX}" \
  --type='json' \
  -p='[
    {"op":"replace","path":"/spec/type","value":"NodePort"},
    {"op":"add","path":"/spec/ports/0/nodePort","value":30080}
  ]'

# ---------------------------------------------------------------------------
# 4. Register worker clusters as ArgoCD external cluster Secrets
# ---------------------------------------------------------------------------
register_worker_cluster "argocd-worker-1" "argocd-worker-1-cluster-secret"
register_worker_cluster "argocd-worker-2" "argocd-worker-2-cluster-secret"

# ---------------------------------------------------------------------------
# 5. Label the built-in in-cluster Secret so the ApplicationSet targets master
#
# ArgoCD creates a Secret named "in-cluster" for https://kubernetes.default.svc
# automatically. We add the federation-demo label so the cluster generator
# includes the master cluster itself.
# ---------------------------------------------------------------------------
echo ""
echo "==> Labelling in-cluster Secret for ApplicationSet targeting..."
# The in-cluster secret may take a few seconds to appear after ArgoCD starts.
for i in $(seq 1 30); do
  if kubectl get secret in-cluster -n argocd --context "${MASTER_CTX}" &>/dev/null; then
    break
  fi
  echo "  Waiting for in-cluster Secret... (${i}/30)"
  sleep 3
done

kubectl label secret in-cluster \
  -n argocd \
  --context "${MASTER_CTX}" \
  "argocd.argoproj.io/federation-demo=true" \
  --overwrite

echo "  ✅ in-cluster Secret labelled"

# ---------------------------------------------------------------------------
# 6. Detect Git remote URL and current branch, then apply the ApplicationSet
# ---------------------------------------------------------------------------
echo ""
echo "==> Detecting Git remote URL and current branch..."

REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"
REPO_URL=$(git -C "${REPO_ROOT}" remote get-url origin 2>/dev/null || true)

if [ -z "${REPO_URL}" ]; then
  echo "ERROR: No git remote 'origin' found."
  echo "       ArgoCD needs a remote Git URL to pull manifests from."
  echo "       Push the branch to a remote and re-run setup.sh."
  exit 1
fi

# Convert SSH remote (git@github.com:user/repo.git) to HTTPS if needed,
# since ArgoCD inside the cluster cannot use SSH agent forwarding.
# git@github.com-personal:patilchinmay/k8s-experiments.git → https://github.com/patilchinmay/k8s-experiments.git
if [[ "${REPO_URL}" == git@* ]]; then
  # Strip any SSH host alias (e.g. github.com-personal → github.com)
  REPO_URL=$(echo "${REPO_URL}" | sed \
    -e 's|git@\([^:]*\):\(.*\)\.git|https://github.com/\2.git|' \
    -e 's|git@\([^:]*\):\(.*\)|https://github.com/\2|')
fi

TARGET_REVISION=$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)

echo "  repoURL        : ${REPO_URL}"
echo "  targetRevision : ${TARGET_REVISION}"

# Substitute placeholders and apply
APPSET_FILE="${SCRIPT_DIR}/argocd/applicationset.yaml"
sed \
  -e "s|__REPO_URL__|${REPO_URL}|g" \
  -e "s|__TARGET_REVISION__|${TARGET_REVISION}|g" \
  "${APPSET_FILE}" | \
  kubectl apply -f - --context "${MASTER_CTX}"

echo ""
echo "✅ Setup complete!"
echo ""
echo "   Master context  : ${MASTER_CTX}"
echo "   Worker 1 context: kind-argocd-worker-1"
echo "   Worker 2 context: kind-argocd-worker-2"
echo ""
echo "   ArgoCD UI : http://localhost:30080"
echo "   Username  : admin"
echo "   Password  : $(kubectl get secret argocd-initial-admin-secret \
                        -n argocd \
                        --context "${MASTER_CTX}" \
                        -o jsonpath='{.data.password}' | base64 -d)"
echo ""
echo "   ArgoCD will begin syncing within ~3 minutes."
echo "   Monitor progress:"
echo "     kubectl get applications -n argocd --context ${MASTER_CTX}"
echo ""
echo "   Next: follow the experiment README.md"
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x argocd/01-multi-cluster-federation/setup.sh
git add argocd/01-multi-cluster-federation/setup.sh
git commit -m "feat(argocd-federation): add setup.sh"
```

---

## Task 6: Create `README.md`

**Files:**
- Create: `argocd/01-multi-cluster-federation/README.md`

- [ ] **Step 1: Create `README.md`**

Create `argocd/01-multi-cluster-federation/README.md`:

```markdown
# ArgoCD Multi-Cluster Federation

A hands-on experiment demonstrating GitOps-driven multi-cluster federation using ArgoCD.

**What you will see:**
- ArgoCD installed on a single master kind cluster managing itself and two worker clusters
- A single `ApplicationSet` with a `clusters` generator creating one Application per cluster
- Kubernetes resources (Namespace, ServiceAccounts, RBAC, ConfigMap) synced to all three clusters from a single Git path — with no direct `kubectl apply` to the workers
- GitOps in action: edit a manifest, push to Git, watch ArgoCD sync the change to all three clusters simultaneously

---

## Prerequisites

- `kind` installed
- `kubectl` installed
- `docker` running
- Repo pushed to a remote (ArgoCD inside the kind cluster pulls from Git over HTTPS)

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

---

## Setup

```bash
cd argocd/01-multi-cluster-federation
bash setup.sh
```

`setup.sh` does the following:

1. Creates `kind-argocd-master`, `kind-argocd-worker-1`, `kind-argocd-worker-2`
2. Installs ArgoCD on the master cluster
3. Creates a dedicated `argocd-manager` ServiceAccount on each worker and registers each worker as an ArgoCD external cluster Secret (with the worker's Docker bridge IP as the API server address)
4. Labels the built-in `in-cluster` Secret so the ApplicationSet targets the master too
5. Detects the Git remote URL and current branch, substitutes them into the ApplicationSet, and applies it

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

If applications show `OutOfSync` or `Progressing`, ArgoCD may still be syncing. Wait a moment and re-run.

### Step 2 — Verify resources on the master cluster

```bash
kubectl get namespace federation-demo --context kind-argocd-master
kubectl get serviceaccounts -n federation-demo --context kind-argocd-master
kubectl get role,rolebinding -n federation-demo --context kind-argocd-master
kubectl get configmap app-config -n federation-demo --context kind-argocd-master -o yaml
```

### Step 3 — Verify resources on worker-1 (no direct kubectl apply was used)

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

> **Key observation:** The same resources are present on all three clusters. None of the worker clusters had `kubectl apply` run against them directly — ArgoCD did it all from the Git source.

### Step 5 — Demonstrate GitOps sync (edit + push)

Edit `gitops/base/configmap.yaml` — change `demo-message`:

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

Wait ~3 minutes (ArgoCD's default poll interval), then verify on all three clusters:

```bash
for ctx in kind-argocd-master kind-argocd-worker-1 kind-argocd-worker-2; do
  echo "=== ${ctx} ==="
  kubectl get configmap app-config -n federation-demo --context "${ctx}" \
    -o jsonpath='{.data.demo-message}{"\n"}'
done
```

Expected: all three clusters show `Updated by GitOps — all clusters will sync!`

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

Login with username `admin` and the password from above.

You will see all three Applications and can browse synced resources per cluster.

---

## Key Observations

| What to observe | Where to look |
|---|---|
| 3 Applications created by ApplicationSet | `kubectl get applications -n argocd --context kind-argocd-master` |
| Resources on master (no manual apply) | `kubectl get all -n federation-demo --context kind-argocd-master` |
| Resources on worker-1 (no manual apply) | `kubectl get all -n federation-demo --context kind-argocd-worker-1` |
| Resources on worker-2 (no manual apply) | `kubectl get all -n federation-demo --context kind-argocd-worker-2` |
| ConfigMap updated after Git push | `kubectl get cm app-config -n federation-demo -o yaml --context kind-argocd-worker-1` |
| ArgoCD cluster registrations | `kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster --context kind-argocd-master` |

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

The ApplicationSet `clusters` generator discovers Secrets in the `argocd` namespace with label `argocd.argoproj.io/secret-type=cluster` that also match the `argocd.argoproj.io/federation-demo=true` label selector. For each matching Secret, it creates one Application. The `{{name}}` and `{{server}}` template variables are populated from the Secret's `data.name` and `data.server` fields.

---

## Cleanup

```bash
bash teardown.sh
```

---

## References

- [ArgoCD ApplicationSet docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [ArgoCD Cluster Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/)
- [ArgoCD Declarative Setup (cluster Secrets)](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters)
- [kind documentation](https://kind.sigs.k8s.io/)
```

- [ ] **Step 2: Commit**

```bash
git add argocd/01-multi-cluster-federation/README.md
git commit -m "feat(argocd-federation): add README with experiment walkthrough"
```

---

## Task 7: Smoke test the setup

These steps verify the files are correct before a full cluster run.

- [ ] **Step 1: Validate all YAML files are well-formed**

```bash
for f in argocd/01-multi-cluster-federation/gitops/base/*.yaml \
          argocd/01-multi-cluster-federation/argocd/applicationset.yaml \
          argocd/01-multi-cluster-federation/kind-*.yaml; do
  echo "Checking ${f}..."
  kubectl apply --dry-run=client -f "${f}" 2>/dev/null || \
    python3 -c "import yaml,sys; list(yaml.safe_load_all(open('${f}')))" && echo "  OK"
done
```

Expected: all files report OK or `dry-run` passes. The ApplicationSet will fail dry-run (CRD not present locally) — that is expected; the python fallback verifies YAML syntax.

- [ ] **Step 2: Verify setup.sh is executable and has no syntax errors**

```bash
bash -n argocd/01-multi-cluster-federation/setup.sh && echo "setup.sh: syntax OK"
bash -n argocd/01-multi-cluster-federation/teardown.sh && echo "teardown.sh: syntax OK"
```

Expected: both print `syntax OK`.

- [ ] **Step 3: Run setup.sh end-to-end**

```bash
cd argocd/01-multi-cluster-federation
bash setup.sh
```

Expected: Script completes with `✅ Setup complete!` and prints the ArgoCD UI URL and password.

- [ ] **Step 4: Verify Applications are Synced**

```bash
# Wait ~3 minutes for initial sync, then:
kubectl get applications -n argocd --context kind-argocd-master
```

Expected:
```
NAME                              SYNC STATUS   HEALTH STATUS
federation-demo-argocd-master     Synced        Healthy
federation-demo-argocd-worker-1   Synced        Healthy
federation-demo-argocd-worker-2   Synced        Healthy
```

- [ ] **Step 5: Verify resources on all three clusters**

```bash
for ctx in kind-argocd-master kind-argocd-worker-1 kind-argocd-worker-2; do
  echo "=== ${ctx} ==="
  kubectl get ns federation-demo --context "${ctx}" --no-headers
  kubectl get sa -n federation-demo --context "${ctx}" --no-headers
  kubectl get role,rolebinding -n federation-demo --context "${ctx}" --no-headers
  kubectl get cm app-config -n federation-demo --context "${ctx}" --no-headers
done
```

Expected: Each cluster shows the `federation-demo` namespace, `app-sa` + `monitoring-sa` ServiceAccounts, `app-role` Role, `app-sa-binding` RoleBinding, and `app-config` ConfigMap.

- [ ] **Step 6: Commit any fixes found during testing, then push**

```bash
git push -u origin feat/argocd-multi-cluster-federation
```

- [ ] **Step 7: Teardown after verification**

```bash
bash teardown.sh
```

Expected: `✅ All clusters deleted.`

---

## Self-Review Checklist

- [x] kind cluster configs created (Task 1)
- [x] GitOps manifests created: namespace, SAs, RBAC, ConfigMap (Task 2)
- [x] ApplicationSet with cluster generator and placeholder substitution (Task 3)
- [x] teardown.sh (Task 4)
- [x] setup.sh covering all 6 setup steps from the spec (Task 5)
- [x] README with experiment walkthrough matching spec's 8-step outline (Task 6)
- [x] End-to-end smoke test steps (Task 7)
- [x] No TBD/TODO placeholders
- [x] SSH-to-HTTPS remote URL conversion handled in setup.sh (matches repo's actual remote format `git@github.com-personal:...`)
- [x] in-cluster Secret labelling step present
- [x] Worker cluster API server rewritten to Docker bridge IP
