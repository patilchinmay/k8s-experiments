# Kubespray
- [Kubespray](#kubespray)
  - [Description](#description)
  - [Process](#process)
    - [Remote server setup:](#remote-server-setup)
    - [Local controller Setup:](#local-controller-setup)
    - [Create Inventory](#create-inventory)
    - [Modify config](#modify-config)
    - [Review config](#review-config)
    - [Delete or Deploy](#delete-or-deploy)
    - [Verify cluster access](#verify-cluster-access)
    - [OIDC auth:](#oidc-auth)
  - [References](#references)


## Description

We will create a kubernetes cluster on a remote server using `kubespray`.

It will have following configuration enabled:
- helm
- OIDC sign in
- certificate auto-renewal
- accessible using a DNS name

Prerequisites:
- 1 remote server (a linux dev pc in this case)
- 1 local machine (mac in this case. linux will work too)
- git
- python 3.11 or later
- virtualenv
- [kubelogin](https://github.com/int128/kubelogin)

## Process

### Remote server setup:

Execute the following on the remote server to let our user become `root` without password:
```bash
sudo vi /etc/sudoers

# Replace chinmay-patil with the name of your remote server's user
#Add the line after the line %sudo	ALL=(ALL:ALL) ALL
chinmay-patil ALL=(ALL) NOPASSWD:ALL
```
Ansible needs to become `root` on the remote server. By doing this step `ansible` can become `root` without needing the password. Thus, `ansible` commands are simplified.

### Local controller Setup:

Create virtual environment:
```bash
# At the root of this repo
WORKSPACE=$(pwd)

cd $WORKSPACE/ansible

virtualenv .venv --python=$(which python3.11) && source $(pwd)/.venv/bin/activate
```

Clone repo and checkout tag:
```bash
git clone git@github.com:kubernetes-sigs/kubespray.git

cd kubespray

git fetch --all --tags

git checkout tags/v2.24.1
```

Install requirements:
```bash
pip install -U -r requirements.txt
```

### Create Inventory

We can skip this step as we already have the inventory created and modified in `$WORKSPACE/clusters/devpc`.

```bash
cd $WORKSPACE/ansible/kubespray

# Copy `inventory/sample` as `$WORKSPACE/clusters/devpc`
cp -rfp inventory/sample/. $WORKSPACE/clusters/devpc

# Update Ansible inventory file with inventory builder
# Replace X.X.X.X with actual IP of the remote hosts
declare -a IPS=(X.X.X.X)
CONFIG_FILE=$WORKSPACE/clusters/devpc/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
```

### Modify config

**IMPORTANT**

By default `kubespray` uses the node names as node1, node2 etc.

Rename the nodes with actual host names of those node in the inventory file `$WORKSPACE/clusters/devpc/hosts.yaml`. This will avoid DNS resolution problems down the line.

Host names need to be lowercase alphanumeric with some allowed symbols such as dash(-)

MAKE THE REQUIRED CONFIG CHANGES AS MENTIONED IN `$WORKSPACE/clusters/devpc/README.md`.

### Review config

```bash
# Review and change parameters under ``inventory/mycluster/group_vars``
cat $WORKSPACE/clusters/devpc/group_vars/all/all.yml
cat $WORKSPACE/clusters/devpc/group_vars/k8s_cluster/k8s-cluster.yml
```

### Delete or Deploy

```bash
# To DELETE CLUSTER
# Clean up old Kubernetes cluster with Ansible Playbook - run the playbook as root
# The option `--become` is required, as for example cleaning up SSL keys in /etc/,
# uninstalling old packages and interacting with various systemd daemons.
# Without --become the playbook will fail to run!
# And be mind it will remove the current kubernetes cluster (if it's running)!
# ansible-playbook \
# -i inventory/mycluster/hosts.yaml  \
# --private-key=~/.ssh/dev-pc.private  \
# --user chinmay-patil \
# --become --become-user=root \
# reset.yml

# Since we have mentioned all details in the host file, we can simplify the command as
ansible-playbook -i $WORKSPACE/clusters/devpc/hosts.yaml reset.yml

# TO DEPLOY CLUSTER
# Deploy Kubespray with Ansible Playbook - run the playbook as root
# The option `--become` is required, as for example writing SSL keys in /etc/,
# installing packages and interacting with various systemd daemons.
# Without --become the playbook will fail to run!
# ansible-playbook \
# -i inventory/mycluster/hosts.yaml  \
# --private-key=~/.ssh/dev-pc.private  \
# --user chinmay-patil \
# --become --become-user=root \
# cluster.yml

# Since we have mentioned all details in the host file, we can simplify the command as
ansible-playbook -i $WORKSPACE/clusters/devpc/hosts.yaml cluster.yml
```

### Verify cluster access

On remote server, make a copy of kubeconfig:
```bash
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
```

On local machine, download kubeconfig:
```bash
scp -r chinmay-patil@dev-pc:~/.kube/config ~/.kube/config
```

Modify the kubeconfig on the local machine. Replace the server URL with the IP/Hostname of the remote server. Now you have the `kubernetes-admin` access to the user.

```bash
kubectl get pod
```

### OIDC auth:

The cluster should already have OIDC auth enabled since we applied the config changes according to the `$WORKSPACE/clusters/devpc/README.md` during creation of the cluster.

However, the any user coming in from OIDC auth will need to assigned roles explicitly so that they can access resources.

In this case,  we assign the OIDC user (with a group claim of `onprem-admin`) kubernetes `cluster-admin` privileges.

Apply ClusterRoleBinding:
```bash
kubectl apply -f oidc-admin-role.yaml
```

Now, anyone coming from oidc sign in with a group claim of `onprem-admin` will be treated as kubernetes cluster admin.

At this point, you can delete the `kubernetes-admin` user credentials from the kubeconfig file and add an oidc based user by using [kubelogin](https://github.com/int128/kubelogin).

Sample:
```yaml
# cat ~/.kube/config
<REDACTED>
users:
  - name: oidc-admin
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        args:
          - oidc-login
          - get-token
          - --oidc-issuer-url=https://PROVIDER_URL/auth/realms/REALM_NAME
          - --oidc-client-id=CLIENT_ID
          - --oidc-client-secret=CLIENT_SECRET
        command: kubectl
        env: null
        provideClusterInfo: false
```

Make sure you actually have the confidential OIDC Client, Client Role (`onprem-admin`) and Client Mapper (`client_roles`) over User Client Role.

Now if you run the following command, a browser window will open for you to complete the authentication process with the OIDC provider. And then you will get a response from the kubernetes cluster.

```bash
kubectl get pod
```

## References

- https://www.youtube.com/watch?v=9pLh2Tt1blc
- https://www.youtube.com/watch?v=lvkpIoySt3U
- https://dev.to/admantium/kubernetes-installation-tutorial-kubespray-46ek
- https://github.com/kubernetes-sigs/kubespray/issues/3546
- https://github.com/kubernetes-sigs/kubespray/issues/9947