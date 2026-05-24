---
title: Prerequisites
---

Before you begin working with ProjectX-Infra, make sure you have the following tools, accounts, and access in place.

## Required Tools

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| **Docker Desktop** | 4.x | Runs the ProjectX Docker workbench container that bundles the full toolchain. |
| **Git** | 2.x | Clone the repository and manage version control. |
| **AWS CLI** | v2 (2.x) | Authenticate with AWS and manage credentials. Pre-installed in the workbench. |
| **Terraform** | >= 1.0.0 (workbench ships 1.5.2) | Provision and manage all infrastructure layers. Pre-installed in the workbench. |
| **kubectl** | 1.27.x (workbench ships 1.27.5) | Interact with the EKS Kubernetes cluster. Pre-installed in the workbench. |
| **Helm** | 3.x (workbench ships 3.12.3) | Deploy Kubernetes Helm charts for cluster add-ons. Pre-installed in the workbench. |

> **Tip:** The Docker workbench image (Ubuntu 22.04) bundles Terraform, kubectl, Helm, and the AWS CLI at tested, compatible versions. If you use the workbench you only need **Docker Desktop** and **Git** installed on your host machine.

## AWS Account Access

- An **AWS account** with **AdministratorAccess** (or equivalent) permissions. The Terraform layers create VPCs, subnets, NAT gateways, RDS instances, EFS file systems, ECR repositories, S3 buckets, IAM roles and policies, and EKS clusters -- all of which require broad IAM privileges.
- A set of **AWS credentials** configured for the `ap-southeast-2` region. You can provide these via:
  - Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`).
  - An AWS CLI named profile (`aws configure --profile projectx`).
  - IAM instance profile / IRSA if running inside AWS.

## Optional but Recommended

| Tool | Purpose |
|------|---------|
| **make** (GNU Make) | The project uses a `Makefile` for orchestration. Pre-installed in the workbench and on most Unix systems. |
| **jq** | Handy for parsing Terraform output JSON. Pre-installed in the workbench. |
| **AWS Session Manager plugin** | Enables secure shell access to private instances without SSH keys. |
| **Lens / k9s** | Graphical or terminal UI for Kubernetes cluster management. |

## Network Requirements

- Outbound internet access to pull Docker images, Terraform providers, Helm charts, and AWS API calls.
- If you are behind a corporate proxy, configure Docker and the AWS CLI to route through it before running any commands.

## Verify Your Setup

Once Docker Desktop is running and you have cloned the repository, the fastest way to verify that everything is ready is to build and enter the workbench:

```bash
make docker-build   # Build the workbench image
make docker-dev     # Launch an interactive shell inside the container
terraform version   # Should print Terraform v1.5.2
kubectl version --client  # Should print v1.27.5
helm version        # Should print v3.12.3
aws --version       # Should print aws-cli/2.x
```

If all four commands return the expected versions, you are ready to proceed to the [Quickstart](/getting-started/quickstart/).
