---
title: "Layer 4: DNS (Route53)"
---

## Purpose

Layer 4 creates a Route53 private hosted zone for internal service discovery. DNS records are managed automatically by ExternalDNS (deployed in the EKS layer) based on Kubernetes Ingress annotations.

## Directory Structure

```
deploy/aws/dev/dns/
├── main.tf          # Route53 hosted zone and outputs
├── variables.tf     # Input variable declarations
├── locals.tf        # Local values and computed expressions
├── versions.tf      # Terraform and provider version constraints
└── env.tfvars       # Environment-specific variable values
```

## Dependencies

**Depends on: Layer 1 (VPC)**

The private hosted zone is associated with the VPC created in Layer 1. The VPC is looked up by tag (`Name = dev-vpc`).

## Resources

| Resource | Details |
|----------|---------|
| **Route53 Private Hosted Zone** | `projectx.internal` |
| **VPC Association** | Associated with `dev-vpc` |

## How DNS Records Are Created

This layer only creates the hosted zone. DNS records are created automatically by **ExternalDNS** (deployed in the EKS layer) when Kubernetes Ingress resources include the annotation:

```yaml
external-dns.alpha.kubernetes.io/hostname: jenkins.projectx.internal
```

ExternalDNS watches for these annotations and creates/deletes Route53 CNAME records pointing to the ALB address.

### Current DNS Records (auto-managed)

| Hostname | Service | Created By |
|----------|---------|------------|
| `jenkins.projectx.internal` | Jenkins ALB | ExternalDNS |
| `grafana.projectx.internal` | Grafana ALB | ExternalDNS |

## Outputs

| Output | Description |
|--------|-------------|
| `zone_id` | The Route53 hosted zone ID (consumed by EKS layer for ExternalDNS) |
| `zone_name` | The zone name (`projectx.internal`) |

## Commands

```bash
make dns-init     # Initialize Terraform
make dns-plan     # Preview changes
make dns-apply    # Create the hosted zone
```
