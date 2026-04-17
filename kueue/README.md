# Kueue Experiments

A collection of hands-on experiments for learning [Kueue](https://kueue.sigs.k8s.io/) — a Kubernetes-native job queuing system.

Each experiment lives in its own self-contained subfolder with its own cluster configuration, setup script, Kueue Helm values, and teardown script. Experiments are independent and can be run in any order.

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
