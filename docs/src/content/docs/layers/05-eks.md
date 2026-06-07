---
title: "Layer 5: EKS (Compute & Orchestration)"
---

## Purpose

Layer 5 provisions the Amazon EKS cluster, managed node groups, cluster addons, and all cluster infrastructure via Helm releases. This includes the ALB controller, Secrets Store CSI driver, Cluster Autoscaler, Fluent Bit log shipping, and ExternalDNS.

## Directory Structure

```
deploy/aws/dev/eks/
├── main.tf          # EKS module, addons, IRSA roles, Helm releases
├── variables.tf     # Input variable declarations
├── locals.tf        # Local values and computed expressions
├── versions.tf      # Terraform and provider version constraints
├── providers.tf     # AWS, Kubernetes, and Helm provider configuration
├── outputs.tf       # Exported values for downstream consumers
└── env.tfvars       # Environment-specific variable values
```

## Dependencies

**Depends on: Layer 1 (VPC), Layer 3 (IAM), and Layer 4 (DNS)**

- **Layer 1** provides the VPC and private subnets where the cluster and nodes are deployed.
- **Layer 3** provides the IAM roles (`ProjectX-InfraProvisionerRole`) referenced by the cluster configuration.
- **Layer 4** provides the Route53 zone ID for ExternalDNS.

## EKS Cluster

| Parameter | Value |
|-----------|-------|
| Cluster Name | `dev-projectx-cluster` |
| Kubernetes Version | `1.31` |
| EKS Module | `terraform-aws-modules/eks/aws` v19.15.3 |
| Subnet Placement | Private subnets only |
| Public Endpoint | Enabled |
| Private Endpoint | Enabled |

### Endpoint Access

- **Public endpoint**: Allows `kubectl` access from developer machines and CI/CD pipelines outside the VPC.
- **Private endpoint**: Allows nodes and pods within the VPC to communicate with the API server without leaving the network.

## Node Groups

### 1. System Node Group

Dedicated to infrastructure workloads (Jenkins controller, Prometheus, Grafana, cluster addons).

| Parameter | Value |
|-----------|-------|
| Instance Type | `t3.medium` |
| Capacity Type | On-Demand |
| Min / Max / Desired | 1 / 2 / 1 |
| Node Label | `role=system` |

### 2. Runners Node Group

Elastic pool of spot instances for CI/CD job execution, managed by the Cluster Autoscaler.

| Parameter | Value |
|-----------|-------|
| Instance Type | `t3.large` |
| Capacity Type | Spot (~70% cost savings vs On-Demand) |
| Min / Max / Desired | 1 / 10 / 2 |
| Node Label | `role=runners` |
| Taint | `dedicated=runners:NoSchedule` |
| Autoscaler Tags | `k8s.io/cluster-autoscaler/enabled=true` |

:::tip
The `dedicated=runners:NoSchedule` taint ensures that only pods with a matching toleration are scheduled on runner nodes. This prevents infrastructure workloads from landing on spot instances that may be reclaimed.
:::

## Cluster Addons

Five EKS managed addons are deployed with the cluster:

| Addon | Purpose |
|-------|---------|
| `coredns` | DNS resolution within the cluster |
| `kube-proxy` | Kubernetes network proxy on each node |
| `vpc-cni` | AWS VPC networking for pods |
| `aws-ebs-csi-driver` | Allows pods to provision EBS volumes (uses IRSA) |
| `aws-efs-csi-driver` | Allows pods to mount EFS filesystems (uses IRSA) |

## Helm Releases

Six Helm releases are deployed as part of this layer:

### AWS Load Balancer Controller

Watches for Kubernetes Ingress resources with `ingressClassName: alb` and provisions AWS ALBs automatically.

| Parameter | Value |
|-----------|-------|
| Chart Version | v1.8.1 |
| Namespace | `kube-system` |
| IRSA Role | `dev-lb-controller-role` |

### Secrets Store CSI Driver

Allows pods to mount AWS Secrets Manager secrets as volumes.

| Parameter | Value |
|-----------|-------|
| CSI Driver Version | v1.4.7 |
| AWS Provider Version | v0.3.11 |
| Secret Rotation | Enabled |
| Secret Sync | Enabled |

### Cluster Autoscaler

Automatically scales runner node group up/down based on pending pod demand.

