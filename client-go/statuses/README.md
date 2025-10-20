# Kubernetes Job Status Monitor

A Go application that monitors and displays the status of Kubernetes JobSets and PyTorchJobs in real-time, providing detailed information about jobs, pods, and containers.

## Overview

This tool continuously monitors JobSet and PyTorchJob resources in a Kubernetes cluster, aggregating their status information and displaying it in JSON format every 30 seconds. It provides detailed insights into:

- Job and Pod statuses with aggregated counts
- Container states (init, regular, and sidecar containers)
- Pod scheduling issues (unschedulable conditions)
- Container issues (ImagePullError, CrashLoopBackOff, OOMKilled, etc.)

## Features

- **Dual Resource Monitoring**: Monitors both JobSet and PyTorchJob resources simultaneously
- **Aggregated Status Counts**: Status displayed as JSON objects with counts (e.g., `{"Running": 2, "Pending": 1}`)
- **Real-time Updates**: Prints status every 30 seconds
- **Detailed Pod Information**: Tracks all container types and their states
- **Error Detection**: Identifies scheduling issues and container problems
- **Code Reuse**: Shared utility functions for both resource types

## Prerequisites

- Go 1.24.3 or later
- Access to a Kubernetes cluster
- `kubectl` configured with cluster access
- JobSet operator installed (for JobSet monitoring)
- Kubeflow Training Operator installed (for PyTorchJob monitoring)

## Installation

### Install JobSet Operator

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/jobset/releases/download/v0.10.1/manifests.yaml
```

### Install Kubeflow Training Operator

```bash
kubectl apply -k "github.com/kubeflow/training-operator.git/manifests/overlays/standalone?ref=v1.8.1"
```

### Build the Application

```bash
cd client-go/statuses
go build
```

## Usage

### Deploy Sample Resources

Deploy the sample JobSet:

```bash
kubectl apply -f jobset.yaml
```

Deploy the sample PyTorchJob:

```bash
kubectl apply -f pytorch-job.yaml
```

### Run the Monitor

```bash
./statuses
```

Or specify a custom kubeconfig:

```bash
./statuses -kubeconfig=/path/to/kubeconfig
```

## Sample Output

```json
{
  "jobset": {
    "name": "bash-counter-jobset",
    "status": {
      "Complete": 1,
      "Running": 1
    },
    "restarts": 0,
    "lastCondition": {
      "type": "Complete",
      "status": "True"
    },
    "jobs": [...]
  }
}

{
  "pytorchJob": {
    "name": "pytorch-simple",
    "status": {
      "Running": 2
    },
    "lastCondition": {
      "type": "Running",
      "status": "True"
    },
    "pods": [...]
  }
}
```

## Architecture

### Resource Hierarchy

**JobSet Flow:**

```
JobSet CR → Jobs (Batch) → Pods → Containers
```

**PyTorchJob Flow:**

```
PyTorchJob CR → Pods → Containers
```

### Shared Utility Functions

The application uses shared functions for both resource types:

| Function | Purpose |
|----------|---------|
| `getPodInfo()` | Extract pod and container information |
| `getContainerIssues()` | Check all containers for issues |
| `getContainerIssueReason()` | Check individual container state |
| `isPodUnschedulable()` | Check if a pod is unschedulable |
| `hasUnschedulablePods()` | Check if any pod in a list is unschedulable |

See [FLOWCHART.md](./FLOWCHART.md) for detailed function reuse visualization.

## Status Detection

The application detects various states:

### Pod States

- **Running**: Pod is actively running
- **Pending**: Pod is waiting to be scheduled
- **Succeeded**: Pod completed successfully
- **Failed**: Pod failed to complete
- **Unschedulable**: Pod cannot be scheduled (e.g., insufficient resources, node selector mismatch)

### Container Issues

- **ErrImagePull** / **ImagePullBackOff**: Cannot pull container image
- **CrashLoopBackOff**: Container keeps crashing
- **OOMKilled**: Container killed due to out-of-memory
- **Error**: Container exited with error
- And other container-specific errors

## Configuration

The application monitors these resources by default:

- **JobSet**: `bash-counter-jobset` in `default` namespace
- **PyTorchJob**: `pytorch-simple` in `default` namespace

To monitor different resources, modify the `main()` function in `main.go`

## References

- [JobSet Documentation](https://github.com/kubernetes-sigs/jobset)
- [Kubeflow Training Operator](https://github.com/kubeflow/training-operator)
- [Kubernetes client-go](https://github.com/kubernetes/client-go)
