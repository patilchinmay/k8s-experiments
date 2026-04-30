# Design: `06-multikueue-jobset-priority`

**Date:** 2026-04-30  
**Status:** Approved

---

## Summary

A new Kueue experiment (`06-multikueue-jobset-priority`) that combines two pending concepts from the project roadmap:

1. **Advanced MultiKueue** — 1 manager cluster + 2 worker clusters. Both workers registered in the `MultiKueueConfig`. JobSet workloads are dispatched to workers.
2. **WorkloadPriorityClass** — Kueue-native priority object, decoupled from Kubernetes `PriorityClass`. Demonstrates admission ordering and the k8s priority decoupling.

The workload type is `JobSet` (instead of `batch/v1 Job`), enabling Kueue's atomic admission of a multi-job workload (leader + worker child jobs).

---

## Scope

This experiment **covers:**
- JobSet integration with Kueue (`jobset.x-k8s.io/jobset` integration framework)
- Multi-worker MultiKueue federation (2 worker clusters in `MultiKueueConfig`)
- `WorkloadPriorityClass` for admission ordering
- Decoupling `WorkloadPriorityClass` from Kubernetes `PriorityClass`

This experiment **does not cover:**
- Worker cluster failure / re-dispatch
- Priority-based preemption (covered in experiments 03–04)
- Cohort + MultiKueue combination
- Load balancing across workers (MultiKueue uses first-available selection; we verify config only)

---

## Architecture

### Clusters

| Cluster | Context | Role |
|---|---|---|
| `kueue-manager` | `kind-kueue-manager` | Holds queues, MultiKueue objects, WorkloadPriorityClasses. Users submit JobSets here. |
| `kueue-worker-1` | `kind-kueue-worker-1` | Receives and executes mirrored JobSets. |
| `kueue-worker-2` | `kind-kueue-worker-2` | Second worker cluster. Registered in MultiKueueConfig. |

Each cluster: 1 control-plane + 2 worker nodes.

Kueue + JobSet CRDs installed on all three clusters. MultiKueue feature gate enabled on manager (harmless on workers).

### Docker network

All Kind clusters share the single `kind` Docker bridge network. Manager's Kueue controller reaches workers via their control-plane container IPs (rewritten in kubeconfig Secrets, same technique as experiment 05).

---

## Kueue Objects

### Manager cluster

| Object | Name | Notes |
|---|---|---|
| `ResourceFlavor` | `default-flavor` | No nodeLabels — all nodes equivalent |
| `WorkloadPriorityClass` | `high-priority` | `value: 100` |
| `WorkloadPriorityClass` | `low-priority` | `value: 10` |
| `MultiKueueCluster` | `kueue-worker-1` | References Secret `kueue-worker-1-kubeconfig` in `kueue-system` |
| `MultiKueueCluster` | `kueue-worker-2` | References Secret `kueue-worker-2-kubeconfig` in `kueue-system` |
| `MultiKueueConfig` | `multikueue-config` | `spec.clusters: [kueue-worker-1, kueue-worker-2]` |
| `AdmissionCheck` | `multikueue-check` | `controllerName: kueue.x-k8s.io/multikueue`, parameters → `multikueue-config` |
| `ClusterQueue` | `team-a-cq` | `queueingStrategy: StrictFIFO`, has `admissionChecks: [multikueue-check]` |
| `LocalQueue` | `team-a-queue` | Namespace: `team-a` |

**Why StrictFIFO?** Priority ordering is only observable with `StrictFIFO`. With `BestEffortFIFO`, Kueue may admit lower-priority workloads if they fit, regardless of queue position.

### Each worker cluster (same config, applied independently)

| Object | Name | Notes |
|---|---|---|
| `ResourceFlavor` | `default-flavor` | Same name as manager — required for mirror routing |
| `ClusterQueue` | `team-a-cq` | Same name, **no** `admissionChecks` |
| `LocalQueue` | `team-a-queue` | Namespace: `team-a` |

---

## JobSet Shape

```
JobSet
├── Job: leader      (parallelism: 1, completions: 1)
│   └── Pod: sleeps 60s, prints hostname
└── Job: worker      (parallelism: 2, completions: 2)
    └── Pods ×2: sleep 60s, print hostname
```

Kueue creates one `Workload` for the entire JobSet. All child jobs are admitted or queued atomically. The JobSet carries:

```yaml
labels:
  kueue.x-k8s.io/queue-name: team-a-queue
  kueue.x-k8s.io/priority-class: high-priority   # or low-priority
```

---

## Experiment Steps (linear narrative)

### Step 0 — Setup
`bash setup.sh`:
1. Creates `kueue-manager`, `kueue-worker-1`, `kueue-worker-2` Kind clusters.
2. Installs cert-manager + Kueue + JobSet CRDs on all three.
3. Extracts worker kubeconfigs, rewrites API server addresses to Docker bridge IPs, stores as Secrets on manager in `kueue-system` namespace.

### Step 1 — Apply MultiKueue federation objects (manager only)
File: `02-multikueue-objects.yaml`
- `MultiKueueCluster` ×2, `MultiKueueConfig`, `AdmissionCheck`

### Step 2 — Apply ClusterQueues
- `03-manager-clusterqueue.yaml` → manager (with admissionChecks)
- `04-worker-clusterqueue.yaml` → worker-1 and worker-2 (no admissionChecks)

### Step 3 — Apply namespace, LocalQueue, WorkloadPriorityClasses
- `05-namespace-localqueue-priority.yaml` → manager (includes both WorkloadPriorityClass objects)
- Same file (namespace + LocalQueue only) → both workers

