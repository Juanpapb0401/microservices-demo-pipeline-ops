# Terraform Single AKS

This Terraform stack provisions one AKS cluster.

`staging` and `production` are Kubernetes namespaces managed by Helm, not separate Terraform environments.

## Variables

All values are intentionally baked into defaults in `variables.tf` for simplicity.

## Backend and state

State is local for lab simplicity. Terraform writes `terraform.tfstate` in this folder.

```bash
terraform init
```

## Plan and apply

```bash
terraform plan
terraform apply
```

## Cost defaults

- `sku_tier = Free`
- `node_count = 1`
- `vm_size = Standard_B2s`
- `os_disk_size_gb = 30`
