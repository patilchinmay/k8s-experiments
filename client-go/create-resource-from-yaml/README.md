# Create K8s Resource from a YAML file using client-go

- [Create K8s Resource from a YAML file using client-go](#create-k8s-resource-from-a-yaml-file-using-client-go)
  - [Create cluster](#create-cluster)
  - [Run the program](#run-the-program)
  - [Cleanup](#cleanup)
  - [Reference](#reference)


## Create cluster

```bash
kind create cluster --config kind.yaml
```

## Run the program

The `job.yaml` contains the definition for a Kubernetes Batch Job.

Our program reads the job.yaml and then creates the Job in the cluster.

```bash
go run main.go

# Verify
kubectl get job
```

## Cleanup

`kind delete cluster`

## Reference

- https://iximiuz.com/en/posts/kubernetes-api-go-types-and-common-machinery/
- https://github.com/iximiuz/client-go-examples/tree/main 
- https://stackoverflow.com/questions/47116811/client-go-parse-kubernetes-json-files-to-k8s-structures
- https://gist.github.com/pytimer/0ad436972a073bb37b8b6b8b474520fc