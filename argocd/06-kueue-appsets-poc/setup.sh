#!/usr/bin/env bash
# setup.sh
# Creates two Kind clusters:
#   kueue-manager  : ArgoCD only (no Kueue)
#   kueue-worker-1 : worker cluster, registered in ArgoCD with the labels the
#                  ApplicationSets select on (kueue-enabled, kueue-resources-enabled)
# then applies the AppProject and the two ApplicationSets (Kueue controller + resources).
#
# Intended to run on a Linux host (Docker + kind + kubectl + git). Run from a clone
# whose current branch has been pushed to GitHub: ArgoCD pulls from Git.
#
#   bash setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_VERSION="v3.3.8"
MANAGER_CTX="kind-kueue-manager"
WORKER_CTX="kind-kueue-worker-1"
WORKER_SHORT_NAME="kueue-worker-1"

for bin in kind kubectl docker git; do
  command -v "${bin}" >/dev/null || { echo "ERROR: ${bin} not found"; exit 1; }
done

# ── Preflight: container runtime capacity (Docker Desktop VM on macOS, host on Linux) ──
DOCKER_CPUS="$(docker info --format '{{.NCPU}}')"
DOCKER_MEM_GIB=$(( $(docker info --format '{{.MemTotal}}') / 1024 / 1024 / 1024 ))
echo "Docker capacity: ${DOCKER_CPUS} CPU / ${DOCKER_MEM_GIB} GiB"
if [ "${DOCKER_CPUS}" -lt 4 ] || [ "${DOCKER_MEM_GIB}" -lt 6 ]; then
  echo "ERROR: need at least 4 CPU and 6 GiB available to Docker (see README, Resources)."
  exit 1
fi

# ── 0. Resolve repo URL / branch (ArgoCD pulls from Git) ─────────────────────
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"
REPO_URL="$(git -C "${REPO_ROOT}" remote get-url origin 2>/dev/null || true)"
[ -z "${REPO_URL}" ] && { echo "ERROR: no git remote 'origin'"; exit 1; }

# SSH remote (incl. host aliases like github.com-personal) -> HTTPS
if [[ "${REPO_URL}" == git@* ]]; then
  REPO_PATH="$(echo "${REPO_URL}" | sed 's|git@[^:]*:\(.*\)|\1|')"
  REPO_URL="https://github.com/${REPO_PATH%.git}.git"
fi

TARGET_REVISION="${TARGET_REVISION:-$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)}"
REMOTE_SHA="$(git -C "${REPO_ROOT}" ls-remote origin "refs/heads/${TARGET_REVISION}" | cut -f1)"
if [ -z "${REMOTE_SHA}" ]; then
  echo "ERROR: branch '${TARGET_REVISION}' is not pushed to origin. Push it first."
  exit 1
fi
if [ "${REMOTE_SHA}" != "$(git -C "${REPO_ROOT}" rev-parse HEAD)" ]; then
  echo "WARN: local HEAD differs from origin/${TARGET_REVISION}; ArgoCD will use the pushed version."
fi
echo "repoURL        : ${REPO_URL}"
echo "targetRevision : ${TARGET_REVISION}"

# ── 1. Create clusters ───────────────────────────────────────────────────────
echo "==> Creating Kind clusters..."
kind create cluster --name kueue-manager  --config "${SCRIPT_DIR}/kind-manager.yaml"
kind create cluster --name kueue-worker-1 --config "${SCRIPT_DIR}/kind-worker-1.yaml"

for ctx in "${MANAGER_CTX}" "${WORKER_CTX}"; do
  kubectl wait deploy/coredns -n kube-system --for=condition=Available --timeout=5m --context "${ctx}"
done

# ── 2. Prepare the worker cluster ──────────────────────────────────────────
# Node label matched by the `default` ResourceFlavor (see overlays/dev/kueue-worker-1/values.yaml).
echo "==> Labelling worker node and creating team namespaces..."
kubectl label node kueue-worker-1-worker karpenter.sh/nodepool=cpu-nodes --overwrite --context "${WORKER_CTX}"
# Team namespaces are provisioned outside the kueue-resources chart (as in the real clusters).
for ns in team-a team-b; do
  kubectl create namespace "${ns}" --context "${WORKER_CTX}" --dry-run=client -o yaml | \
    kubectl apply -f - --context "${WORKER_CTX}"
done

# ── 3. Install ArgoCD on the manager ─────────────────────────────────────────────
echo "==> Installing ArgoCD ${ARGOCD_VERSION} on ${MANAGER_CTX}..."
kubectl create namespace argocd --context "${MANAGER_CTX}"
kubectl apply -n argocd --server-side --context "${MANAGER_CTX}" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

