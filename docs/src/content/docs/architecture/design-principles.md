---
title: Design Principles
---

ProjectX-Infra is built on a set of deliberate engineering principles that guide every architectural decision. These principles ensure the platform remains reliable, secure, cost-effective, and easy to operate as it grows.

## Pipeline-as-Code

Every infrastructure change flows through a codified pipeline. Terraform configurations are version-controlled in Git, reviewed via pull requests, and applied through deterministic `make` targets. There is no manual clicking in the AWS console -- if it is not in code, it does not exist. This makes every change auditable, reproducible, and reversible.

## Immutable Infrastructure

Resources are replaced rather than mutated. When a configuration changes, Terraform destroys the old resource and creates a new one with the updated settings. This eliminates configuration drift, removes the risk of partially-applied changes, and guarantees that what runs in production exactly matches what is defined in code. Node groups, for example, are rolled rather than patched in place.

## Zero Standing Access

No human or service retains persistent privileged access to the environment. IAM roles are scoped to the minimum permissions each layer requires, and temporary credentials are used wherever possible. EKS API endpoints are private by default, and Secrets Manager handles sensitive values so they never appear in plaintext in Terraform state or environment variables. The goal is to reduce the blast radius of any compromised credential to near zero.

## Observability First

Infrastructure is designed to be observable from day one, not instrumented as an afterthought. VPC Flow Logs, CloudWatch metrics, and S3 access logging are enabled at the network and storage layers. The planned Layer 5 (Analytics and Observability) will add Prometheus, Grafana, and CloudWatch dashboards to give operators real-time visibility into cluster health, application performance, and cost trends.

## Modular Layering

The platform is decomposed into six independent layers, each with its own Terraform state, variables, and outputs. This modularity means a change to an IAM policy does not require re-planning the entire VPC, and a node group scale-out does not touch the database layer. Teams can own individual layers, apply changes in isolation, and reason about failure domains without understanding the entire stack. Shared logic is extracted into reusable modules under the `modules/` directory.

## Cost Optimisation

Cloud spend is treated as a first-class engineering concern, not a finance problem. The platform uses several strategies to control costs without compromising reliability:

- **Spot instances** are used for non-critical EKS node groups, reducing compute costs by up to 70% compared to on-demand pricing. On-demand capacity is retained for system workloads that cannot tolerate interruption.
- **S3 lifecycle policies** automatically transition infrequently accessed objects to cheaper storage classes (Infrequent Access, then Glacier) and expire obsolete data after a defined retention period.
- **ECR lifecycle policies** prune untagged and aged container images to prevent unbounded registry growth.
- **Right-sized RDS instances** are selected based on actual workload profiling rather than worst-case estimates, with the ability to scale vertically during the next maintenance window if demand increases.
- **NAT gateway per AZ** may appear more expensive than a single shared gateway, but it eliminates cross-AZ data transfer charges and provides resilience -- a net cost saving at moderate traffic volumes.
