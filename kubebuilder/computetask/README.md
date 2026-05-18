# ComputeTask Operator

A Kubernetes operator that manages `ComputeTask` resources. When a `ComputeTask` is created with `suspend: false`, the controller creates a backing Pod that runs for `spec.durationSeconds` seconds and then exits. The controller watches the Pod phase and reflects it back into `status.phase`.

```
spec.suspend = false  →  Pod created  →  status.phase: Pending → Running → Succeeded
spec.suspend = true   →  Pod deleted  →  status.phase: Pending
```

## Prerequisites

- [Go](https://go.dev/) v1.24+
- [Docker](https://docs.docker.com/get-docker/) v17.03+
- [kubectl](https://kubernetes.io/docs/tasks/tools/) v1.11+
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [make](https://www.gnu.org/software/make/)

## Local Development: Build, Deploy, and Run

### 1. Create the kind cluster

A `kind.yaml` is provided at the root of this directory. It creates a cluster named `computetask` with one control-plane node and one worker node.

```sh
kind create cluster --config kind.yaml
```

Verify the cluster is up:

```sh
kubectl cluster-info --context kind-computetask
kubectl get nodes
```

### 2. Build the operator image

```sh
make docker-build IMG=controller:latest
```

### 3. Load the image into kind

kind clusters cannot pull images from a local Docker daemon by default. Load the image directly:

```sh
kind load docker-image controller:latest --name computetask
```

> **Note:** The `config/manager/manager.yaml` sets `imagePullPolicy: IfNotPresent` so that
> Kubernetes uses the locally loaded image instead of trying to pull `controller:latest` from
> Docker Hub (which would fail, since it is not a public image). Without this, Kubernetes
> defaults to `imagePullPolicy: Always` for `:latest` tags and ignores the local image.

### 4. Install the CRD

Generate and install the `ComputeTask` CRD into the cluster:

```sh
make install
```

Verify it was installed:

```sh
kubectl get crd computetasks.example.com
```

### 5. Deploy the operator

```sh
make deploy IMG=controller:latest
```

This creates the `computetask-system` namespace and deploys the controller manager into it.

Wait for the controller to be ready:

```sh
kubectl -n computetask-system rollout status deployment/computetask-controller-manager
```

Check the controller logs:

```sh
kubectl -n computetask-system logs -l control-plane=controller-manager -f
```

### 6. Run a sample ComputeTask

Apply the sample from `config/samples/`:

```sh
kubectl apply -k config/samples/
```

Watch the `ComputeTask` status update as the Pod progresses:

```sh
kubectl get computetask -w
```

You should see the `PHASE` column transition: _(empty)_ → `Pending` → `Running` → `Succeeded`.

Inspect the backing Pod the controller created:

```sh
kubectl get pod ct-computetask-sample
kubectl logs ct-computetask-sample
```

Inspect the full status of the `ComputeTask`:

```sh
kubectl describe computetask computetask-sample
```

### 7. Clean up

Delete the sample:

```sh
kubectl delete -k config/samples/
```

Undeploy the controller:

```sh
make undeploy
```

Uninstall the CRD:

```sh
make uninstall
```

Delete the kind cluster:

```sh
kind delete cluster --name computetask
```

---

## Running Tests

### Unit tests (envtest)

```sh
make test
```

### End-to-end tests (kind)

The e2e suite builds the image, loads it into a dedicated kind cluster, deploys the operator, and runs behavioural tests against it.

```sh
make test-e2e
```

The kind cluster is created and torn down automatically. The default cluster name is `computetask-test-e2e` (configurable via `KIND_CLUSTER`).

---

## API Reference

### ComputeTaskSpec

| Field | Type | Default | Description |
|---|---|---|---|
| `durationSeconds` | `int32` | `60` | How many seconds the backing Pod sleeps before exiting. Minimum: `1`. |
| `suspend` | `bool` | `false` | When `true`, the controller deletes any existing Pod and holds the task in `Pending`. |

### ComputeTaskStatus

| Field | Type | Description |
|---|---|---|
| `phase` | `string` | Current lifecycle phase: `Pending`, `Running`, `Succeeded`, or `Failed`. |
| `podName` | `string` | Name of the Pod created by the controller (`ct-<name>`). |
| `startTime` | `time` | When the backing Pod started running. |
| `completionTime` | `time` | When the backing Pod finished (succeeded or failed). |
| `conditions` | `[]Condition` | Standard Kubernetes conditions. |

---

**NOTE:** Run `make help` for the full list of available make targets.

More information can be found via the [Kubebuilder Documentation](https://book.kubebuilder.io/introduction.html).
