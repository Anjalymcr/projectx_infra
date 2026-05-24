---
title: Terraform Variables
---

Complete reference of all Terraform input variables across each infrastructure layer, with their types and default values from the `env.tfvars` files.

## Infra Layer

| Variable | Type | Default Value | Description |
|----------|------|---------------|-------------|
| `region` | `string` | `"ap-southeast-2"` | AWS region for all infrastructure resources |
| `environment` | `string` | `"dev"` | Environment name, used in resource naming and tagging |
| `vpc_cidr` | `string` | `"10.0.0.0/16"` | CIDR block for the VPC |
| `availability_zones` | `list(string)` | `["ap-southeast-2a", "ap-southeast-2b"]` | Availability zones for subnet placement |
| `private_subnets` | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` | CIDR blocks for private subnets (one per AZ) |
| `public_subnets` | `list(string)` | `["10.0.101.0/24", "10.0.102.0/24"]` | CIDR blocks for public subnets (one per AZ) |

## Storage Layer

| Variable | Type | Default Value | Description |
|----------|------|---------------|-------------|
| `environment` | `string` | `"dev"` | Environment name, used in bucket naming and tagging |

## IAM Layer

| Variable | Type | Default Value | Description |
|----------|------|---------------|-------------|
| `region` | `string` | `"ap-southeast-2"` | AWS region (used for region-specific IAM conditions) |
| `environment` | `string` | `"dev"` | Environment name, used in role/policy naming and tagging |

## EKS Layer

| Variable | Type | Default Value | Description |
|----------|------|---------------|-------------|
| `region` | `string` | `"ap-southeast-2"` | AWS region for the EKS cluster |
| `environment` | `string` | `"dev"` | Environment name, used in cluster naming and tagging |
| `my_ip_cidr` | `string` | Auto-detected | Your public IP in CIDR notation (e.g., `203.0.113.10/32`), used to restrict EKS API server public access |

The `my_ip_cidr` variable is not defined in `env.tfvars`. It is automatically populated at runtime by the Makefile, which queries `ifconfig.me` to detect your current public IP address and appends `/32`:

```makefile
MY_IP := $(shell curl -s ifconfig.me)/32
```

This value is passed to Terraform via the `-var` flag:

```bash
terraform apply -var="my_ip_cidr=$(MY_IP)"
```

## Variable Files

Each environment has its own `env.tfvars` file located within the layer directory:

```
deploy/aws/dev/
├── infra/env.tfvars
├── storage/env.tfvars
├── iam/env.tfvars
└── eks/env.tfvars
```

To override any default, edit the corresponding `env.tfvars` file for the target environment and layer.
