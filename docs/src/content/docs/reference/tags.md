---
title: Tagging Strategy
---

ProjectX-Infra applies a consistent set of tags to every AWS resource through a shared `common_tags` local value defined in each layer's Terraform configuration.

## Common Tags

Every resource created by this project receives the following tags:

| Tag Key | Value | Description |
|---------|-------|-------------|
| `Project` | `ProjectX-Infra` | Identifies the project that owns the resource |
| `Environment` | `var.environment` | Environment name (e.g., `dev`, `staging`, `prod`) |
| `ManagedBy` | `Terraform` | Indicates the resource is managed by infrastructure-as-code |
| `Owner` | `Infra-Team` | Team responsible for the resource |
| `CostCenter` | `Engineering-101` | Cost allocation code for billing and chargeback |

These tags are defined as a `locals` block and applied via `default_tags` in the AWS provider or directly on each resource:

```hcl
locals {
  common_tags = {
    Project     = "ProjectX-Infra"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "Infra-Team"
    CostCenter  = "Engineering-101"
  }
}
```

## Why Consistent Tagging Matters

### Cost Allocation

Tags are the primary mechanism for breaking down AWS costs by project, team, and environment. The `CostCenter` and `Project` tags enable finance and engineering leadership to attribute infrastructure spend accurately in AWS Cost Explorer and billing reports.

### Resource Identification

In a shared AWS account or multi-project environment, tags make it immediately clear which resources belong to ProjectX-Infra. Filtering by `Project = ProjectX-Infra` in the AWS Console or CLI returns only resources managed by this stack.

### Automation

Tags enable automated operations such as:

- **Scheduled shutdowns:** Stop non-production resources tagged with `Environment = dev` outside business hours.
- **Backup policies:** Apply AWS Backup plans to resources matching specific tag combinations.
- **Cleanup scripts:** Identify and remove resources from decommissioned environments based on their `Environment` tag.

### Compliance

Many organizations require all cloud resources to carry specific metadata tags for audit and governance purposes. The `ManagedBy` tag proves that resources are managed through an approved IaC workflow rather than created manually. The `Owner` tag establishes a clear chain of responsibility for incident response and security reviews.

## Adding Custom Tags

To add project-specific or layer-specific tags, merge them with `common_tags`:

```hcl
resource "aws_instance" "example" {
  # ...

  tags = merge(local.common_tags, {
    Name = "example-instance"
    Role = "web-server"
  })
}
```

This ensures the standard tags are always present while allowing additional context per resource.
