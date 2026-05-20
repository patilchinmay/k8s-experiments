#!/usr/bin/env bash
# setup.sh
# Creates 4 Kind clusters (kueue-mgmt + kueue-worker-1/2/3),
# installs ArgoCD on mgmt, registers workers as ArgoCD external clusters,
# creates MultiKueue kubeconfig Secrets on mgmt,
# and applies the ApplicationSets that install Kueue (via OCI chart) and
# sync Kueue resources (via the local Helm chart) on all clusters.
#
# Run from within this directory: bash setup.sh
#
# Prerequisites: kind, kubectl, docker, git

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_VERSION="v3.3.8"
KUEUE_VERSION="0.17.3"
MGMT_CTX="kind-kueue-mgmt"

# ---------------------------------------------------------------------------
# Helper: wait for all deployments in a namespace to be Available
# ---------------------------------------------------------------------------
wait_for_deployments() {
  local ctx="$1" ns="$2"
  echo "  Waiting for all deployments in ${ns} on ${ctx}..."
  kubectl wait deploy --all -n "${ns}" \
    --for=condition=Available --timeout=5m --context "${ctx}"
}

# ---------------------------------------------------------------------------
# Helper: create a kubeconfig Secret on mgmt for MultiKueue to reach a worker
# ---------------------------------------------------------------------------
create_multikueue_secret() {
  local worker_name="$1"   # e.g. kueue-worker-1
  local secret_name="$2"   # e.g. worker-1-secret
  local cp_container="${worker_name}-control-plane"
  local worker_ip
  worker_ip=$(docker inspect "${cp_container}" \
    --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
  local tmp_file="/tmp/${secret_name}.yaml"
  kind get kubeconfig --name "${worker_name}" --internal | \
    sed "s|https://${worker_name}-control-plane:6443|https://${worker_ip}:6443|g" \
    > "${tmp_file}"
  kubectl create secret generic "${secret_name}" \
    --from-file=kubeconfig="${tmp_file}" \
    --namespace kueue-system --context "${MGMT_CTX}" \
    --dry-run=client -o yaml | kubectl apply -f - --context "${MGMT_CTX}"
  rm -f "${tmp_file}"
  echo "  ✅ MultiKueue secret ${secret_name} created on mgmt"
}

# ---------------------------------------------------------------------------
# Helper: register a worker cluster as an ArgoCD external cluster Secret
# ---------------------------------------------------------------------------
register_argocd_cluster() {
  local worker_name="$1"   # e.g. kueue-worker-1
  local secret_name="$2"   # e.g. kueue-worker-1-cluster-secret
  local role_label="$3"    # e.g. worker-1
  local worker_ctx="kind-${worker_name}"

  echo ""
  echo "  Registering ${worker_name} as ArgoCD external cluster (role=${role_label})..."

  local cp_container="${worker_name}-control-plane"
  local worker_ip
  worker_ip=$(docker inspect "${cp_container}" \
    --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
  local server_url="https://${worker_ip}:6443"

  # Create argocd-manager SA + token + ClusterRoleBinding on the worker
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

  echo "  Waiting for argocd-manager-token to be populated..."
  local token=""
  for i in $(seq 1 30); do
    token=$(kubectl get secret argocd-manager-token -n kube-system \
      --context "${worker_ctx}" \
      -o jsonpath='{.data.token}' 2>/dev/null || true)
    [ -n "${token}" ] && break
    sleep 2
  done
  [ -z "${token}" ] && { echo "ERROR: token not populated on ${worker_name}"; exit 1; }

  local bearer_token ca_data config_json
  bearer_token=$(echo "${token}" | base64 -d)
  ca_data=$(kubectl get secret argocd-manager-token -n kube-system \
    --context "${worker_ctx}" -o jsonpath='{.data.ca\.crt}')
  config_json="{\"tlsClientConfig\":{\"insecure\":false,\"caData\":\"${ca_data}\"},\"bearerToken\":\"${bearer_token}\"}"

  kubectl create secret generic "${secret_name}" \
    --namespace argocd --context "${MGMT_CTX}" \
    --from-literal=name="${worker_name}" \
    --from-literal=server="${server_url}" \
    --from-literal=config="${config_json}" \
    --dry-run=client -o yaml | \
  kubectl annotate --local -f - "managed-by=argocd.argoproj.io" --dry-run=client -o yaml | \
  kubectl label --local -f - \
    "argocd.argoproj.io/secret-type=cluster" \
    "kueue-poc-role=${role_label}" \
    "kueue-poc-cluster=true" \
    --dry-run=client -o yaml | \
  kubectl apply -f - --context "${MGMT_CTX}"

  echo "  ✅ Registered ${worker_name} (${server_url}) as ArgoCD cluster"
}

# ── 1. Create clusters ────────────────────────────────────────────────────────
echo "==> Creating Kind clusters..."
kind create cluster --name kueue-mgmt    --config "${SCRIPT_DIR}/kind-mgmt.yaml"
kind create cluster --name kueue-worker-1 --config "${SCRIPT_DIR}/kind-worker-1.yaml"
kind create cluster --name kueue-worker-2 --config "${SCRIPT_DIR}/kind-worker-2.yaml"
kind create cluster --name kueue-worker-3 --config "${SCRIPT_DIR}/kind-worker-3.yaml"

for ctx in kind-kueue-mgmt kind-kueue-worker-1 kind-kueue-worker-2 kind-kueue-worker-3; do
  kubectl wait deploy/coredns -n kube-system --for=condition=Available --timeout=5m --context "${ctx}"
done

# ── 2. Create MultiKueue worker kubeconfig Secrets on mgmt ───────────────────
echo ""
echo "==> Creating MultiKueue worker kubeconfig Secrets on mgmt..."
kubectl create namespace kueue-system --context "${MGMT_CTX}" || true
create_multikueue_secret "kueue-worker-1" "worker-1-secret"
create_multikueue_secret "kueue-worker-2" "worker-2-secret"
create_multikueue_secret "kueue-worker-3" "worker-3-secret"

# ── 3. Install ArgoCD on mgmt ─────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Installing ArgoCD ${ARGOCD_VERSION} on ${MGMT_CTX}"
echo "══════════════════════════════════════════════════════════════════"
kubectl create namespace argocd --context "${MGMT_CTX}" || true
kubectl apply -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
  --context "${MGMT_CTX}" --server-side
wait_for_deployments "${MGMT_CTX}" argocd

# ── 4. Expose ArgoCD UI via NodePort 30080 ───────────────────────────────────
echo ""
echo "==> Patching argocd-server to NodePort 30080..."
kubectl patch svc argocd-server -n argocd --context "${MGMT_CTX}" \
  --type='json' \
  -p='[
    {"op":"replace","path":"/spec/type","value":"NodePort"},
    {"op":"add","path":"/spec/ports/0/nodePort","value":30080}
  ]'

# ── 5. Label the in-cluster Secret so mgmt ApplicationSets target it ─────────
echo ""
echo "==> Creating in-cluster Secret (labelled kueue-poc-role=mgmt, kueue-poc-cluster=true)..."
kubectl create secret generic in-cluster \
  --namespace argocd --context "${MGMT_CTX}" \
  --from-literal=name="in-cluster" \
  --from-literal=server="https://kubernetes.default.svc" \
  --from-literal=config='{"tlsClientConfig":{"insecure":false}}' \
  --dry-run=client -o yaml | \
kubectl label --local -f - \
  "argocd.argoproj.io/secret-type=cluster" \
  "kueue-poc-role=mgmt" \
  "kueue-poc-cluster=true" \
  --dry-run=client -o yaml | \
kubectl apply -f - --context "${MGMT_CTX}"
echo "  ✅ in-cluster Secret created"

# ── 6. Register workers as ArgoCD external clusters ──────────────────────────
echo ""
echo "==> Registering worker clusters with ArgoCD..."
register_argocd_cluster "kueue-worker-1" "kueue-worker-1-cluster-secret" "worker-1"
register_argocd_cluster "kueue-worker-2" "kueue-worker-2-cluster-secret" "worker-2"
register_argocd_cluster "kueue-worker-3" "kueue-worker-3-cluster-secret" "worker-3"

# ── 7. Apply ApplicationSets ──────────────────────────────────────────────────
echo ""
echo "==> Detecting Git remote URL and current branch..."
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"
REPO_URL=$(git -C "${REPO_ROOT}" remote get-url origin 2>/dev/null || true)

if [ -z "${REPO_URL}" ]; then
  echo "ERROR: No git remote 'origin' found."
  echo "       Push the branch to a remote and re-run setup.sh."
  exit 1
fi

# Convert SSH remote to HTTPS
if [[ "${REPO_URL}" == git@* ]]; then
  REPO_PATH=$(echo "${REPO_URL}" | sed 's|git@[^:]*:\(.*\)|\1|')
  REPO_URL="https://github.com/${REPO_PATH%.git}.git"
fi

TARGET_REVISION=$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)
echo "  repoURL        : ${REPO_URL}"
echo "  targetRevision : ${TARGET_REVISION}"

