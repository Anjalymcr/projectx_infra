---
title: Environments
---

ProjectX-Infra supports multiple isolated environments using a directory-based structure. Each environment is fully self-contained with its own Terraform state and variable values.

## Current Environment

| Property | Value |
|----------|-------|
| Environment name | `dev` |
| AWS Region | `ap-southeast-2` (Sydney) |
| Makefile default | `ENV=dev` |

The `dev` environment is the default and currently the only deployed environment.

## Directory Structure

Environments are organized under `deploy/aws/{ENV}/`, with each infrastructure layer in its own subdirectory:

```
deploy/aws/
└── dev/
    ├── infra/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── env.tfvars
    ├── storage/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── env.tfvars
    ├── iam/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── env.tfvars
    └── eks/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── env.tfvars
```

## Environment Selection

The environment is selected via the `ENV` variable in the Makefile, which defaults to `dev`:

```makefile
ENV ?= dev
```

All layer directory paths are derived from this variable:

```makefile
INFRA_DIR   = deploy/aws/$(ENV)/infra
STORAGE_DIR = deploy/aws/$(ENV)/storage
IAM_DIR     = deploy/aws/$(ENV)/iam
EKS_DIR     = deploy/aws/$(ENV)/eks
```

To target a different environment, override `ENV` on the command line:

```bash
make deploy-all ENV=staging
make deploy-all ENV=prod
```

## State Isolation

Each environment maintains its own Terraform state. State files are stored independently (either locally or in a per-environment S3 backend), so changes to one environment have no effect on another. There is no shared state between environments.

## Production Mirroring

A production environment would use the same directory structure with different values in `env.tfvars`. The key differences for a production configuration include:

| Setting | Dev | Prod |
|---------|-----|------|
| `deletion_protection` | `false` | `true` — prevents accidental deletion of RDS and other stateful resources |
| `single_nat_gateway` | `true` | `false` — deploys one NAT gateway per AZ for high availability |
| `cluster_endpoint_public_access` | `true` | `false` — restricts EKS API access to the VPC (requires VPN or bastion) |
| Instance types | Smaller/cheaper (e.g., `t3.medium`) | Larger/production-grade (e.g., `m5.large`, `r5.large`) |
| Node group scaling | Minimal (e.g., 1-2 nodes) | Right-sized (e.g., 3-10 nodes with autoscaling) |

To create a production environment:

1. Copy the `dev` directory:
   ```bash
   cp -r deploy/aws/dev deploy/aws/prod
   ```
2. Update each layer's `env.tfvars` with production-appropriate values.
3. Configure a separate Terraform state backend (e.g., a different S3 bucket or key prefix).
4. Deploy with `ENV=prod`:
   ```bash
   make deploy-all ENV=prod
   ```
