# Jobset

- [Jobset](#jobset)
  - [Description](#description)
  - [Installation](#installation)
  - [Running a Jobset](#running-a-jobset)
  - [References](#references)

## Description

JobSet is a Kubernetes API extension (Custom Resource Definition) that enables you to run a group of Jobs as a single unit. It's particularly designed for distributed workloads where multiple Jobs need to work together, communicate with each other, and be managed collectively.

<https://kubernetes.io/blog/2025/03/23/introducing-jobset/>

**Key Features**:

- Multi-Job Coordination: Manages multiple Jobs that need to run together
- Inter-Job Communication: Enables Jobs to discover and communicate with each other
- All-or-Nothing Semantics: The entire JobSet succeeds only when all Jobs complete successfully
- Automatic Cleanup: Manages lifecycle of all related Jobs together
- Failure Handling: If one Job fails, the entire JobSet can be restarted

## Installation

<https://jobset.sigs.k8s.io/docs/installation/>

```bash
VERSION=v0.10.1
kubectl apply --server-side -f https://github.com/kubernetes-sigs/jobset/releases/download/$VERSION/manifests.yaml
```

Verify the installation:

```bash
kubectl get pods -n jobset-system
```

## Running a Jobset

```bash
# Apply the JobSet
kubectl apply -f jobset.yaml

# Watch the JobSet status
kubectl get jobset bash-counter-jobset -w

# View all pods created by the JobSet
kubectl get pods -l jobset.sigs.k8s.io/jobset-name=bash-counter-jobset

# Check logs from both pods
kubectl logs -l jobset.sigs.k8s.io/jobset-name=bash-counter-jobset --all-containers=true -f

# Check logs from a specific pod
kubectl logs -l jobset.sigs.k8s.io/replicatedjob-name=counter-job-a --tail=20

# Delete the JobSet (this will delete all pods)
kubectl delete jobset bash-counter-jobset
```

## References

- <https://kubernetes.io/blog/2025/03/23/introducing-jobset/>
- <https://github.com/kubernetes-sigs/jobset>
