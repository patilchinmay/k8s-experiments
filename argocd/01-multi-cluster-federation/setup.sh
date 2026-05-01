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
ARGOCD_VERSION="v3.3.8"
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
# We create a dedicated argocd-manager ServiceAccount on the worker cluster
# and use its long-lived token as the bearerToken so ArgoCD can authenticate
# to the worker API server.
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

  # Create a dedicated ServiceAccount + long-lived token Secret + ClusterRoleBinding
  # in the worker for ArgoCD to use. ArgoCD needs cluster-admin to manage
  # arbitrary resources across all namespaces.
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

  # Wait for the token Secret to be populated by the token controller
  echo "  Waiting for argocd-manager-token to be populated..."
  local token=""
  for i in $(seq 1 30); do
    token=$(kubectl get secret argocd-manager-token \
      -n kube-system \
      --context "${worker_ctx}" \
      -o jsonpath='{.data.token}' 2>/dev/null || true)
    if [ -n "${token}" ]; then
      break
    fi
    sleep 2
  done

  if [ -z "${token}" ]; then
    echo "ERROR: argocd-manager-token was not populated after 60s on ${worker_name}"
    exit 1
  fi

  local bearer_token
  bearer_token=$(echo "${token}" | base64 -d)

  # Get the CA cert from the worker cluster (base64-encoded, as ArgoCD expects it)
  local ca_data
  ca_data=$(kubectl get secret argocd-manager-token \
    -n kube-system \
    --context "${worker_ctx}" \
    -o jsonpath='{.data.ca\.crt}')

  # Build the ArgoCD cluster config JSON.
  # caData is already base64-encoded from the Secret; ArgoCD expects raw base64 here.
  local config_json
  config_json="{\"tlsClientConfig\":{\"insecure\":false,\"caData\":\"${ca_data}\"},\"bearerToken\":\"${bearer_token}\"}"

  # Create the ArgoCD cluster Secret on the master.
  # The pipeline: create (dry-run) → annotate (dry-run) → label (dry-run) → apply
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
  --context "${MASTER_CTX}" \
  --server-side

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
# automatically on startup. We add the federation-demo label so the cluster
# generator includes the master cluster itself.
# ---------------------------------------------------------------------------
echo ""
echo "==> Labelling in-cluster Secret for ApplicationSet targeting..."
# The in-cluster Secret may take a few seconds to appear after ArgoCD starts.
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

# Convert SSH remote to HTTPS if needed, since ArgoCD runs inside a pod and
# has no access to the host's SSH keys or agent.
# Handles both standard SSH format (git@github.com:user/repo.git) and
# SSH host aliases (git@<alias>:user/repo.git) by discarding everything
# before the colon and treating the hostname as github.com.
if [[ "${REPO_URL}" == git@* ]]; then
  REPO_PATH=$(echo "${REPO_URL}" | sed 's|git@[^:]*:\(.*\)|\1|')
  REPO_URL="https://github.com/${REPO_PATH}"
  # Normalise: strip trailing .git then re-add for consistency
  REPO_URL="${REPO_URL%.git}.git"
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
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  --context "${MASTER_CTX}" \
  -o jsonpath='{.data.password}' | base64 -d)
echo "   Password  : ${ARGOCD_PASSWORD}"
echo ""
echo "   ArgoCD will begin syncing within ~3 minutes."
echo "   Monitor progress:"
echo "     kubectl get applications -n argocd --context ${MASTER_CTX}"
echo ""
echo "   Next: follow the experiment README.md"
