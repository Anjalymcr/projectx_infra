---
title: Deployment Guide
---

This guide covers the full deployment workflow for ProjectX-Infra, including dependency ordering, step-by-step instructions, and individual layer deployment.

## Dependency Chain

The infrastructure is organized into four layers with strict dependencies:

```
Infra (Layer 1)
├── Storage (Layer 2) — depends on Infra
├── IAM (Layer 3) — depends on Infra
└── EKS (Layer 4) — depends on Infra + IAM
```

The Makefile enforces these dependencies via target ordering. You cannot deploy a downstream layer without its dependencies being in place first. For example, EKS requires both the VPC networking from Infra and the IAM roles from the IAM layer.

## Full Deployment Sequence

Follow these steps to deploy the entire stack from scratch.

### 1. Build and Enter the Workbench

```bash
make docker-build && make docker-dev
```

This builds the Docker-based development container (the "workbench") with all required tools (Terraform, AWS CLI, kubectl, Helm) and drops you into an interactive shell.

### 2. Initialize All Layers

```bash
make init-all
```

Runs `terraform init` across all four layers in dependency order, downloading providers and configuring state backends.

### 3. Deploy All Layers

```bash
make deploy-all
```

This orchestrates the full deployment in the correct order:

1. `infra-apply` — VPC, subnets, NAT gateway, security groups
2. `storage-apply` — S3 buckets, RDS database, Secrets Manager entries
3. `iam-apply` — IAM roles, policies, instance profiles
4. `eks-apply` — EKS cluster, node groups, add-ons

Each step runs `terraform apply -auto-approve` with the appropriate variable files.

### 4. Configure kubectl

```bash
make eks-auth
```

Updates your local kubeconfig to authenticate with the newly created EKS cluster using `aws eks update-kubeconfig`.

### 5. Deploy Applications

```bash
make jenkins-deploy
make runners-deploy
```

Deploys Jenkins and GitHub Actions runners onto the EKS cluster using Helm charts and Kubernetes manifests.

### 6. Verify Status

```bash
make status
```

Checks the health of the EKS cluster, running pods, services, and node readiness.

## Individual Layer Deployment

You can deploy layers individually when making targeted changes. Always ensure dependencies are already deployed.

### Layer 1: Infra

```bash
make infra-plan    # Preview changes
make infra-apply   # Apply changes
```

### Layer 2: Storage

```bash
make storage-plan  # Preview changes
make storage-apply # Apply changes
```

Requires Layer 1 (Infra) to be deployed — references VPC subnets for RDS placement.

### Layer 3: IAM

```bash
make iam-plan      # Preview changes
make iam-apply     # Apply changes
```

Requires Layer 1 (Infra) to be deployed.

### Layer 4: EKS

```bash
make eks-plan      # Preview changes
make eks-apply     # Apply changes
```

Requires Layer 1 (Infra) and Layer 3 (IAM) to be deployed — uses VPC subnets and IAM roles.

## MY_IP Auto-Detection

The EKS layer automatically detects your public IP address using `ifconfig.me` and passes it as the `my_ip_cidr` variable. This restricts the EKS API server's public endpoint to your current IP for security.

```makefile
MY_IP := $(shell curl -s ifconfig.me)/32
```

If you are behind a VPN or NAT, ensure the detected IP matches your actual egress IP. You can override it manually:

```bash
make eks-apply MY_IP="203.0.113.10/32"
```
