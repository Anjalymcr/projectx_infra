---
title: Terraform Variables
---

Complete reference of all Terraform input variables across each infrastructure layer.

## Shared Variables (common.tfvars)

These variables are shared across all layers via `deploy/aws/dev/common.tfvars`:

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `project` | `string` | `"ProjectX-Infra"` | Project name for resource tagging |
| `owner` | `string` | `"Infra-Team"` | Team owning this infrastructure |
| `cost_center` | `string` | `"Engineering-101"` | Cost center for billing |

## Infra Layer

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `region` | `string` | `"ap-southeast-2"` | AWS region for all infrastructure resources |
| `environment` | `string` | `"dev"` | Environment name, used in resource naming and tagging |
| `vpc_cidr` | `string` | `"10.0.0.0/16"` | CIDR block for the VPC |
| `availability_zones` | `list(string)` | `["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]` | Availability zones for subnet placement |
| `private_subnets` | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]` | CIDR blocks for private subnets (one per AZ) |
| `public_subnets` | `list(string)` | `["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]` | CIDR blocks for public subnets (one per AZ) |

## Storage Layer

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `region` | `string` | `"ap-southeast-2"` | AWS region for storage resources |
| `environment` | `string` | `"dev"` | Environment name, used in bucket naming and tagging |

## IAM Layer

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `region` | `string` | `"ap-southeast-2"` | AWS region |
| `environment` | `string` | `"dev"` | Environment name, used in role/policy naming |

## DNS Layer

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `region` | `string` | `"ap-southeast-2"` | AWS region |
| `environment` | `string` | `"dev"` | Environment name |

## EKS Layer

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `region` | `string` | `"ap-southeast-2"` | AWS region for the EKS cluster |
| `environment` | `string` | `"dev"` | Environment name, used in cluster naming |
| `my_ip_cidr` | `string` | Auto-detected | Your public IP in CIDR notation, used for node security group access |
| `route53_zone_id` | `string` | Auto-fetched | Route53 zone ID for ExternalDNS configuration |

The `my_ip_cidr` variable is automatically populated by the Makefile via `ifconfig.me`. The `route53_zone_id` is fetched from the DNS layer's terraform output.

## Variable Files

Each environment uses two variable files: a shared `common.tfvars` and a layer-specific `env.tfvars`.

```
deploy/aws/dev/
├── common.tfvars        # Shared across all layers (project, owner, cost_center)
├── infra/env.tfvars     # VPC CIDR, AZs, subnets
├── storage/env.tfvars   # Region, environment
├── iam/env.tfvars       # Region, environment
├── dns/env.tfvars       # Region, environment
└── eks/env.tfvars       # Region, environment
```

The Makefile passes both files to Terraform:

```bash
terraform apply -var-file=../common.tfvars -var-file=env.tfvars
```