# Serve the UI over plain HTTP so an SSH tunnel to NodePort 30080 works without TLS redirects.
kubectl patch configmap argocd-cmd-params-cm -n argocd --context "${MANAGER_CTX}" \
  --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl rollout restart deploy/argocd-server -n argocd --context "${MANAGER_CTX}"

kubectl wait deploy --all -n argocd --for=condition=Available --timeout=5m --context "${MANAGER_CTX}"
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=5m --context "${MANAGER_CTX}"

kubectl patch svc argocd-server -n argocd --context "${MANAGER_CTX}" --type=json -p='[
  {"op":"replace","path":"/spec/type","value":"NodePort"},
  {"op":"add","path":"/spec/ports/0/nodePort","value":30080}
]'

# ── 4. Register the worker cluster in ArgoCD ───────────────────────────────
# Kind containers share the `kind` docker network, so the manager reaches the worker
# API server via its container IP.
echo "==> Registering ${WORKER_SHORT_NAME} in ArgoCD..."
WORKER_IP="$(docker inspect kueue-worker-1-control-plane \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
WORKER_SERVER="https://${WORKER_IP}:6443"

kubectl apply --context "${WORKER_CTX}" -f - <<EOF
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

TOKEN=""
for _ in $(seq 1 30); do
  TOKEN="$(kubectl get secret argocd-manager-token -n kube-system --context "${WORKER_CTX}" \
    -o jsonpath='{.data.token}' 2>/dev/null || true)"
  [ -n "${TOKEN}" ] && break
  sleep 2
done
[ -z "${TOKEN}" ] && { echo "ERROR: argocd-manager token not populated"; exit 1; }

BEARER="$(echo "${TOKEN}" | base64 -d)"
CA_DATA="$(kubectl get secret argocd-manager-token -n kube-system --context "${WORKER_CTX}" \
  -o jsonpath='{.data.ca\.crt}')"
CONFIG_JSON="{\"tlsClientConfig\":{\"insecure\":false,\"caData\":\"${CA_DATA}\"},\"bearerToken\":\"${BEARER}\"}"

# Labels match what kueue-enabled / kueue-resources-enabled ApplicationSets select on,
# and `short-name` selects the per-cluster resources overlay directory.
kubectl create secret generic "${WORKER_SHORT_NAME}-cluster-secret" \
  --namespace argocd --context "${MANAGER_CTX}" \
  --from-literal=name="${WORKER_SHORT_NAME}" \
  --from-literal=server="${WORKER_SERVER}" \
  --from-literal=config="${CONFIG_JSON}" \
  --dry-run=client -o yaml | \
kubectl label --local -f - \
  argocd.argoproj.io/secret-type=cluster \
  environment=dev \
  short-name="${WORKER_SHORT_NAME}" \
  kueue-enabled=true \
  kueue-resources-enabled=true \
  --dry-run=client -o yaml | \
kubectl apply -f - --context "${MANAGER_CTX}"

# ── 5. Apply AppProject + ApplicationSets ────────────────────────────────────
echo "==> Applying AppProject and ApplicationSets..."
kubectl apply -f "${SCRIPT_DIR}/argocd/appproject.yaml" --context "${MANAGER_CTX}"
for f in kueue-controller.yaml kueue-resources.yaml; do
  sed \
    -e "s|__REPO_URL__|${REPO_URL}|g" \
    -e "s|__TARGET_REVISION__|${TARGET_REVISION}|g" \
    "${SCRIPT_DIR}/argocd/${f}" | kubectl apply -f - --context "${MANAGER_CTX}"
done

# ── 6. Summary ───────────────────────────────────────────────────────────────
ARGOCD_PASSWORD="$(kubectl get secret argocd-initial-admin-secret -n argocd --context "${MANAGER_CTX}" \
  -o jsonpath='{.data.password}' | base64 -d)"
cat <<EOF

Setup complete.

  Manager cluster  : ${MANAGER_CTX}   (ArgoCD)
  Worker cluster   : ${WORKER_CTX}   (Kueue, team-a / team-b)

  ArgoCD UI (bound to 127.0.0.1:30080 of the machine running the clusters):
    local Mac        : http://localhost:30080
    Linux via SSH    : ssh -L 8080:localhost:30080 <user>@<server>  ->  http://localhost:8080
  Login: admin / ${ARGOCD_PASSWORD}

  Watch:  kubectl get applications -n argocd --context ${MANAGER_CTX}
EOF