| Parameter | Value |
|-----------|-------|
| Chart Version | v9.43.2 |
| Namespace | `kube-system` |
| Node Selector | `role=system` |
| IRSA Role | `dev-cluster-autoscaler-role` |
| Auto-Discovery | Enabled (uses cluster name tags on node groups) |

### Fluent Bit

DaemonSet that runs on every node (including tainted runners) and ships container logs to CloudWatch.

| Parameter | Value |
|-----------|-------|
| Chart Version | v0.47.10 |
| Namespace | `kube-system` |
| CloudWatch Log Group | `/eks/dev-projectx-cluster/containers` |
| Log Stream Prefix | `fluent-bit-` |
| Runner Toleration | `dedicated=runners:NoSchedule` |
| IRSA Role | `dev-fluentbit-role` |

### ExternalDNS

Watches Kubernetes Ingress resources for `external-dns.alpha.kubernetes.io/hostname` annotations and automatically creates/deletes Route53 DNS records.

| Parameter | Value |
|-----------|-------|
| Chart Version | v1.14.4 |
| Namespace | `kube-system` |
| Provider | AWS (Route53) |
| Domain Filter | `projectx.internal` |
| Policy | `sync` (creates and deletes records) |
| Node Selector | `role=system` |
| IRSA Role | `dev-external-dns-role` |

## IRSA Roles

All AWS API access from pods uses IAM Roles for Service Accounts (IRSA).

| Role | Namespace:ServiceAccount | Permissions |
|------|--------------------------|-------------|
| `dev-ebs-csi-role` | `kube-system:ebs-csi-controller-sa` | EBS CSI policy |
| `dev-efs-csi-role` | `kube-system:efs-csi-controller-sa` | EFS CSI policy |
| `dev-lb-controller-role` | `kube-system:aws-load-balancer-controller` | Load Balancer Controller policy |
| `dev-cluster-autoscaler-role` | `kube-system:dev-cluster-autoscaler-*` | Cluster Autoscaler policy |
| `dev-fluentbit-role` | `kube-system:dev-fluent-bit` | CloudWatch Logs (Create/Put/Describe) |
| `dev-external-dns-role` | `kube-system:external-dns` | Route53 record management |
| `dev-jenkins-role` | `jenkins:jenkins` | S3 access + ECR PowerUser |

### Jenkins IRSA Permissions

- **S3 Access** -- `GetObject`, `PutObject`, `ListBucket`, `DeleteObject` on `projectx-jenkins-artifacts-dev-*` and `projectx-release-dev-*` buckets.
- **ECR PowerUser** -- Push and pull container images to/from ECR repositories.

## AWS Auth Configuration

The `aws-auth` ConfigMap maps IAM roles to Kubernetes RBAC:

| IAM Role | Kubernetes User | Kubernetes Groups | Access Level |
|----------|----------------|-------------------|-------------|
| `ProjectX-InfraProvisionerRole` | `infra-admin` | `system:masters` | Full cluster admin |

## Security

### Node Security Group Rules

| Rule | Protocol | Port | Source |
|------|----------|------|--------|
| `ingress_allow_me` | TCP | 443 | `var.my_ip_cidr` (auto-detected by Makefile) |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_name` | The name of the EKS cluster |
| `cluster_endpoint` | Endpoint URL for the EKS control plane |
| `cluster_security_group_id` | Security group ID of the cluster control plane |
| `oidc_provider_arn` | ARN of the OIDC provider for IRSA |
| `ebs_csi_irsa_role_arn` | IAM role ARN for the EBS CSI driver |
| `efs_csi_irsa_role_arn` | IAM role ARN for the EFS CSI driver |
| `load_balancer_controller_irsa_role_arn` | IAM role ARN for the ALB controller |
| `cluster_autoscaler_irsa_role_arn` | IAM role ARN for the Cluster Autoscaler |
| `fluentbit_irsa_role_arn` | IAM role ARN for Fluent Bit |
| `jenkins_irsa_role_arn` | IAM role ARN for Jenkins |

## Commands

```bash
make eks-init     # Initialize Terraform and download providers/modules
make eks-plan     # Preview changes (auto-fetches Route53 zone ID from DNS layer)
make eks-apply    # Apply the EKS cluster, addons, and Helm releases
make eks-auth     # Update local kubeconfig with cluster credentials
```
