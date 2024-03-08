## Description

We will create a kubernetes cluster on a remote server using `kubespray`.

It will have following configuration enabled:
- helm
- OIDC sign in
- certificate auto-renewal
- accessible using a DNS name

## Process

1. On the remote server:

Let our user become sudo without password:
```bash
sudo vi /etc/sudoers

# Replace chinmay-patil with the name of your user
#Add the line after the line %sudo	ALL=(ALL:ALL) ALL
chinmay-patil ALL=(ALL) NOPASSWD:ALL
```

2. Local controller Setup:

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

3. Create Inventory

```bash
cd $WORKSPACE/ansible/kubespray

# Copy ``inventory/sample`` as ``inventory/mycluster``
# We can skip this as we already have inventory in $WORKSPACE/clusters/devpc
cp -rfp inventory/sample inventory/mycluster

# Update Ansible inventory file with inventory builder
# We can skip this as we already have inventory in $WORKSPACE/clusters/devpc
# Replace X.X.X.X with actual IP of the remote hosts
declare -a IPS=(X.X.X.X)
CONFIG_FILE=$WORKSPACE/clusters/devpc/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
```

4. Modify config

**IMPORTANT**

By default `kubespray` uses the node names as node1, node2 etc.

Rename the nodes with actual host names of those node in the inventory file `$WORKSPACE/clusters/devpc/hosts.yaml`. This will avoid DNS resolution problems down the line.

Host names need to be lowercase alphanumeric with some allowed symbols such as dash(-)

MAKE THE REQUIRED CONFIG CHANGES AS MENTIONED IN `$WORKSPACE/clusters/devpc/README.md`.

5. Review config

```bash
# Review and change parameters under ``inventory/mycluster/group_vars``
cat $WORKSPACE/clusters/devpc/group_vars/all/all.yml
cat $WORKSPACE/clusters/devpc/group_vars/k8s_cluster/k8s-cluster.yml
```

6. Deploy

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

7. Verify

On remote server, make a copy of kubeconfig:
```bash
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
```

On local machine, download kubeconfig:
```bash
scp -r chinmay-patil@dev-pc:~/.kube/config ~/.kube/config
```

Modify the kubeconfig on the local machine. Replace the server URL with the IP/Hostname of the remote server. Now you have the `kubernetes-admin` access to the user.

8. OIDC:

Apply ClusterRoleBinding:
`kubectl apply -f oidc-admin-role.yaml`

Now, anyone coming from oidc sign in with a group claim of `onprem-admin` will be treated as kubernetes cluster admin.

At this point, you can delete the `kubernetes-admin` credentials from the kubeconfig file and add an oidc based user by using [kubelogin](https://github.com/int128/kubelogin).

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


## References

- https://www.youtube.com/watch?v=9pLh2Tt1blc
- https://www.youtube.com/watch?v=lvkpIoySt3U
- https://dev.to/admantium/kubernetes-installation-tutorial-kubespray-46ek
- https://github.com/kubernetes-sigs/kubespray/issues/3546
- https://github.com/kubernetes-sigs/kubespray/issues/9947