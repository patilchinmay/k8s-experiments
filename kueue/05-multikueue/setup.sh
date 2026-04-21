#!/usr/bin/env bash
# setup.sh
# Creates two Kind clusters (kueue-manager + kueue-worker) and installs
# cert-manager + Kueue + all job-framework CRDs on both clusters for the
# MultiKueue experiment.
# Run from within this directory: bash setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUEUE_VERSION="0.17.0"

# ---------------------------------------------------------------------------
# Dependency versions — must match the integrations.frameworks list in
# values.yaml so that Kueue can watch these CRDs on the worker cluster.
# Versions sourced from kueue v0.17.0 go.mod.
# ---------------------------------------------------------------------------
JOBSET_VERSION="v0.11.1"
MPI_VERSION="v0.8.0"
LWS_VERSION="v0.8.0"
TRAINING_OPERATOR_VERSION="v1.9.3"
KUBERAY_VERSION="v1.6.0"
APPWRAPPER_VERSION="v1.2.0"
KUBEFLOW_TRAINER_VERSION="v2.2.0"
SPARK_OPERATOR_VERSION="v2.5.0"

# ---------------------------------------------------------------------------
# Helper: install cert-manager + Kueue on a given context
# ---------------------------------------------------------------------------
install_kueue() {
  local context="$1"
  local values_file="$2"
  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "  Installing cert-manager + Kueue on context: ${context}"
  echo "══════════════════════════════════════════════════════════════════"

  helm install \
    cert-manager oci://quay.io/jetstack/charts/cert-manager \
    --version v1.20.2 \
    --namespace cert-manager \
    --create-namespace \
    --set crds.enabled=true \
    --kube-context "${context}"

  kubectl wait deploy/cert-manager          -n cert-manager --for=condition=available --timeout=5m --context "${context}"
  kubectl wait deploy/cert-manager-cainjector -n cert-manager --for=condition=available --timeout=5m --context "${context}"
  kubectl wait deploy/cert-manager-webhook  -n cert-manager --for=condition=available --timeout=5m --context "${context}"

  helm install kueue oci://registry.k8s.io/kueue/charts/kueue \
    --version="${KUEUE_VERSION}" \
    --namespace kueue-system \
    --create-namespace \
    --wait --timeout 300s \
    --values "${values_file}" \
    --kube-context "${context}"
}

