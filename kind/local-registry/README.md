# KinD cluster with local registry

- [KinD cluster with local registry](#kind-cluster-with-local-registry)
  - [Description](#description)
  - [Customizations](#customizations)
  - [Create Cluster](#create-cluster)
  - [Verification](#verification)
  - [Clean up](#clean-up)
  - [References](#references)

## Description

Create a `Kind` cluster with a local registry to speed up local development flow.

Whilst a remote registry is the easiest way to get started when developing functions, a local registry can be faster for development and testing.

It helps avoid the process of manually loading the local images into `Kind` cluster with the `kind load` command.

Instead, we can tag the locally built images with the local-registry and push them. Then, they will be readily available to be used inside the `Kind` cluster without any additional image-loading step.

## Customizations

The script `kind-with-registry.sh` is copied from https://kind.sigs.k8s.io/docs/user/local-registry/. It is subject to change with the newer releases of `Kind`.

We have modified the step 2 of the script to read the cluster configuration from the file `kind.yaml`.

The rest of the script remains unchanged.

## Create Cluster

```bash
kind version
> kind v0.23.0 go1.22.3 darwin/arm64

./kind-with-registry.sh
```

The script should start a cluster with the local-registry.

```bash
docker ps

>
CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS          PORTS                                                 NAMES
843d78be3075   kindest/node:v1.30.0   "/usr/local/bin/entr…"   39 seconds ago   Up 38 seconds   0.0.0.0:30000->30000/tcp, 127.0.0.1:51090->6443/tcp   kind-control-plane
43bafd2a9f39   registry:2             "/entrypoint.sh /etc…"   40 seconds ago   Up 39 seconds   127.0.0.1:5001->5000/tcp                              kind-registry
```

## Verification

Pull a remote image for testing.

```bash
docker pull curlimages/curl:latest
```

Tag the image with local-registry. The name and the port of the registry are defined in the script.

```bash
docker tag docker.io/curlimages/curl:latest localhost:5001/local-curl:0.1
```

Push the image to the local-registry.

```bash
docker push localhost:5001/local-curl:0.1

>
The push refers to repository [localhost:5001/local-curl]
5f70bf18a086: Pushed
480e3038b821: Pushed
9110f7b5208f: Pushed
0.1: digest: sha256:a113f76803223bb6c6a6e362397cada6fd5f29a1f6df138236d546367805e8ff size: 945
```

Run a test container inside the `Kind` cluster with the image from the local-registry.

```bash
kubectl run -i --tty --rm local-registry-test --image=localhost:5001/local-curl:0.1 --restart=Never -- sh

>
If you don't see a command prompt, try pressing enter.
~ $
```

In a separate terminal, run:

```bash
kubectl get pod local-registry-test -o=jsonpath='{.spec.containers[0].image}'

> localhost:5001/local-curl:0.1%
```

Thus, we can see that the local-registry's image has been successfully used inside the `Kind` cluster.

## Clean up

Delete the cluster as well as the local-registry containers.

```bash
kind delete cluster && docker stop kind-registry && docker rm kind-registry

>
Deleting cluster "kind" ...
Deleted nodes: ["kind-control-plane"]
kind-registry
kind-registry
```

## References

1. https://kind.sigs.k8s.io/docs/user/local-registry/