# 1. Runnable

- [1. Runnable](#1-runnable)
  - [1.1. Description](#11-description)
  - [1.2. What is Runnable?](#12-what-is-runnable)
  - [1.3. What are we building?](#13-what-are-we-building)
  - [1.4. Create Cluster](#14-create-cluster)
  - [1.5. Run the manager (and the runnable)](#15-run-the-manager-and-the-runnable)
  - [1.6. Verify](#16-verify)
  - [1.7. Cleanup](#17-cleanup)


## 1.1. Description

Demonstrate the functionality of the controller-runtime's [Runnable](https://github.com/kubernetes-sigs/controller-runtime/blob/a0c9fd9d3f310f48155ce985366b21914675fbea/pkg/manager/manager.go#L290-L298) interface.

## 1.2. What is Runnable?

As per Gemini AI:

In the controller-runtime library, the `Runnable` interface defines a component that can be managed by the `Manager`. Here's when you'd typically use it:

* **Background tasks:** You can use `Runnable` for functionalities outside the core reconciliation loop of a controller. This includes things like:
    * Periodic tasks: Run code at regular intervals, like collecting metrics every minute. 
    * Event listeners:  Implement a component that listens for specific events (outside of Kubernetes objects) and reacts accordingly.

* **Utility components:**  The `Manager` can also manage utility components that aren't controllers, such as:
    * Web servers: Start an HTTP server for your operator to expose functionalities.
    * Leader election (optional): If your component shouldn't run on multiple pods simultaneously, implement `Runnable` to participate in leader election coordinated by the `Manager`.

**Key points to remember:**

* The `Start` method of `Runnable`  blocks until the context is closed or an error occurs. This ensures the component runs for the entire lifecycle of the manager.
* The `Manager` takes care of starting and stopping `Runnables` along with the controllers it manages.

If your functionality fits within the core reconciliation loop of a controller (reacting to changes in Kubernetes objects), then you wouldn't necessarily need `Runnable`. It's more for background tasks or utilities that the `Manager` can manage alongside your controllers.

## 1.3. What are we building?

A simple program that will use a Runnable and print time every second.

This program will be started by the Manager and it will exit with the manager (on CTRL+C interrupt).

## 1.4. Create Cluster

```bash
kind create cluster --config kind.yaml
```

## 1.5. Run the manager (and the runnable)

```bash
go mod tidy
go run .
```

## 1.6. Verify

Verify that the Runnable has started by viewing the logs. Time should be printed every second.

## 1.7. Cleanup

Terminate the program by pressing `Ctrl+C`.

Delete the cluster.

```bash
kind delete cluster
```