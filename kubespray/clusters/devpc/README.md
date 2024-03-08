# Cluster config

---

File `/group_vars/k8s_cluster/addons.yml`:

Helm:
- `helm_enabled: true`

---

File `/group_vars/k8s_cluster/k8s-cluster.yml`:

Certificate auto-renewal:
  - `auto_renew_certificates: true`
  - uncomment `auto_renew_certificates_systemd_calendar`

Use appropriate values as per OIDC provider:
- `kube_oidc_auth: true`
- `kube_oidc_url: https://PROVIDER_URL/auth/realms/REALM_NAME`
- `kube_oidc_client_id: CLIENT_ID`
- `kube_oidc_username_claim: email`
- `kube_oidc_username_prefix: "oidc:"`
- `kube_oidc_groups_claim: client_roles`
- `kube_oidc_groups_prefix: "oidc:"`

Make sure you actually have the confidential OIDC Client, Client Role (`onprem-admin`) and Client Mapper (`client_roles`) over User Client Role.

Access using DNS Name:
```yaml
supplementary_addresses_in_ssl_keys:
  - REMOTE_HOST_DNS_NAME
```

---