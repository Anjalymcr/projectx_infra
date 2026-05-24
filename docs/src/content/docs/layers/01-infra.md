---
title: "Layer 1: Infrastructure (VPC & Networking)"
---

## Purpose

Layer 1 is the foundation of the entire ProjectX infrastructure. It provisions the Virtual Private Cloud (VPC) and all associated networking resources, establishing the network isolation boundary within which all other layers operate. Every subsequent layer depends on the VPC and subnets created here.

## Directory Structure

```
deploy/aws/dev/infra/
├── main.tf          # VPC module invocation and resource definitions
├── variables.tf     # Input variable declarations
├── locals.tf        # Local values and computed expressions
├── versions.tf      # Terraform and provider version constraints
└── env.tfvars       # Environment-specific variable values
```

## Module

This layer uses the community VPC module:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name = "${local.project}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnet_cidrs
  public_subnets  = local.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_vpn_gateway = false

  # S3 VPC Gateway Endpoint
  enable_s3_endpoint = true

  # Tags required for Kubernetes ALB Controller discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                              = "1"
    "kubernetes.io/cluster/${local.cluster_name}"          = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                     = "1"
    "kubernetes.io/cluster/${local.cluster_name}"          = "shared"
  }

  tags = local.common_tags
}
```

## Resources Created

| Resource | Details |
|----------|---------|
| **VPC** | CIDR `10.0.0.0/16` |
| **Private Subnets** | 3 subnets, one per Availability Zone |
| **Public Subnets** | 3 subnets, one per Availability Zone |
| **NAT Gateways** | 3 provisioned (one per AZ), but `single_nat_gateway = true` routes all traffic through one to reduce cost |
| **Internet Gateway** | 1, attached to the VPC for public subnet routing |
| **S3 VPC Gateway Endpoint** | Allows private access to S3 without traversing the internet |
| **Route Table Associations** | Private subnets routed through NAT gateway; public subnets routed through Internet Gateway |

## Key Configuration

```hcl
single_nat_gateway   = true    # Cost optimization: all private subnets share one NAT gateway
enable_dns_hostnames = true    # Required for EKS and service discovery
enable_dns_support   = true    # Required for DNS resolution within the VPC
```

### Kubernetes Subnet Tags

The ALB Ingress Controller in EKS uses specific tags to discover which subnets to place load balancers in:

- **Public subnets**: Tagged with `kubernetes.io/role/elb = "1"` for internet-facing ALBs.
- **Private subnets**: Tagged with `kubernetes.io/role/internal-elb = "1"` for internal ALBs.
- Both subnet types are tagged with `kubernetes.io/cluster/<cluster-name> = "shared"` so the controller knows which cluster owns them.

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_id` | The ID of the created VPC |
| `private_subnets` | List of private subnet IDs |
| `public_subnets` | List of public subnet IDs |
| `vpc_cidr_block` | The CIDR block of the VPC (`10.0.0.0/16`) |

These outputs are consumed by downstream layers (Storage, EKS) via Terraform remote state data sources or by looking up resources by tag.

## Commands

```bash
# Initialize Terraform working directory and download providers/modules
make infra-init

# Preview changes without applying
make infra-plan

# Apply the infrastructure changes
make infra-apply
```

:::caution
This is the base layer. Destroying it will cascade failures to all other layers. Always ensure no dependent resources exist before running `terraform destroy`.
:::