sed \
  -e "s|__REPO_URL__|${REPO_URL}|g" \
  -e "s|__TARGET_REVISION__|${TARGET_REVISION}|g" \
  -e "s|__KUEUE_VERSION__|${KUEUE_VERSION}|g" \
  "${SCRIPT_DIR}/argocd/app-of-appsets.yaml" | \
  kubectl apply -f - --context "${MGMT_CTX}"

# ── 8. Print summary ──────────────────────────────────────────────────────────
echo ""
echo "✅ Setup complete!"
echo ""
echo "   Clusters:"
echo "     kind-kueue-mgmt     — ArgoCD + Kueue manager + MultiKueue control plane"
echo "     kind-kueue-worker-1 — set-1 worker (GKE-like)"
echo "     kind-kueue-worker-2 — set-1 worker (EKS-like)"
echo "     kind-kueue-worker-3 — set-2 worker (BYOC/on-prem)"
echo ""
echo "   ArgoCD UI : http://localhost:30080"
echo "   Username  : admin"
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
  -n argocd --context "${MGMT_CTX}" \
  -o jsonpath='{.data.password}' | base64 -d)
echo "   Password  : ${ARGOCD_PASSWORD}"
echo ""
echo "   ArgoCD will begin syncing within ~3 minutes."
echo "   Monitor: kubectl get applications -n argocd --context ${MGMT_CTX}"
echo ""
echo "   Next: follow the README.md verification steps."
