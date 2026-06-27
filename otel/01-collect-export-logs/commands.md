# Create cluster

kind create cluster --config kind.yaml

# Install cert-manager

helm install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.20.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

kubectl wait deploy/cert-manager -n cert-manager --for=condition=available --timeout=5m
kubectl wait deploy/cert-manager-cainjector -n cert-manager --for=condition=available --timeout=5m
kubectl wait deploy/cert-manager-webhook -n cert-manager --for=condition=available --timeout=5m

# Install Otel Collector
<!--https://opentelemetry.io/docs/platforms/kubernetes/helm/collector/-->
<!--https://github.com/open-telemetry/opentelemetry-helm-charts/blob/main/charts/opentelemetry-collector/values.yaml-->
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm install my-opentelemetry-collector open-telemetry/opentelemetry-collector \
   --set image.repository="otel/opentelemetry-collector-k8s" \
   --set mode=daemonset \
   -f values.yaml

# Install Loki

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki \
  --namespace monitoring \
  --create-namespace \
  --set deploymentMode=SingleBinary \
  --set loki.auth_enabled=false \
  --set loki.useTestSchema=true \
  --set singleBinary.replicas=1 \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set minio.enabled=false \
  --set backend.replicas=0 \
  --set read.replicas=0 \
  --set write.replicas=0

kubectl wait pod -l app.kubernetes.io/name=loki -n monitoring --for=condition=ready --timeout=5m

# Install Grafana

helm install grafana grafana/grafana \
  --namespace monitoring \
  --set adminPassword=admin \
  --set service.type=NodePort \
  --set service.nodePort=30000 \
  --set "datasources.datasources\.yaml.apiVersion=1" \
  --set "datasources.datasources\.yaml.datasources[0].name=Loki" \
  --set "datasources.datasources\.yaml.datasources[0].type=loki" \
  --set "datasources.datasources\.yaml.datasources[0].url=http://loki-gateway.monitoring.svc.cluster.local" \
  --set "datasources.datasources\.yaml.datasources[0].access=proxy" \
  --set "datasources.datasources\.yaml.datasources[0].isDefault=true"

kubectl wait pod -l app.kubernetes.io/name=grafana -n monitoring --for=condition=ready --timeout=5m

# Upgrade OTel Collector to export logs to Loki
<!--https://opentelemetry.io/docs/platforms/kubernetes/helm/collector/-->
<!--https://github.com/open-telemetry/opentelemetry-helm-charts/blob/main/charts/opentelemetry-collector/values.yaml-->
helm upgrade my-opentelemetry-collector open-telemetry/opentelemetry-collector \
   --set image.repository="otel/opentelemetry-collector-k8s" \
   --set mode=daemonset \
   -f values.yaml

# Access Grafana at http://localhost:30000 (admin/admin)
# Explore -> Loki -> query: {k8s_container_name="bash-counter"}
