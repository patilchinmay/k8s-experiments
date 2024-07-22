# Typed Controller / Custom Reconcile Requests

**Table of Contents**:
- [Typed Controller / Custom Reconcile Requests](#typed-controller--custom-reconcile-requests)
  - [Description](#description)
  - [What are we building?](#what-are-we-building)
  - [Prerequisite](#prerequisite)
  - [Create Cluster](#create-cluster)
  - [Run the manager (and the controller)](#run-the-manager-and-the-controller)
  - [Explanation](#explanation)
  - [Cleanup](#cleanup)

## Description

Demonstrate the capability of a `controller-runtime` library's typed controller to handler and trigger reconciliation based on custom reconcile requests instead of the standard [reconcile.Request](https://github.com/kubernetes-sigs/controller-runtime/blob/1ed345090869edc4bd94fe220386cb7fa5df745f/pkg/reconcile/reconcile.go#L50).


## What are we building?

Create a typed controller that will use a custom defined input for reconciliation input.

## Prerequisite

Since Typed functions and type definitions are not available in the releases of controller-runtime, we need to pull the main branch in so that we can access the required function and type definitions.

```bash
go mod tidy
go get sigs.k8s.io/controller-runtime@main
```

## Create Cluster

```bash
kind version
> kind v0.22.0 go1.21.7 darwin/arm64

kind create cluster --config kind.yaml
```

## Run the manager (and the controller)

```bash
❯ go run .

2024-07-22T23:24:07+09:00	INFO	entrypoint	setting up manager
2024-07-22T23:24:07+09:00	INFO	entrypoint	starting manager
2024-07-22T23:24:07+09:00	INFO	controller-runtime.metrics	Starting metrics server
2024-07-22T23:24:07+09:00	INFO	Starting EventSource	{"controller": "typed_controller", "source": "kind source: *v1.Job"}
2024-07-22T23:24:07+09:00	INFO	Starting Controller	{"controller": "typed_controller"}
2024-07-22T23:24:07+09:00	INFO	Starting workers	{"controller": "typed_controller", "worker count": 1}
2024-07-22T23:24:07+09:00	INFO	controller-runtime.metrics	Serving metrics server	{"bindAddress": ":8080", "secure": false}

2024-07-22T23:24:14+09:00	INFO	handler	Create CustomEventHandler	{"evt-name": "print-time", "evt-ns": "default", "evt-userID": "5f8e036b-c183-4120-8da3-9f1f7860b271"}
2024-07-22T23:24:14+09:00	INFO	reconciler	{"controller": "typed_controller", "reconcileID": "051dfb3c-7d84-4824-ad37-7388af32f1a1", "incoming req": {}, "userID": "5f8e036b-c183-4120-8da3-9f1f7860b271"}

2024-07-22T23:24:14+09:00	INFO	handler	Update CustomEventHandler	{"old-evt-name": "print-time", "old-evt-ns": "default", "new-evt-name": "print-time", "new-evt-ns": "default", "evt-userID": "f92ec9ab-2def-4cea-984c-43555f452487"}
2024-07-22T23:24:14+09:00	INFO	reconciler	{"controller": "typed_controller", "reconcileID": "e5a9cffe-af73-4c7d-ac44-a4ead5b38c3e", "incoming req": {}, "userID": "f92ec9ab-2def-4cea-984c-43555f452487"}

2024-07-22T23:24:18+09:00	INFO	handler	Update CustomEventHandler	{"old-evt-name": "print-time", "old-evt-ns": "default", "new-evt-name": "print-time", "new-evt-ns": "default", "evt-userID": "db2bd750-2c85-4dc8-b516-543426fffd2d"}
2024-07-22T23:24:18+09:00	INFO	reconciler	{"controller": "typed_controller", "reconcileID": "b990240b-c9b1-442a-a786-4f7cd37713b2", "incoming req": {}, "userID": "db2bd750-2c85-4dc8-b516-543426fffd2d"}

2024-07-22T23:25:18+09:00	INFO	handler	Update CustomEventHandler	{"old-evt-name": "print-time", "old-evt-ns": "default", "new-evt-name": "print-time", "new-evt-ns": "default", "evt-userID": "d6540945-219d-424a-b6fa-bd77d3117c32"}
2024-07-22T23:25:18+09:00	INFO	reconciler	{"controller": "typed_controller", "reconcileID": "21577836-8ef7-490e-92e4-5bf5f3faf690", "incoming req": {}, "userID": "d6540945-219d-424a-b6fa-bd77d3117c32"}

2024-07-22T23:25:19+09:00	INFO	handler	Update CustomEventHandler	{"old-evt-name": "print-time", "old-evt-ns": "default", "new-evt-name": "print-time", "new-evt-ns": "default", "evt-userID": "8f97cebd-a43a-44a9-9dcf-11e3d51e2e0a"}
2024-07-22T23:25:19+09:00	INFO	reconciler	{"controller": "typed_controller", "reconcileID": "2668f2ae-00c2-4fed-b7b3-d9231c885ec8", "incoming req": {}, "userID": "8f97cebd-a43a-44a9-9dcf-11e3d51e2e0a"}

2024-07-22T23:25:19+09:00	INFO	handler	Update CustomEventHandler	{"old-evt-name": "print-time", "old-evt-ns": "default", "new-evt-name": "print-time", "new-evt-ns": "default", "evt-userID": "a02c1a0f-fc13-4ebf-89ae-3f2941a30798"}
2024-07-22T23:25:19+09:00	INFO	reconciler	{"controller": "typed_controller", "reconcileID": "cd724d31-fafe-46d8-9239-67320e77e0b9", "incoming req": {}, "userID": "a02c1a0f-fc13-4ebf-89ae-3f2941a30798"}

2024-07-22T23:28:14+09:00	INFO	handler	Delete CustomEventHandler	{"evt-name": "print-time", "evt-ns": "default", "evt-userID": "5cd37eea-5b81-4280-b2b2-65ab541c19ae"}
2024-07-22T23:28:14+09:00	INFO	reconciler	{"controller": "typed_controller", "reconcileID": "5e01ccd8-7807-47b9-9aa2-e4b08c6d349c", "incoming req": {}, "userID": "5cd37eea-5b81-4280-b2b2-65ab541c19ae"}

^C2024-07-22T23:28:19+09:00	INFO	Stopping and waiting for non leader election runnables
2024-07-22T23:28:19+09:00	INFO	Stopping and waiting for leader election runnables
2024-07-22T23:28:19+09:00	INFO	Shutdown signal received, waiting for all workers to finish	{"controller": "typed_controller"}
2024-07-22T23:28:19+09:00	INFO	All workers finished	{"controller": "typed_controller"}
2024-07-22T23:28:19+09:00	INFO	Stopping and waiting for caches
2024-07-22T23:28:19+09:00	INFO	Stopping and waiting for webhooks
2024-07-22T23:28:19+09:00	INFO	Stopping and waiting for HTTP servers
2024-07-22T23:28:19+09:00	INFO	controller-runtime.metrics	Shutting down metrics server with timeout of 1 minute
2024-07-22T23:28:19+09:00	INFO	Wait completed, proceeding to shutdown the manager
```

## Explanation

- `request.go` defines `CustomReconcileRequest`, it acts as a custom input for reconcile requests.
- `handler.go` defines te `CustomEventHandler` of type `handler.TypedEventHandler[*batchv1.Job, CustomReconcileRequest]`
  - It means that it will receive the events related to `batchv1.Job` (to be set up as watch in main) and it will create enqueue request for reconciling of the type `CustomReconcileRequest`.
  - Currently, it only enqueues the `CustomReconcileRequest{userID}` with random uuids (which will be printed in reconciler) as a demo purpose. But this structure can be used for determining and enqueuing the request with a valid use case.
- `reconciler.go` implements a no-op reconciler.
  - It uses `CustomReconcileRequest` as an input to the `Reconcile()`.
  - It is no-op. Simply prints the `userID` contained in the `CustomReconcileRequest` input parameter that is initialized by `CustomEventHandler`.
  - The flow of requests can be traced in the logs using the printed `userID`.
- `main.go` creates the manager, uses a builder to create a controller (that is registered with manager), set the watch on it, register the reconciler and finally starts the manager.
  - It uses builder.TypedControllerManagedBy to create a typed builder.
  - `TypedController` only allows `WatchesRawSource`, not `For()` or `Owns()` at least till the version we are using.

## Cleanup

Terminate the program by pressing `Ctrl+C`.

Delete the cluster.

```bash
kind delete cluster
```