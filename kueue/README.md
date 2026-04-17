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
