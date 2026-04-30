# Kueue Experiments

A collection of hands-on experiments for learning [Kueue](https://kueue.sigs.k8s.io/) — a Kubernetes-native job queuing system.

Each experiment lives in its own self-contained subfolder with its own cluster configuration, setup script, Kueue Helm values, and teardown script. Experiments are independent and can be run in any order.

## Experiments

| Experiment | Description |
|---|---|
| [01-basic-job](./01-basic-job/) | Submit jobs through a single ClusterQueue and observe how Kueue intercepts, queues, and admits them against a resource quota. |
| [02-multi-team-queues](./02-multi-team-queues/) | Run two teams with separate LocalQueues across on-demand and reserved capacity tiers, sharing the same ClusterQueues. |
| [03-borrowing-and-preemption](./03-borrowing-and-preemption/) | Use a Cohort to let teams borrow each other's idle quota, with lending limits and priority-based preemption to reclaim it. |
| [04-borrowing-with-distinct-flavors](./04-borrowing-with-distinct-flavors/) | Extend borrowing to two distinct ResourceFlavors so that a borrowing workload physically runs on the lender's nodes. |
| [05-multikueue](./05-multikueue/) | Federate a manager cluster and a worker cluster with MultiKueue — submit jobs to the manager and watch them dispatched to and executed on the worker, with status mirrored back. |
| [06-multikueue-jobset-priority](./06-multikueue-jobset-priority/) | Extend MultiKueue to two worker clusters, submit JobSet workloads (leader + worker child jobs admitted atomically), and demonstrate WorkloadPriorityClass for admission ordering — decoupled from Kubernetes PriorityClass. |

---

## Concepts Covered

The table below tracks which Kueue concepts each completed experiment teaches.

| Concept | Experiments |
|---|---|
| `ResourceFlavor` — node pool abstraction | 01, 02, 03, 04, 05 |
| `ClusterQueue` — quota enforcer | 01, 02, 03, 04, 05 |
| `LocalQueue` — team submission endpoint | 01, 02, 03, 04, 05 |
| `Workload` — admission unit (auto-created) | 01 |
| `nominalQuota` — guaranteed per-team quota | 01, 02 |
| `StrictFIFO` vs `BestEffortFIFO` queueing strategies | 01, 02 |
| Multi-tenant quota sharing (two teams, one ClusterQueue) | 02 |
| Capacity tiers (reserved vs on-demand) | 02 |
| `Cohort` — cooperative quota pool | 03, 04 |
| `borrowingLimit` — cap on how much a queue can borrow | 03, 04 |
| `lendingLimit` — cap on how much a queue will lend | 03, 04 |
| Priority-based preemption (`reclaimWithinCohort`) | 03, 04 |
| `withinClusterQueue` preemption | 03, 04 |
| `borrowWithinCohort` policy | 03, 04 |
| `PriorityClass` for workload priority | 03, 04 |
| Distinct `ResourceFlavors` with `nodeLabels` (physical node targeting) | 04 |
| Flavor-selection order (first-fit fallback) | 04 |
| Cross-flavor borrowing (workload physically moves to lender's nodes) | 04 |
| `MultiKueue` — multi-cluster job federation (manager + worker) | 05 |
| `MultiKueueCluster` — worker cluster connection (kubeconfig Secret) | 05 |
| `MultiKueueConfig` — groups worker clusters for an AdmissionCheck | 05 |
| `AdmissionCheck` — gate that triggers MultiKueue dispatch | 05 |
| Job mirroring — Job + Workload copied to worker cluster | 05 |
| Status mirroring — worker execution status reflected on manager | 05 |
| Manager Job stays `suspend: true` — pods never run on manager | 05 |
| kubeconfig Secret — worker cluster credentials stored on manager | 05 |
| `JobSet` integration (`jobset.x-k8s.io/jobset`) | 06 |
| Atomic admission of multi-job workloads (single `Workload` for entire `JobSet`) | 06 |
| `WorkloadPriorityClass` — Kueue-native admission priority | 06 |
| `WorkloadPriorityClass` vs `PriorityClass` decoupling | 06 |
| `StrictFIFO` queueing strategy (required for priority ordering) | 06 |
| Multiple worker clusters in `MultiKueueConfig` (2 workers) | 06 |
| Two kubeconfig Secrets on manager (one per worker cluster) | 06 |

---

## Pending Concepts & Future Experiments

The following Kueue concepts have not yet been covered. Each maps to a suggested future experiment.

### ✅ `WorkloadPriorityClass` — covered in [06-multikueue-jobset-priority](./06-multikueue-jobset-priority/)

Core `WorkloadPriorityClass` concepts (admission ordering, decoupling from k8s `PriorityClass`) are covered in experiment 06.

**Concepts not yet covered:**
- **`preemption.withinClusterQueue: Any`** — preempt *any* lower-priority workload in the same queue, not just strictly lower-priority ones.
- **Fair sharing (`fairSharing.weight`)** — assign weights to ClusterQueues within a cohort so heavier-weighted queues receive a proportionally larger share of the shared pool.

---

### `JobSet` Integration (multi-job workloads)

**Concepts:**

- **`JobSet`** — a single logical workload composed of multiple `batch/v1 Job` objects (e.g. a trainer + parameter server). Kueue treats the entire JobSet as one admission unit.
- **`jobset` integration** — must be enabled in Kueue Helm values (`integrations.frameworks: ["jobset"]`).

**What to observe:** Submit a JobSet with two child Jobs (leader + worker). Observe that Kueue creates a single `Workload` for the whole set and admits or queues all child Jobs atomically.

---

### `ProvisioningRequestConfig` (Kueue + Cluster Autoscaler)

**Concepts:**

- **`ProvisioningRequestConfig`** — integrates Kueue with the Cluster Autoscaler `ProvisioningRequest` API. Kueue holds a workload in a pending `AdmissionCheck` state until the autoscaler provisions the required nodes, then admits it.
- **`AdmissionCheck`** — a gate object that must reach `Ready` before a workload is admitted. Used by both Provisioning and MultiKueue integrations.

**What to observe:** Submit a workload that requires more nodes than currently exist. Watch Kueue create a `ProvisioningRequest`, the autoscaler scale up, and Kueue admit the workload once nodes are ready.

---

### Topology-Aware Scheduling (TAS)

**Concepts:**

- **`topologyAwareScheduling`** — Kueue packs or spreads workload pods across topology domains (node, rack, zone) to minimise network hops for distributed jobs. Requires `ResourceFlavor.spec.topologyName` pointing to a `Topology` object.
- **`TopologyAssignment`** — the scheduling result, visible in `Workload.status.admission.podSetAssignments[].topologyAssignment`.

**What to observe:** Submit a multi-pod distributed job and observe that Kueue assigns all pods to the same topology domain (e.g. same rack), rather than spreading them across the cluster.

---

### ✅ `MultiKueue` (multi-cluster federation) — covered in [05-multikueue](./05-multikueue/) and [06-multikueue-jobset-priority](./06-multikueue-jobset-priority/)

Core MultiKueue concepts (single manager + single worker) are covered in experiment 05. Two-worker federation is covered in experiment 06.

---

### ✅ Advanced `MultiKueue` (multiple workers) — covered in [06-multikueue-jobset-priority](./06-multikueue-jobset-priority/)

Two-worker MultiKueue federation (`MultiKueueConfig` with two `MultiKueueCluster` entries) is covered in experiment 06.

**Concepts not yet covered:**
- **Worker cluster failure / re-dispatch** — delete a worker cluster and observe how MultiKueue re-dispatches pending workloads to a healthy worker.
- **Cohort + MultiKueue** — combine MultiKueue dispatch with cohort borrowing so the manager can borrow quota from another manager-side ClusterQueue before dispatching.
- **`MultiKueueCluster` status conditions** — observe `Active: False` when the worker is unreachable and `Active: True` when it recovers.
- **Namespace isolation with `spec.namespaceSelector`** — restrict which namespaces can submit to a MultiKueue ClusterQueue.

---

### Additional Concepts (no dedicated experiment yet)

| Concept | Description |
|---|---|
| `ClusterQueue.spec.namespaceSelector` | Restrict which namespaces can submit to a ClusterQueue using label selectors (currently all experiments use `{}` — open to all). |
| `ResourceFlavorFungibility` | Controls flavor substitution when the preferred flavor is unavailable: `Borrow`, `Preempt`, or `BorrowOrPreempt`. |
| `RayJob` / `RayCluster` integration | Kueue manages admission of an entire Ray cluster as one workload. Requires the `ray` integration. |
| `MPIJob` integration | Distributed MPI workloads (Horovod, etc.) managed as a single Kueue workload. |
| `PyTorchJob` / `TFJob` (Training Operator) | Kubeflow Training Operator jobs admitted and queued by Kueue. |
| Kueue Prometheus metrics | `kueue_pending_workloads`, `kueue_admitted_workloads_total`, `kueue_quota_reserved_*`, etc. |
| `kubectl-kueue` plugin | CLI plugin for richer Kueue object inspection beyond raw `kubectl`. |
| Workload condition deep-dive | `QuotaReserved`, `Admitted`, `Evicted`, `Finished` conditions and their `Reason` / `Message` fields. |

---

## Running an Experiment

Each experiment is fully self-contained. Navigate into the experiment subfolder and run the scripts from there:

```bash
# 1. Enter the experiment directory
cd kueue/<NN-experiment-name>

# 2. Start the cluster and install Kueue
bash setup.sh

# 3. Follow the experiment README
# e.g.:
cd kueue/01-basic-job
bash setup.sh
# then follow README.md

# 4. Clean up when done
bash teardown.sh

# 5. Delete the cluster
kind delete cluster --name kueue-cluster
```

---

## References

- [Kueue Official Docs](https://kueue.sigs.k8s.io/docs/)
- [Kueue Helm Chart](https://github.com/kubernetes-sigs/kueue/blob/main/charts/kueue/README.md)
- [Kueue GitHub](https://github.com/kubernetes-sigs/kueue)
