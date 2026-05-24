---
title: Architecture Overview
---

ProjectX-Infra uses a **six-layer strategic model** to organise AWS infrastructure into isolated, independently deployable Terraform stacks. Each layer has a clear responsibility boundary, its own state file, and well-defined inputs and outputs. This separation lets teams plan, apply, and destroy individual layers without risking unrelated resources.

## The Six-Layer Model

### Layer 1 -- Network & Identity

**Status:** Implemented

Provisions the foundational network fabric that every other layer builds on.

- VPC with CIDR `10.0.0.0/16`
- 3 public subnets and 3 private subnets across `ap-southeast-2a`, `ap-southeast-2b`, and `ap-southeast-2c`
- One NAT gateway per Availability Zone for high-availability egress
- VPC S3 Gateway endpoint for private S3 access without traversing the internet
- DNS hostnames and DNS resolution enabled
- Kubernetes-specific subnet tags for ALB Ingress Controller auto-discovery

See [Network Architecture](/architecture/networking/) for full details.

### Layer 2 -- Persistence & Registries

**Status:** Implemented

Creates the data stores, artifact registries, and secret vaults used by applications.

- **Amazon RDS** -- Managed relational database (PostgreSQL) in a private subnet group
- **Amazon EFS** -- Elastic file system for shared persistent storage across pods
- **Amazon ECR** -- Container image repositories with lifecycle policies
- **Amazon S3** -- Object storage buckets for application data, logs, and Terraform state
- **AWS Secrets Manager** -- Encrypted secret storage for database credentials and API keys

### Layer 3 -- Identity & Access

**Status:** Implemented

Defines the IAM posture for the entire platform.

- IAM roles for EKS cluster, node groups, and Fargate profiles
- IAM policies scoped to least-privilege per service
- IRSA (IAM Roles for Service Accounts) trust relationships
- Instance profiles for EC2-backed workloads

### Layer 4 -- Compute & Orchestration

**Status:** Implemented

Deploys the Kubernetes control plane and worker nodes.

- **Amazon EKS** cluster (Kubernetes 1.27) with a private API endpoint
- Managed node groups using a mix of on-demand and spot instances
- Cluster add-ons: CoreDNS, kube-proxy, VPC CNI, EBS CSI driver
- OIDC provider for IRSA integration
- Kubeconfig generation for operator access

### Layer 5 -- Analytics & Observability

**Status:** Planned

Will provide data analytics and platform-wide observability.

- Amazon Athena for serverless SQL queries over S3 data lakes
- AWS Glue for ETL cataloguing and data transformation
- CloudWatch dashboards, alarms, and log insights
- Prometheus and Grafana deployed via Helm into EKS

### Layer 6 -- Distribution & Routing

**Status:** Planned

Will handle global content delivery and DNS management.

- Amazon CloudFront distributions for static and dynamic content acceleration
- AWS Route 53 hosted zones and DNS record management
- ACM (AWS Certificate Manager) TLS certificates
- WAF (Web Application Firewall) rules attached to CloudFront and ALB

## Repository Structure

```
projectx-infra/
├── infra/                  # Layer 1 -- Network & Identity
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── storage/                # Layer 2 -- Persistence & Registries
│   ├── main.tf
│   ├── rds.tf
│   ├── efs.tf
│   ├── ecr.tf
│   ├── s3.tf
│   ├── variables.tf
│   └── outputs.tf
├── iam/                    # Layer 3 -- Identity & Access
│   ├── main.tf
│   ├── roles.tf
│   ├── policies.tf
│   ├── variables.tf
│   └── outputs.tf
├── eks/                    # Layer 4 -- Compute & Orchestration
│   ├── main.tf
│   ├── cluster.tf
│   ├── node_groups.tf
│   ├── addons.tf
│   ├── variables.tf
│   └── outputs.tf
├── modules/                # Shared reusable Terraform modules
├── scripts/                # Helper scripts (bootstrap, rotate, etc.)
├── docker/                 # Workbench Dockerfile and configs
│   └── Dockerfile
├── docs/                   # This documentation site (Astro Starlight)
├── diagrams/               # Architecture diagrams (draw.io / PNG)
├── Makefile                # Orchestration entry point
└── README.md
```

## Architecture Diagrams

Visual architecture diagrams are maintained in the `diagrams/` directory at the repository root. They cover the VPC network topology, EKS cluster layout, IAM trust relationships, and data flow between layers. Refer to those diagrams alongside this documentation for a complete picture of the platform.

## Layer Dependencies

Layers are deployed in numerical order because each layer consumes outputs from the layers below it:

```
Layer 1 (Network)
  └──> Layer 2 (Storage)    -- needs VPC ID, subnet IDs
        └──> Layer 3 (IAM)  -- needs resource ARNs from Storage
              └──> Layer 4 (EKS) -- needs VPC, subnets, IAM roles
```

Terraform remote state data sources (`terraform_remote_state`) wire these dependencies together automatically. When destroying resources, work in reverse order (Layer 4 first, Layer 1 last) to avoid orphaned dependencies.
