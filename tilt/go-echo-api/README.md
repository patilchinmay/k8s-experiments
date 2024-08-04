# Go Echo API with TILT

- [Go Echo API with TILT](#go-echo-api-with-tilt)
  - [Description](#description)
  - [Create cluster with local-registry](#create-cluster-with-local-registry)
  - [Build and Deploy (without Tilt)](#build-and-deploy-without-tilt)
  - [Simulate Change](#simulate-change)
  - [Install `Tilt`](#install-tilt)
  - [Tiltfile](#tiltfile)
  - [Build and Deploy with `Tilt`](#build-and-deploy-with-tilt)
  - [Simulate Change (with `Tilt`)](#simulate-change-with-tilt)
  - [How does `Tilt` detect changes?](#how-does-tilt-detect-changes)
  - [Clean up](#clean-up)
  - [References](#references)

## Description

Demonstrate the value of `Tilt` and how it saves the time for local development with kubernetes.

As per https://docs.tilt.dev/:

> `Tilt` automates all the steps from a code change to a new process: watching files, building container images, and bringing your environment up-to-date. Think docker build && kubectl apply or docker-compose up.


## Create cluster with local-registry

```bash
kind version
> kind v0.23.0 go1.22.3 darwin/arm64

./kind-with-registry.sh
```

The script should start a cluster with the local-registry at `localhost:5001`.

```bash
docker ps

>
CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS          PORTS                                                 NAMES
843d78be3075   kindest/node:v1.30.0   "/usr/local/bin/entr…"   39 seconds ago   Up 38 seconds   0.0.0.0:30000->30000/tcp, 127.0.0.1:51090->6443/tcp   kind-control-plane
43bafd2a9f39   registry:2             "/entrypoint.sh /etc…"   40 seconds ago   Up 39 seconds   127.0.0.1:5001->5000/tcp                              kind-registry
```

## Build and Deploy (without Tilt)

1. Build image and tag with local-registry:

```bash
docker build -f deployments/Dockerfile --target run --tag localhost:5001/go-echo-api:latest .
```

The `deployments/Dockerfile` is a standard multi-stage dockerfile. It is written with the intention of building a standard go application image with small memory footprint.

2. Push the image to local-registry:

```bash
docker push localhost:5001/go-echo-api:latest
```

3. Deploy image into `kind` cluster:

```bash
kubectl apply -f deployments/deploy.yaml
```

4. Test that the image is working as expected:

```bash
curl localhost:8000

❯ Hello, World!
```

## Simulate Change

We have `GET /v2` and `GET /v3` routes commented out in `main()` in the `main.go`.

Uncomment them to simulate API changes.

In order to deploy those changes into cluster, we need to re-run steps 1, 2 and 3 from above.

This process takes time and it is quite repetitive.

`Tilt` tries to solve this exact pain point.

## Install `Tilt`

Install tilt with homebrew.
```bash
brew install tilt

# Check version
tilt version
❯ v0.33.18, built 2024-08-01
```

## Tiltfile

We have written a `Tiltfile`.

It contains 5 blocks:

1. `track-rebuild-time`
   1. Defines a simple python script for tracking the time taken to rebuild the image.
   2. It overwrites the `start.go` with current time.
   3. `main.go` reads the time from `start.go` and determines the elapsed time between the two.
   4. This is our customization. It is not needed by Tilt.
2. `compile-on-host`
   1. This enables compiling the binary on the host instead of inside the container.
   2. This speeds up the process.
   3. The binary is outputted in the `./build` directory.
3. `docker_build_with_restart`
   1. Builds the docker image.
   2. Gives it the tag and pushes it to local-registry.
   3. Tracks any changes in the `./build` directory.
   4. Triggers the rebuild when any changes are detected.
   5. Copies the binary from host's `./build` directory inside the container's `/app/`, for live updates.
4. `k8s_yaml`
   1. Load the deployment manifest.
   2. The image name of the container must match the image name in `docker_build_with_restart`
5. `k8s_resource`
   1. Creates the kubernetes deployment and enables port forwarding.

## Build and Deploy with `Tilt`

```bash
tilt up

❯ 
Tilt started on http://localhost:10350/
v0.33.18, built 2024-08-01

(space) to open the browser
(s) to stream logs (--stream=true)
(t) to open legacy terminal mode (--legacy=true)
(ctrl-c) to exit
Opening browser: http://localhost:10350/
```

The above process will build the docker image, push it to the local-registry and create the deployment with the pod that uses the image from the local-registry. 

**NOTE**:
In Tiltfile, we use a different dockerfile `deployments/Dockerfile.tilt-restart`, compared to the non-tilt phase above.

Check kubernetes resources created by `Tilt`:

```bash
kubectl get deployment

❯ 
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
go-echo-api   1/1     1            1           24m

kubectl get pod

❯
NAME                           READY   STATUS    RESTARTS   AGE
go-echo-api-84855dfb46-nhq9p   1/1     Running   0          24m
```

## Simulate Change (with `Tilt`)

We have `GET /v2` and `GET /v3` routes commented out in `main()` in the `main.go`.

Uncomment them to simulate API changes.

`Tilt` will automatically detect these changes and update the running pod to reflect them.

We do not need to perform any action. Thus, saving us time and repetitive actions.

We can see the time taken for this process (which `main.go` prints as part of execution) on Tilt's web page:

```bash
<truncated>

Will copy 1 file(s) to container: [go-echo-api-84855dfb46-nhq9p/go-echo-api]
- '/Users/chinmay/learn/k8s-experiments/tilt/go-echo-api/build/go-echo-api' --> '/app/go-echo-api'
[CMD 1/1] sh -c date > /tmp/.restart-proc
  → Container go-echo-api-84855dfb46-nhq9p/go-echo-api updated!
2024/08/04 07:02:45 Rebuild time: 2s

<truncated>
```

## How does `Tilt` detect changes?

1. Editing `main.go` triggers `track-rebuild-time` and `compile-on-host` from `Tiltfile`.
2. Since `compile-on-host` depends on `track-rebuild-time`, it will wait.
3. `track-rebuild-time` will overwrite `start.go`.
4. This triggers `compile-on-host` again. Since the previous execution is yet pending, they are clubbed.
5. `compile-on-host` outputs the binary inside `./build`.
6. Since `docker_build_with_restart` is watching `./build`, it detects this change, copies the binary inside the running pod and triggers process restart with `entrypoint` for re-execution.

## Clean up

Exit the `tilt up` command's terminal by pressing `ctrl + c`.

Clean up kubernetes resources:

```bash
kubectl delete deployment go-echo-api
```

Delete the `Kind` cluster and `local-registry`:

```bash
kind delete cluster && docker stop kind-registry && docker rm kind-registry
```

## References

- https://docs.tilt.dev/
- https://docs.tilt.dev/example_go
- https://docs.tilt.dev/resource_dependencies
- https://kind.sigs.k8s.io/docs/user/local-registry/
- https://github.com/patilchinmay/k8s-experiments/tree/master/kind/local-registry
