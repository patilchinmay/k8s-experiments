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

- **Kubernetes Toolings/Ecosystem**
  - [kustomize](./kustomize/)
  - `tilt`
    - [go-echo-api](./tilt/go-echo-api/)
  - [sealed-secrets](./sealed-secrets/)
  - Policy Management
    - [kubewebhook](./policy/kubewebhook/)
    - `kyverno`
      - [check-for-labels](./policy/kyverno/check-for-labels/)
