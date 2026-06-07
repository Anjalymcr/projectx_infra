---
title: Makefile Reference
---

Complete reference for all Make targets in the ProjectX-Infra Makefile, organized by section.

## Global Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV` | `dev` | Target environment name |
| `AWS_REGION` | `ap-southeast-2` | AWS region for deployment |
| `AWS_PROFILE` | `svc-deployer` | AWS CLI profile to use |
| `MY_IP` | Auto-detected via `ifconfig.me` | Your public IP (appended with `/32`) for EKS API access |
| `ROUTE53_ZONE_ID` | Auto-fetched from DNS layer | Route53 zone ID passed to EKS layer for ExternalDNS |

## Layer 1: Infra

| Target | Description | Dependencies |
|--------|-------------|--------------|
| `infra-init` | Initialize the infra layer (download providers) | None |
| `infra-plan` | Preview changes to VPC, subnets, NAT gateway | `infra-init` |
| `infra-apply` | Apply infra layer changes | None |

## Layer 2: Storage

| Target | Description | Dependencies |
|--------|-------------|--------------|
| `storage-init` | Initialize the storage layer | None |
| `storage-plan` | Preview changes to RDS, EFS, ECR, S3, Secrets | `storage-init` |
| `storage-apply` | Apply storage layer changes | `infra-apply` |

## Layer 3: IAM

| Target | Description | Dependencies |
|--------|-------------|--------------|
| `iam-init` | Initialize the IAM layer | None |
| `iam-plan` | Preview changes to IAM roles and policies | `iam-init` |
| `iam-apply` | Apply IAM layer changes | `infra-apply` |

## Layer 4: DNS

| Target | Description | Dependencies |
|--------|-------------|--------------|
| `dns-init` | Initialize the DNS layer | None |
| `dns-plan` | Preview changes to Route53 hosted zone | `dns-init` |
| `dns-apply` | Apply DNS layer changes | `infra-apply` |

## Layer 5: EKS

| Target | Description | Dependencies |
|--------|-------------|--------------|
| `eks-init` | Initialize the EKS layer | None |
| `eks-plan` | Preview changes to EKS cluster, addons, and Helm releases | `eks-init` |
| `eks-apply` | Apply EKS layer changes | `infra-apply`, `iam-apply`, `dns-apply` |

All EKS targets automatically pass `my_ip_cidr` and `route53_zone_id` variables.

## Orchestration

| Target | Description | Dependencies |
|--------|-------------|--------------|
| `init-all` | Initialize all 5 layers | None |
| `plan-all` | Plan all layers sequentially (continues on failure) | None |
| `deploy-all` | Deploy all layers: Infra -> Storage -> IAM -> DNS -> EKS | None |
| `destroy-all` | Destroy everything: Apps -> EKS -> DNS -> IAM -> Storage -> Infra | `destroy-apps` |

## Kubernetes Apps

| Target | Description | Dependencies |
|--------|-------------|--------------|
| `eks-auth` | Configure kubectl to connect to `dev-projectx-cluster` | `eks-apply` |
| `jenkins-deploy` | Deploy Jenkins via `k8s/aws/jenkins` Helm chart | `eks-auth` |
| `runners-deploy` | Deploy CI/CD runners | `eks-auth` |
| `status` | Show all pods across all namespaces | `eks-auth` |

## Platform Services

| Target | Description | Dependencies |
|--------|-------------|--------------|
| `prometheus-deploy` | Deploy Prometheus via `k8s/aws/prometheus` Helm chart | `eks-auth` |
| `grafana-deploy` | Deploy Grafana via `k8s/aws/grafana` Helm chart | `eks-auth` |
| `platform-deploy` | Deploy both Prometheus and Grafana | `eks-auth` |

## Destroy Targets

| Target | Description |
|--------|-------------|
| `destroy-apps` | Uninstall all Helm releases (Jenkins, Grafana, Prometheus, Runners) and wait for ALB cleanup |
| `destroy-jenkins` | Uninstall Jenkins, delete ingress and namespace |
| `destroy-runners` | Uninstall Runners and delete namespace |
| `destroy-prometheus` | Uninstall Prometheus and delete monitoring namespace |
| `destroy-grafana` | Uninstall Grafana from monitoring namespace |
| `destroy-eks` | Destroy EKS cluster and all addons |
| `destroy-dns` | Destroy Route53 hosted zone |
| `destroy-iam` | Destroy IAM roles and policies |
| `destroy-storage` | Destroy RDS, EFS, ECR, S3, and secrets |
| `destroy-infra` | Destroy VPC and networking |
