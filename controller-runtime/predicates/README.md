# 1. Batch Job Controller

Same as [batchjobcontroller](../batchjobcontroller/README.md), except it uses predicates (for filtering the incoming events).

- [1. Batch Job Controller](#1-batch-job-controller)
  - [1.1. Description](#11-description)
  - [1.2. Create Cluster](#12-create-cluster)
  - [1.3. Run the controller inside the cluster](#13-run-the-controller-inside-the-cluster)
  - [1.4. Submit Job](#14-submit-job)
  - [1.5. Verify](#15-verify)
  - [1.6. Cleanup](#16-cleanup)


## 1.1. Description

Create a batch job controller based on controller-runtime that is capable of detecting the events related to the Batch Job.

## 1.2. Create Cluster

```bash
kind create cluster --config kind.yaml
```

## 1.3. Run the controller inside the cluster

```bash
go run .
```

This will start streaming the logs of the controller in the terminal.

## 1.4. Submit Job

In a new terminal window, create the sample batch job.

Ensure that the kubectl context is set to kind cluster.

```bash
kubectl apply -f logjob.yaml
```

This job will simply print the current time to the terminal every second for 1 minute.

## 1.5. Verify

Verify that the controller's reconcile function was called by viewing the streaming logs in the terminal from step 2.

## 1.6. Cleanup

Delete the cluster.

```bash
kind delete cluster
```