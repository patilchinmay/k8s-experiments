# Commands

Source: [Kubernetes Operator's Book](https://github.com/kubernetes-operators-book/chapters/tree/master)

Note: The database image has been changed from `mysql:5.7` to `mariadb:10.5` due to arm mac m1 compatibility issue.

--- 

```bash
❯ kubebuilder version

Version: main.version{KubeBuilderVersion:"3.11.1", KubernetesVendor:"1.27.1", GitCommit:"1dc8ed95f7cc55fef3151f749d3d541bec3423c9", BuildDate:"2023-07-03T13:10:56Z", GoOs:"darwin", GoArch:"arm64"}
```

`kubebuilder init --domain example.com --repo github.com/patilchinmay/k8s-experiments/kubebuilder/visitors-operator`

`kubebuilder create api --group apps --version v1 --kind VisitorsApp`

Edit and update `api/v1/visitorsapp_types.go`

Edit and update `internal/controller/visitorsapp_controller.go`

`make manifests`

Edit and update `config/samples/apps_v1_visitorsapp.yaml`

`make install`

`make run`

`kubectl apply -f config/samples/apps_v1_visitorsapp.yaml`

`kubectl get visitorsapps.apps.example.com`

`kubectl get deployment`

`kubectl get service`

`kubectl get pod`

`make docker-build docker-push IMG=patilchinmay/kubebuilder-visitorsapp:latest`

Stop the `make run`

`make deploy IMG=patilchinmay/kubebuilder-visitorsapp:latest`