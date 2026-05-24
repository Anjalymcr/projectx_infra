---
title: Makefile Reference
---

Complete reference for all Make targets in the ProjectX-Infra Makefile, organized by section.

## Global Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV` | `dev` | Target environment name |
| `AWS_REGION` | `ap-southeast-2` | AWS region for deployment |
| `AWS_PROFILE` | `default` | AWS CLI profile to use |
| `MY_IP` | Auto-detected via `ifconfig.me` | Your public IP (appended with `/32`) for EKS API access |
| `INFRA_DIR` | `deploy/aws/$(ENV)/infra` | Path to the infra layer |
| `STORAGE_DIR` | `deploy/aws/$(ENV)/storage` | Path to the storage layer |
| `IAM_DIR` | `deploy/aws/$(ENV)/iam` | Path to the IAM layer |
| `EKS_DIR` | `deploy/aws/$(ENV)/eks` | Path to the EKS layer |

## Layer 1: Infra

| Target | Command | Description | Dependencies |
|--------|---------|-------------|--------------|
| `infra-init` | `terraform -chdir=$(INFRA_DIR) init` | Initialize the infra layer (download providers, configure backend) | None |
| `infra-plan` | `terraform -chdir=$(INFRA_DIR) plan -var-file=env.tfvars` | Preview changes to VPC, subnets, NAT gateway, and security groups | `infra-init` |
| `infra-apply` | `terraform -chdir=$(INFRA_DIR) apply -auto-approve -var-file=env.tfvars` | Apply infra layer changes | `infra-init` |

## Layer 2: Storage

| Target | Command | Description | Dependencies |
|--------|---------|-------------|--------------|
| `storage-init` | `terraform -chdir=$(STORAGE_DIR) init` | Initialize the storage layer | None |
| `storage-plan` | `terraform -chdir=$(STORAGE_DIR) plan -var-file=env.tfvars` | Preview changes to S3 buckets, RDS, and Secrets Manager | `storage-init` |
| `storage-apply` | `terraform -chdir=$(STORAGE_DIR) apply -auto-approve -var-file=env.tfvars` | Apply storage layer changes | `storage-init`, `infra-apply` |

## Layer 3: IAM

| Target | Command | Description | Dependencies |
|--------|---------|-------------|--------------|
| `iam-init` | `terraform -chdir=$(IAM_DIR) init` | Initialize the IAM layer | None |
| `iam-plan` | `terraform -chdir=$(IAM_DIR) plan -var-file=env.tfvars` | Preview changes to IAM roles, policies, and instance profiles | `iam-init` |
| `iam-apply` | `terraform -chdir=$(IAM_DIR) apply -auto-approve -var-file=env.tfvars` | Apply IAM layer changes | `iam-init`, `infra-apply` |

## Layer 4: EKS

| Target | Command | Description | Dependencies |
|--------|---------|-------------|--------------|
| `eks-init` | `terraform -chdir=$(EKS_DIR) init` | Initialize the EKS layer | None |
| `eks-plan` | `terraform -chdir=$(EKS_DIR) plan -var-file=env.tfvars -var="my_ip_cidr=$(MY_IP)"` | Preview changes to EKS cluster, node groups, and add-ons | `eks-init` |
| `eks-apply` | `terraform -chdir=$(EKS_DIR) apply -auto-approve -var-file=env.tfvars -var="my_ip_cidr=$(MY_IP)"` | Apply EKS layer changes | `eks-init`, `infra-apply`, `iam-apply` |

## Orchestration

| Target | Command | Description | Dependencies |
|--------|---------|-------------|--------------|
| `init-all` | Runs `infra-init`, `storage-init`, `iam-init`, `eks-init` | Initialize all layers in sequence | None |
| `plan-all` | Runs `infra-plan`, `storage-plan`, `iam-plan`, `eks-plan` | Plan all layers in dependency order | `init-all` |
| `deploy-all` | Runs `infra-apply` -> `storage-apply` -> `iam-apply` -> `eks-apply` | Deploy all layers in dependency order | `init-all` |
| `destroy-all` | Runs `destroy-eks` -> `destroy-iam` -> `destroy-storage` -> `destroy-infra` | Destroy all layers in reverse dependency order | None |

## Kubernetes Apps

| Target | Command | Description | Dependencies |
|--------|---------|-------------|--------------|
| `eks-auth` | `aws eks update-kubeconfig --name $(ENV)-cluster --region $(AWS_REGION)` | Configure kubectl to connect to the EKS cluster | `eks-apply` |
| `jenkins-deploy` | Helm install/upgrade of Jenkins chart | Deploy Jenkins onto the EKS cluster | `eks-auth` |
| `runners-deploy` | Apply Kubernetes manifests for GitHub Actions runners | Deploy self-hosted GitHub Actions runners | `eks-auth` |
| `status` | `kubectl get nodes,pods,svc -A` | Show cluster nodes, pods, and services across all namespaces | `eks-auth` |

## Destroy

| Target | Command | Description | Dependencies |
|--------|---------|-------------|--------------|
| `destroy-eks` | `terraform -chdir=$(EKS_DIR) destroy -auto-approve -var-file=env.tfvars -var="my_ip_cidr=$(MY_IP)"` | Destroy EKS cluster and node groups | None |
| `destroy-iam` | `terraform -chdir=$(IAM_DIR) destroy -auto-approve -var-file=env.tfvars` | Destroy IAM roles and policies | `destroy-eks` |
| `destroy-storage` | `terraform -chdir=$(STORAGE_DIR) destroy -auto-approve -var-file=env.tfvars` | Destroy S3 buckets, RDS, and secrets | `destroy-eks` |
| `destroy-infra` | `terraform -chdir=$(INFRA_DIR) destroy -auto-approve -var-file=env.tfvars` | Destroy VPC, subnets, and networking | `destroy-iam`, `destroy-storage` |
