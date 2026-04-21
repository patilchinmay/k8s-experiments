# Kubernetes Experiments

Learning Kubernetes through experiments.

<!-- no toc -->
- **Local Kubernetes**
  - `Kind`
    - [expose-service-to-host](./kind/expose-service-to-host/)
    - [local-registry](./kind/local-registry/)
  - `Minikube`
    - [remote-access](./minikube/remote-access/)

- **Programming Kubernetes**
  - `client-go`
    - [create-client](./client-go/create-client/)
    - [create-resource-from-yaml](./client-go/create-resource-from-yaml/)
    - [informers](./client-go/informers/)
    - [dynamic-informer](./client-go/dynamic-informer/)
    - [statuses](./client-go/statuses/) - Monitor JobSet and PyTorchJob status
  - `controller-runtime`
    - [batchjobcontroller](./controller-runtime/batchjobcontroller/)
    - [predicates](./controller-runtime/predicates/)
    - [custom-source-eventhandler](./controller-runtime/custom-source-eventhandler/)
    - [runnable](./controller-runtime/runnable/)
    - [typedcontroller-custom-reconcile-request](./controller-runtime/typedcontroller-custom-reconcile-request/)
  - Kubernetes Operators
    - `Kubebuilder`
      - [visitors-operator](./kubebuilder/visitors-operator/)

- **Deploying Kubernetes**
  - [Kubespray](./kubespray/)

- **Concepts/Features**
  - Affinity
    - [all-pods-on-one-node](./affinity/all-pods-on-one-node/) `nodeAffinity/podAffinity`
    - [each-pod-on-separate-node](./affinity/each-pod-on-separate-node/) `nodeAffinity/podAntiAffinity`
  - Autoscalers
    - [horizontal-pod-autoscaler](./horizontal-pod-autoscaler/)
    - [vertical-pod-autoscaler](./vertical-pod-autoscaler/)
  - JobSet
    - [jobset](./jobset/)
  - Taints and Tolerations
    - [multi-taints](./taints-toleration/multi-taints/)
    - [taint-no-taint](./taints-toleration/taint-no-taint/)
  - Working Together with Taints, Toleration And Affinity
    - [taints-toleration-affinity](./taints-toleration-affinity/)
  - Working Together with Taints, Toleration, Affinity and Preference
    - [taints-toleration-affinity-preference](./taints-toleration-affinity-preference/)

- **Kueue**
  - [01-basic-job](./kueue/01-basic-job/) — Submit jobs through a single ClusterQueue and observe how Kueue intercepts, queues, and admits them against a resource quota.
  - [02-multi-team-queues](./kueue/02-multi-team-queues/) — Run two teams with separate LocalQueues across on-demand and reserved capacity tiers, sharing the same ClusterQueues.
  - [03-borrowing-and-preemption](./kueue/03-borrowing-and-preemption/) — Use a Cohort to let teams borrow each other's idle quota, with lending limits and priority-based preemption to reclaim it.
  - [04-borrowing-with-distinct-flavors](./kueue/04-borrowing-with-distinct-flavors/) — Extend borrowing to two distinct ResourceFlavors so that a borrowing workload physically runs on the lender's nodes.
  - [05-multikueue](./kueue/05-multikueue/) — Federate a manager cluster and a worker cluster with MultiKueue — submit jobs to the manager and watch them dispatched to and executed on the worker, with status mirrored back.

- **Kubernetes Toolings/Ecosystem**
  - [kustomize](./kustomize/)
  - `tilt`
    - [go-echo-api](./tilt/go-echo-api/)
  - [sealed-secrets](./sealed-secrets/)
  - Policy Management
    - [kubewebhook](./policy/kubewebhook/)
    - `kyverno`
      - [check-for-labels](./policy/kyverno/check-for-labels/)