# ---------------------------------------------------------------------------
# Helper: install all job-framework CRDs on a given context.
# MultiKueue requires that every framework listed in integrations.frameworks
# has its CRDs present on the worker cluster, otherwise the Watch call fails
# with "no matches for kind" and the MultiKueueCluster goes Active=False.
# ---------------------------------------------------------------------------
install_crds() {
  local context="$1"
  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "  Installing job-framework CRDs on context: ${context}"
  echo "══════════════════════════════════════════════════════════════════"

  # ── JobSet ──────────────────────────────────────────────────────────────
  echo "  -> JobSet ${JOBSET_VERSION}"
  helm install jobset oci://registry.k8s.io/jobset/charts/jobset \
    --version "${JOBSET_VERSION#v}" \
    --namespace jobset-system \
    --create-namespace \
    --wait --timeout 300s \
    --kube-context "${context}"

  # # ── Kubeflow MPI Operator ────────────────────────────────────────────────
  # echo "  -> MPI Operator ${MPI_VERSION}"
  # kubectl apply --server-side -f \
  #   "https://raw.githubusercontent.com/kubeflow/mpi-operator/${MPI_VERSION}/deploy/v2beta1/mpi-operator.yaml" \
  #   --context "${context}"

  # # ── LeaderWorkerSet ──────────────────────────────────────────────────────
  # echo "  -> LeaderWorkerSet ${LWS_VERSION}"
  # kubectl apply --server-side -f \
  #   "https://github.com/kubernetes-sigs/lws/releases/download/${LWS_VERSION}/manifests.yaml" \
  #   --context "${context}"

  # ── Kubeflow Training Operator (PyTorchJob, TFJob, XGBoostJob, etc.) ─────
  echo "  -> Kubeflow Training Operator ${TRAINING_OPERATOR_VERSION}"
  kubectl apply --server-side -k \
    "github.com/kubeflow/training-operator.git/manifests/overlays/standalone?ref=${TRAINING_OPERATOR_VERSION}" \
    --context "${context}"

  # ── Kubeflow Trainer (TrainJob) ──────────────────────────────────────────
  echo "  -> Kubeflow Trainer ${KUBEFLOW_TRAINER_VERSION}"
  # Chart: ghcr.io/kubeflow/charts/kubeflow-trainer (version without 'v' prefix)
  # Disable bundled jobset sub-chart since we install JobSet separately above.
  helm install kubeflow-trainer oci://ghcr.io/kubeflow/charts/kubeflow-trainer \
    --version "${KUBEFLOW_TRAINER_VERSION#v}" \
    --namespace kubeflow \
    --create-namespace \
    --set jobset.install=false \
    --wait --timeout 300s \
    --kube-context "${context}"

  # # ── KubeRay (RayJob, RayService, RayCluster) ────────────────────────────
  # # KubeRay does not publish a single-file manifest; install CRDs from the
  # # helm chart source tree.
  # echo "  -> KubeRay CRDs ${KUBERAY_VERSION}"
  # kubectl apply --server-side -f \
  #   "https://raw.githubusercontent.com/ray-project/kuberay/${KUBERAY_VERSION}/helm-chart/kuberay-operator/crds/ray.io_rayclusters.yaml" \
  #   --context "${context}"
  # kubectl apply --server-side -f \
  #   "https://raw.githubusercontent.com/ray-project/kuberay/${KUBERAY_VERSION}/helm-chart/kuberay-operator/crds/ray.io_rayjobs.yaml" \
  #   --context "${context}"
  # kubectl apply --server-side -f \
  #   "https://raw.githubusercontent.com/ray-project/kuberay/${KUBERAY_VERSION}/helm-chart/kuberay-operator/crds/ray.io_rayservices.yaml" \
  #   --context "${context}"

  # # ── AppWrapper ───────────────────────────────────────────────────────────
  # echo "  -> AppWrapper ${APPWRAPPER_VERSION}"
  # kubectl apply --server-side -f \
  #   "https://github.com/project-codeflare/appwrapper/releases/download/${APPWRAPPER_VERSION}/install.yaml" \
  #   --context "${context}"

  # ── Spark Operator ───────────────────────────────────────────────────────
  # Spark Operator is commented out in values.yaml integrations but we install
  # the CRD anyway to keep the list consistent.
  # (Uncomment the line below if you enable sparkoperator in values.yaml)
  # echo "  -> Spark Operator CRDs ${SPARK_OPERATOR_VERSION}"
  # kubectl apply --server-side -f \
  #   "https://raw.githubusercontent.com/kubeflow/spark-operator/${SPARK_OPERATOR_VERSION}/config/crd/bases/sparkoperator.k8s.io_sparkapplications.yaml" \
  #   --context "${context}"

  echo "  ✅ CRDs installed on ${context}"
}

# ---------------------------------------------------------------------------
# 1. Create the manager cluster
# ---------------------------------------------------------------------------
echo "==> Creating manager cluster (kueue-manager)..."
kind create cluster --name kueue-manager --config "${SCRIPT_DIR}/kind-manager.yaml"
kubectl cluster-info --context kind-kueue-manager
kubectl wait deploy/coredns -n kube-system --for=condition=available --timeout=5m --context kind-kueue-manager

# ---------------------------------------------------------------------------
# 2. Create the worker cluster
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating worker cluster (kueue-worker)..."
kind create cluster --name kueue-worker --config "${SCRIPT_DIR}/kind-worker.yaml"
kubectl cluster-info --context kind-kueue-worker
kubectl wait deploy/coredns -n kube-system --for=condition=available --timeout=5m --context kind-kueue-worker

# ---------------------------------------------------------------------------
# 3. Install job-framework CRDs on BOTH clusters
#    This is required so that MultiKueue can Watch all enabled frameworks on
#    the worker cluster without getting "no matches for kind" errors.
# ---------------------------------------------------------------------------
install_crds "kind-kueue-manager"
install_crds "kind-kueue-worker"

# ---------------------------------------------------------------------------
# 4. Install Kueue on both clusters
#    - Manager: values.yaml has MultiKueue feature gate enabled
#    - Worker:  same values.yaml is fine; MultiKueue feature gate is harmless
#               on the worker (it just won't create MultiKueue objects there)
# ---------------------------------------------------------------------------
install_kueue "kind-kueue-manager" "${SCRIPT_DIR}/values.yaml"
install_kueue "kind-kueue-worker"  "${SCRIPT_DIR}/values.yaml"