### Step 4 — Verify setup
Confirm `MultiKueueCluster` ×2 are `Active: True`, `AdmissionCheck` is `Active: True`.

### Step 5 — Submit a JobSet and observe multi-cluster dispatch
Submit `06-jobset-high-priority.yaml`. Observe:
- Single `Workload` on manager (not two separate workloads)
- JobSet mirrored to a worker cluster
- `leader` + `worker` child jobs appear on the worker
- Manager's JobSet remains `suspend: true`
- Status (`Running` → `Succeeded`) mirrored back

### Step 6 — Priority-based admission ordering
1. Submit several `07-jobset-low-priority.yaml` instances to fill the ClusterQueue quota.
2. While queue is full (workloads pending), submit `06-jobset-high-priority.yaml`.
3. With `StrictFIFO`, Kueue re-orders the queue so the high-priority workload is next to be admitted when quota becomes available.
4. Observe `kubectl get workloads -n team-a` — once a running workload finishes and quota is freed, the high-priority workload is admitted before remaining low-priority ones.

### Step 7 — WorkloadPriorityClass decoupled from k8s PriorityClass
1. Submit two JobSets with **identical** or no Kubernetes `PriorityClass`
2. One carries `kueue.x-k8s.io/priority-class: high-priority`, the other `low-priority`
3. Observe that Kueue respects `WorkloadPriorityClass` order for admission
4. Check pod `priority` field — both pods have the same scheduling priority (or default)
5. Key observation: Kueue admission priority ≠ pod scheduling priority

### Step 8 — Cleanup
`bash teardown.sh`

---

## File Structure

```
kueue/06-multikueue-jobset-priority/
├── kind-manager.yaml                     # Kind config: kueue-manager (1 cp + 2 workers)
├── kind-worker-1.yaml                    # Kind config: kueue-worker-1 (1 cp + 2 workers)
├── kind-worker-2.yaml                    # Kind config: kueue-worker-2 (1 cp + 2 workers)
├── values.yaml                           # Helm values (cp from 05-multikueue/values.yaml)
├── setup.sh                              # Creates 3 clusters, installs deps, creates kubeconfig Secrets
├── teardown.sh                           # Cleans up experiment resources
├── 02-multikueue-objects.yaml            # MultiKueueCluster×2, MultiKueueConfig, AdmissionCheck
├── 03-manager-clusterqueue.yaml          # ResourceFlavor + manager ClusterQueue (with admissionChecks)
├── 04-worker-clusterqueue.yaml           # ResourceFlavor + worker ClusterQueue (no admissionChecks)
├── 05-namespace-localqueue-priority.yaml # Namespace, LocalQueue, WorkloadPriorityClass×2
├── 06-jobset-high-priority.yaml          # JobSet with kueue.x-k8s.io/priority-class: high-priority
├── 07-jobset-low-priority.yaml           # JobSet with kueue.x-k8s.io/priority-class: low-priority
└── README.md
```

**Note on `values.yaml`:** The file is copied from `05-multikueue/values.yaml` using `cp`. It already contains:
- `featureGates: MultiKueue: enabled: true`
- `integrations.frameworks: ["batch/job", "jobset.x-k8s.io/jobset", ...]`

No content changes are needed to the values file — it works as-is.

---

## Concepts Covered

| Concept | Notes |
|---|---|
| `JobSet` integration | Kueue treats the entire JobSet as one admission unit |
| `jobset.x-k8s.io/jobset` integration framework | Must be listed in `integrations.frameworks` |
| Atomic admission of multi-job workloads | Single `Workload` created for the entire JobSet |
| `WorkloadPriorityClass` | Kueue-native priority object, separate from k8s `PriorityClass` |
| `WorkloadPriorityClass` vs k8s `PriorityClass` decoupling | Admission order ≠ pod scheduling priority |
| `StrictFIFO` queueing strategy | Required to make priority ordering observable |
| Multiple worker clusters in `MultiKueueConfig` | Two workers registered; first-available dispatch |
| Two kubeconfig Secrets on manager | One per worker cluster, both in `kueue-system` |

---

## README Updates Required

- `kueue/README.md` — add row for experiment 06 in the Experiments table; add new concepts to the Concepts Covered table; mark "Advanced MultiKueue" and "WorkloadPriorityClass" sections as covered (or remove/update them in "Pending Concepts").

---

## Key Constraints and Gotchas

1. **JobSet label, not annotation** — `kueue.x-k8s.io/queue-name` and `kueue.x-k8s.io/priority-class` must be **labels**, not annotations. Kueue reads them via `GetLabels()`.
2. **Worker ClusterQueues must NOT have `admissionChecks`** — would cause infinite mirror loop.
3. **Names must match across clusters** — `ClusterQueue` name, `LocalQueue` name, `ResourceFlavor` name, and namespace must be identical on manager and workers.
4. **kubeconfig Secrets** — must use Docker bridge IP (not `127.0.0.1`), must be in `kueue-system`, data key must be exactly `kubeconfig`.
5. **JobSet CRDs on workers** — MultiKueue mirrors the `JobSet` object to the worker; the worker must have `JobSet` CRDs installed or the mirror will fail.
6. **`StrictFIFO` is required for priority demo** — `BestEffortFIFO` may admit lower-priority workloads out of order.
7. **WorkloadPriorityClass is cluster-scoped** — only needs to exist on the manager cluster (it's evaluated at admission time, not mirrored to workers).
