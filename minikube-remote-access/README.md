# Expose Minikube with OIDC for Remote Access

- [Expose Minikube with OIDC for Remote Access](#expose-minikube-with-oidc-for-remote-access)
  - [Setup](#setup)
    - [Prerequisites](#prerequisites)
  - [Start Minikube](#start-minikube)
  - [Expose Minikube with NGINX](#expose-minikube-with-nginx)
  - [OIDC Role Setup (Optional)](#oidc-role-setup-optional)
  - [Dealing with Certificates](#dealing-with-certificates)
  - [Access Minikube Remotely](#access-minikube-remotely)
  - [Reference](#reference)


## Setup

We need 2 hosts. We will install and expose minikube on first (linux host) and we will test the access from the second.

### Prerequisites

Host 1 (minikube):

- Docker
- Kubectl
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)

Host 2:

- Kubectl
- [Kubelogin](https://github.com/int128/kubelogin)

## Start Minikube

```bash
minikube start --driver=docker --gpus=all \
--apiserver-names=minikube,HOSTNAME \
--apiserver-ips=IP \
--extra-config=apiserver.authorization-mode=Node,RBAC \
--extra-config=apiserver.oidc-issuer-url=OIDC_ISSUER_URL \
--extra-config=apiserver.oidc-username-claim=email \
--extra-config=apiserver.oidc-client-id=OIDC_CLIENT_ID
```

Replace `HOSTNAME` and `IP` with the hostname and IP of the host where minikube is installed.

Use appropriate values for `OIDC_ISSUER_URL`, `OIDC_CLIENT_ID`. `OIDC_ISSUER_URL` has to be https with a valid certificate.

More config options for OIDC: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#configuring-the-api-server

More config options for minikube start command: https://minikube.sigs.k8s.io/docs/commands/start/

This command will start the minikube cluster as a docker container. It can be verified using `docker ps`

The name of the container will be `minikube`. It will exist in a network named `minikube`. The k8s api server will be exposed on the port `8443` of the container.

```bash
docker ps
docker ps --format '{{ .ID }} {{ .Names }} {{ json .Networks }}'
```
This process will also configure the kubeconfig on this host.

```bash
cat ~/.kube/config
# OR
kubectl config view
```
Test that the minikube is working.

```bash
> kubectl get pod
No resources found in default namespace.
```

## Expose Minikube with NGINX

Minikube is currently running in a container named `minikube` with api server exposed on the port `8443` of the container.

This port is also exposed on the random port on `127.0.0.1` as seen in the output of the `docker ps`.

To be able to access the minikube cluster (i.e. the api server) from outside of this machine, we need to expose the api server on `0.0.0.0`

For this purpose we will use `NGINX` running as a docker container. It will act as a reverse proxy that listens on `0.0.0.0:52000` and forwards the incoming connections to `minikube:8443`

The NGINX will be deployed in an already existing network `minikube` that is created by minikube when it runs. This allows the nginx to communicate with the `minikube` container.

```bash
# on the host running minikube
docker compose -f nginx.yaml up -d
```

At this stage, we should have at least 2 containers running; one for minikube and other for nginx.

## OIDC Role Setup (Optional)

If we want to enable oidc for authentication, create the appropriate roles and role-binding.

Replace `EMAIL` in `role.yaml` with your email that can be authenticated by `OIDC_ISSUER` connected with minikube.

```bash
# on the host running minikube
kubectl apply -f role.yaml
```

## Dealing with Certificates

At this point, `minikube` is running on our first host. 

`minikube` creates a self signed root CA key and certificate (public key) during its creation process. Then it creates the keys and certificates used for HTTPS communication. These keys are signed by the root CA key/certificate.

Thus, if we want to securely communicate with the minikube over HTTPS, we need minikube's root CA certificate that can verify/certify the HTTPS communication with minikube. This root CA certificate is stored at `~/.minikube/ca.crt` on minikube's host machine.

Run the following command and copy the result for later use.

```bash
# on the host running minikube
cat ~/.minikube/ca.crt | base64
```

## Access Minikube Remotely

In this step, we set up kubeconfig on our second host.

If you have a pre-existing kube config, take its backup.

```bash
cp ~/.kube/config ~/.kube/config.bk
```

Place the file `config` from current directory inside `~/.kube`.

In the new `~/.kube/config` file:

1. Replace the `BASE64_ENCODED_CA_CERT` from the with the value copied in the `Dealing With Certificates` stage.
2. Replace the `MINIKUBE_HOSTNAME_OR_IP` with either `HOSTNAME` or `IP` of the minikube host used in stage `Start Minikube` above.
3. Replace `OIDC_ISSUER_URL, OIDC_CLIENT_ID, and OIDC_CLIENT_SECRET` credentials with appropriate values from the stage `Start Minikube` above.

Once the above steps are completed, we can access the minikube from the remote host.

```bash
> kubectl get pod
No resources found in default namespace.
```

The above command should open up a browser window for you to login. Once the log in is successful, you can see the response from the kubectl command.

If there are any issue with the authentication, check [Kubelogin](https://github.com/int128/kubelogin) for more details and troubleshooting.

In case you are not using `oidc/kubelogin`, you can copy over minikube generated client key and certificate from host 1 onto host 2 and use them in the kube config for authentication. These will have admin access.

Note: SCP needs target folder to already exist as well as using lowercase characters.

```bash
scp -r user@host1:~/.minikube/profiles/minikube/client.crt .minikube/profiles/minikube/client.crt
scp -r user@host1:~/.minikube/profiles/minikube/client.key .minikube/profiles/minikube/client.key
```

```yaml
# ~/.kube/config
# REDACTED
users:
- name: minikube
  user:
    client-certificate: /home/USER/.minikube/profiles/minikube/client.crt
    client-key: /home/USER/.minikube/profiles/minikube/client.key
```

## Reference

- https://minikube.sigs.k8s.io/docs/start/
- https://minikube.sigs.k8s.io/docs/tutorials/openid_connect_auth/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/#configuring-the-api-server
- https://docs.nginx.com/nginx/admin-guide/load-balancer/tcp-udp-load-balancer/#configuring-reverse-proxy
- https://zepworks.com/posts/access-minikube-remotely-kvm/
