# Kubernetes Experiments

Learning Kubernetes through experiments.

- [Kubernetes Experiments](#kubernetes-experiments)
  - [Local Kubernetes](#local-kubernetes)
    - [Kind](#kind)
      - [expose-service-to-host](#expose-service-to-host)
      - [local-registry](#local-registry)
    - [Minikube](#minikube)
      - [remote-access](#remote-access)
  - [Programming Kubernetes](#programming-kubernetes)
    - [client-go](#client-go)
      - [create-client](#create-client)
      - [create-resource-from-yaml](#create-resource-from-yaml)
      - [informers](#informers)
      - [dynamic-informer](#dynamic-informer)
    - [controller-runtime](#controller-runtime)
      - [batchjobcontroller](#batchjobcontroller)
      - [batchjobcontrollerv2](#batchjobcontrollerv2)
      - [custom-source-eventhandler](#custom-source-eventhandler)
      - [runnable](#runnable)
      - [typedcontroller-custom-reconcile-request](#typedcontroller-custom-reconcile-request)
    - [Kubernetes Operators](#kubernetes-operators)
      - [Kubebuilder / visitors-operator](#kubebuilder--visitors-operator)
  - [Deploying Kubernetes](#deploying-kubernetes)
    - [Kubespray](#kubespray)
  - [Concepts/Features](#conceptsfeatures)
    - [Affinity](#affinity)
      - [nodeAffinity/podAffinity all-pods-on-one-node](#nodeaffinitypodaffinity-all-pods-on-one-node)
      - [nodeAffinity/podAntiAffinity each-pod-on-separate-node](#nodeaffinitypodantiaffinity-each-pod-on-separate-node)
    - [Autoscalers](#autoscalers)
      - [horizontal-pod-autoscaler](#horizontal-pod-autoscaler)
      - [vertical-pod-autoscaler](#vertical-pod-autoscaler)
    - [Taints and Tolerations](#taints-and-tolerations)
      - [multi-taints](#multi-taints)
      - [taint-no-taint](#taint-no-taint)
  - [Kubernetes Toolings/Ecosystem](#kubernetes-toolingsecosystem)
    - [kustomize](#kustomize)
    - [tilt / go-echo-api](#tilt--go-echo-api)
    - [sealed-secrets](#sealed-secrets)
    - [Policy Management](#policy-management)
      - [kubewebhook](#kubewebhook)
      - [kyverno / check-for-labels](#kyverno--check-for-labels)


## Local Kubernetes

### [Kind](./kind/)

#### [expose-service-to-host](./kind/expose-service-to-host/)

#### [local-registry](./kind/local-registry/)

### [Minikube](./minikube/)

#### [remote-access](./minikube/remote-access/)

## Programming Kubernetes

### [client-go](./client-go/)

#### [create-client](./client-go/create-client/)

#### [create-resource-from-yaml](./client-go/create-resource-from-yaml/)

#### [informers](./client-go/informers/)

#### [dynamic-informer](./client-go/dynamic-informer/)

### [controller-runtime](./controller-runtime/)

#### [batchjobcontroller](./controller-runtime/batchjobcontroller/)

#### [batchjobcontrollerv2](./controller-runtime/batchjobcontrollerv2/)

#### [custom-source-eventhandler](./controller-runtime/custom-source-eventhandler/)

#### [runnable](./controller-runtime/runnable/)

#### [typedcontroller-custom-reconcile-request](./controller-runtime/typedcontroller-custom-reconcile-request/)

### Kubernetes Operators

#### Kubebuilder / [visitors-operator](./kubebuilder/visitors-operator/)

## Deploying Kubernetes

### [Kubespray](./kubespray/)

## Concepts/Features

### [Affinity](./affinity/)

#### nodeAffinity/podAffinity [all-pods-on-one-node](./affinity/all-pods-on-one-node/)

#### nodeAffinity/podAntiAffinity [each-pod-on-separate-node](./affinity/each-pod-on-separate-node/)

### Autoscalers

#### [horizontal-pod-autoscaler](./horizontal-pod-autoscaler/)

#### [vertical-pod-autoscaler](./vertical-pod-autoscaler/)

### [Taints and Tolerations](./taints-toleration/)

#### [multi-taints](./taints-toleration/multi-taints/)

#### [taint-no-taint](./taints-toleration/taint-no-taint/)

## Kubernetes Toolings/Ecosystem

### [kustomize](./kustomize/)

### tilt / [go-echo-api](./tilt/go-echo-api/)

### [sealed-secrets](./sealed-secrets/)

### [Policy Management](./policy/)

#### [kubewebhook](./policy/kubewebhook/)

#### kyverno / [check-for-labels](./policy/kyverno/check-for-labels/)
