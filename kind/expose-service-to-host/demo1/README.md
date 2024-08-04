# Expose service on Kind Host

Create a deployment and service in a kind cluster.

Expose the service so that it is accesible from the host machine on which kind cluster is running.

# Process

- `kind create cluster --config kind.yaml`
- `kubectl apply -f deployment.yaml`
- `kubectl apply -f service.yaml`
- `curl http://localhost:30000/api`