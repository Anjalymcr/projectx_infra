---
title: Architecture Overview
---

ProjectX-Infra uses a **layered model** to organise AWS infrastructure into isolated, independently deployable Terraform stacks. Each layer has a clear responsibility boundary, its own state file, and well-defined inputs and outputs. This separation lets teams plan, apply, and destroy individual layers without risking unrelated resources.

## The Layered Model

### Layer 1 -- Network & Infrastructure

**Status:** Implemented

Provisions the foundational network fabric that every other layer builds on.

- VPC with CIDR `10.0.0.0/16`
- 3 public subnets and 3 private subnets across `ap-southeast-2a`, `ap-southeast-2b`, and `ap-southeast-2c`
- Single NAT gateway for cost-optimised egress (dev environment)
- VPC S3 Gateway endpoint for private S3 access without traversing the internet
- DNS hostnames and DNS resolution enabled
- Kubernetes-specific subnet tags for ALB Ingress Controller auto-discovery

See [Network Architecture](/architecture/networking/) for full details.

### Layer 2 -- Persistence & Registries

**Status:** Implemented

Creates the data stores, artifact registries, and secret vaults used by applications.

- **Amazon RDS** -- MySQL 8.0 database (`db.t3.micro`, 20GB gp3) for application metrics
- **Amazon EFS** -- Encrypted elastic file system for Jenkins persistent storage
- **Amazon ECR** -- Two container image repositories (`projectx-app`, `infra-tools`) with IMMUTABLE tags and lifecycle policies
- **Amazon S3** -- Four buckets (tf-state, jenkins-artifacts, analytics, release) with versioning and public access blocked
- **AWS Secrets Manager** -- Auto-generated database credentials with immediate deletion on destroy

### Layer 3 -- Identity & Access

**Status:** Implemented

Defines the IAM posture for the entire platform.

- IAM roles for EKS cluster and node groups
- IAM policies scoped to least-privilege per service
- `ProjectX-InfraProvisionerRole` for cluster admin access
- Instance profiles for EC2-backed workloads

### Layer 4 -- DNS

**Status:** Implemented

Manages private DNS for internal service discovery.

- **Route53 Private Hosted Zone** -- `projectx.internal` associated with the VPC
- ExternalDNS controller (deployed in EKS layer) automatically creates records from Kubernetes Ingress annotations

### Layer 5 -- Compute & Orchestration

**Status:** Implemented

Deploys the Kubernetes control plane, worker nodes, and all cluster infrastructure.

- **Amazon EKS** cluster (Kubernetes 1.31) with public and private API endpoints
- Managed node groups: system (ON_DEMAND `t3.medium`) and runners (SPOT `t3.large`)
- Cluster addons: CoreDNS, kube-proxy, VPC CNI, EBS CSI driver, EFS CSI driver
- **AWS Load Balancer Controller** (Helm v1.8.1) for ALB Ingress
- **Secrets Store CSI Driver** (Helm v1.4.7) + AWS Provider for Secrets Manager integration
- **Cluster Autoscaler** (Helm v9.43.2) for runner node scaling
- **Fluent Bit** (Helm v0.47.10) for CloudWatch log shipping from all nodes
- **ExternalDNS** (Helm v1.14.4) for automatic Route53 record management
- IRSA roles for all components (7 roles total)

### Kubernetes Applications

**Status:** Implemented

Deployed via Helm charts in the `k8s/aws/` directory.

- **Jenkins** -- CI/CD controller with EFS persistence, IRSA for S3/ECR, ALB ingress, JCasC configuration
- **Prometheus** -- Metrics collection with 10Gi gp2 storage, 7-day retention, Jenkins scrape config
- **Grafana** -- Dashboards with 5Gi gp2 storage, ALB ingress, Prometheus datasource auto-discovery

## Repository Structure

```
projectx-infra/
├── deploy/aws/dev/
│   ├── common.tfvars        # Shared variables (project, owner, cost_center)
│   ├── infra/               # Layer 1 -- VPC & Networking
│   ├── storage/             # Layer 2 -- RDS, EFS, ECR, S3, Secrets
│   ├── iam/                 # Layer 3 -- IAM Roles & Policies
│   ├── dns/                 # Layer 4 -- Route53 Private Zone
│   └── eks/                 # Layer 5 -- EKS, Addons, Helm Releases
├── k8s/aws/
│   ├── jenkins/             # Jenkins Helm chart & values
│   ├── prometheus/          # Prometheus Helm chart & values
│   └── grafana/             # Grafana Helm chart & values
├── docs/                    # This documentation site (Astro Starlight)
├── Dockerfile               # Dev container / workbench
├── Makefile                 # Orchestration entry point
└── README.md
```

## Layer Dependencies

Layers are deployed in numerical order because each layer consumes outputs from the layers below it:

```
Layer 1 (Network)
  ├──> Layer 2 (Storage)     -- needs VPC ID, subnet IDs
  ├──> Layer 3 (IAM)         -- needs VPC for role scoping
  └──> Layer 4 (DNS)         -- needs VPC for private hosted zone
         └──> Layer 5 (EKS)  -- needs VPC, subnets, IAM roles, Route53 zone ID
```

Layers discover each other via data source tag lookups (not remote state). When destroying resources, work in reverse order (EKS first, Infra last) to avoid orphaned dependencies. The `make destroy-all` target handles this automatically.