# ---------------------------------------------------------------------------
# 5. Extract the worker cluster's kubeconfig and store it as a Secret on the
#    manager cluster.  MultiKueueCluster references this Secret to connect to
#    the worker.
#
# Docker network topology — why WORKER_CP_IP works:
#   Kind does NOT create a separate Docker network per cluster.
#   ALL Kind clusters on the same host share a single Docker bridge network
#   named "kind" (typically 172.18.0.0/16).  Every node container from every
#   cluster is attached to this same bridge, so they can reach each other
#   directly by IP:
#
#     Docker host
#     └── bridge network: "kind"  (172.18.0.0/16)
#         ├── kueue-manager-control-plane  172.18.0.2
#         ├── kueue-manager-worker         172.18.0.3
#         ├── kueue-manager-worker2        172.18.0.4
#         ├── kueue-worker-control-plane   172.18.0.5  ← WORKER_CP_IP
#         ├── kueue-worker-worker          172.18.0.6
#         └── kueue-worker-worker2         172.18.0.7
#
#   You can verify with:
#     docker network ls                   # → one network named "kind"
#     docker inspect kind | \
#       jq '.[0].Containers[].Name'       # → all cluster containers listed
#
# Why we must rewrite the API server address:
#   Kind writes the kubeconfig with server: https://127.0.0.1:<host-port>.
#   That works from your laptop's terminal (host network), but from inside
#   the manager cluster's containers 127.0.0.1 refers to the container
#   itself — not the worker.  We replace it with the worker control-plane
#   container's bridge IP so that Kueue's controller pod (running inside
#   the manager cluster) can TCP-connect to the worker API server over the
#   shared "kind" bridge network.
#
#   --internal flag on `kind get kubeconfig` gives us the Docker-internal
#   hostname (kueue-worker-control-plane:6443) instead of 127.0.0.1, which
#   we then replace with the raw IP for maximum reliability (hostname DNS
#   resolution across Kind clusters on the same bridge can be unreliable).
# ---------------------------------------------------------------------------
echo ""
echo "==> Extracting worker kubeconfig and creating Secret on manager..."

WORKER_CP_IP=$(docker inspect kueue-worker-control-plane \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

echo "   Worker control-plane container IP: ${WORKER_CP_IP}"
echo "   (reachable from manager containers via the shared 'kind' Docker bridge)"

# Export the worker kubeconfig, swap the server address, then create the Secret.
#
# IMPORTANT — Secret placement rules (from Kueue source):
#   - Namespace : kueue-system  (Kueue always looks in its own config namespace)
#   - Data key  : kubeconfig    (must be exactly "kubeconfig")
#   - location  in MultiKueueCluster: just the Secret NAME (not "namespace/name")
#
# The `create --dry-run=client -o yaml | apply` pattern makes this idempotent:
#   `kubectl create` would fail if the Secret already exists; piping through
#   `kubectl apply` updates it instead, so setup.sh can be re-run safely.
kind get kubeconfig --name kueue-worker --internal | \
  sed "s|https://kueue-worker-control-plane:6443|https://${WORKER_CP_IP}:6443|g" \
  > /tmp/kueue-worker-kubeconfig.yaml

kubectl create secret generic kueue-worker-kubeconfig \
  --from-file=kubeconfig=/tmp/kueue-worker-kubeconfig.yaml \
  --namespace kueue-system \
  --context kind-kueue-manager \
  --dry-run=client -o yaml | \
  kubectl apply -f - --context kind-kueue-manager

# Remove the temp file so cluster credentials don't linger on disk.
rm -f /tmp/kueue-worker-kubeconfig.yaml

echo ""
echo "✅ Both clusters and Kueue are ready."
echo ""
echo "   Manager context : kind-kueue-manager"
echo "   Worker context  : kind-kueue-worker"
echo ""
echo "   Worker kubeconfig Secret created:"
echo "     namespace : kueue-system"
echo "     name      : kueue-worker-kubeconfig"
echo "     data key  : kubeconfig"
echo ""
echo "   Next: follow the experiment README.md"
