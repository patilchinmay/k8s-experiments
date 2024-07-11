# Batch Job Controller

Create a batch job controller based on controller-runtime that is capable of detecting the events related to the Batch Job.

## 1. Create Cluster

```bash
kind create cluster --config kind.yaml
```

## 2. Run the controller inside the cluster

```bash
go run main.go
```

This will start streaming the logs of the controller in the terminal.

## 3. Submit Job

In a new terminal window, create the sample batch job.

Ensure that the kubectl context is set to kind cluster.

```bash
kubectl apply -f logjob.yaml
```

This job will simply print the current time to the terminal every second for 1 minute.

## 4. Verify

Verify that the controller's reconcile function was called by viewing the streaming logs in the terminal from step 2.

## 5. Cleanup

Delete the cluster.

```bash
kind delete cluster
```