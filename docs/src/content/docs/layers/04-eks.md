---
title: "Layer 4: EKS (Compute & Orchestration)"
---

## Purpose

Layer 4 provisions the Amazon EKS (Elastic Kubernetes Service) cluster that serves as the compute platform for all ProjectX workloads. This includes the Kubernetes control plane, managed node groups with distinct roles, authentication configuration, and security group rules.

## Directory Structure

```
deploy/aws/dev/eks/
├── main.tf          # EKS module invocation and supporting resources
├── variables.tf     # Input variable declarations
├── locals.tf        # Local values and computed expressions
├── versions.tf      # Terraform and provider version constraints
└── env.tfvars       # Environment-specific variable values
```

## Dependencies

**Depends on: Layer 1 (VPC) and Layer 3 (IAM Roles)**

- **Layer 1** provides the VPC and private subnets where the cluster and nodes are deployed.
- **Layer 3** provides the IAM roles (`ProjectX-EKSMasterRole`, `ProjectX-EKSNodeRole`, `InfraProvisionerRole`) referenced by the cluster configuration.

## Module

This layer uses the community EKS module:

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = local.cluster_name
  cluster_version = "1.31"

  vpc_id     = data.aws_vpc.main.id
  subnet_ids = data.aws_subnets.private.ids

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # IAM
  iam_role_arn = data.aws_iam_role.eks_master.arn

  # Node Groups
  eks_managed_node_groups = {
    system  = local.system_node_group
    runners = local.runners_node_group
  }

  # AWS Auth ConfigMap
  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = data.aws_iam_role.infra_provisioner.arn
      username = "infra-provisioner"
      groups   = ["system:masters"]
    }
  ]

  tags = local.common_tags
}
```

## Cluster Configuration

| Parameter | Value |
|-----------|-------|
| Cluster Name | `dev-projectx-cluster` |
| Kubernetes Version | `1.31` |
| Subnet Placement | Private subnets only |
| Public Endpoint | Enabled |
| Private Endpoint | Enabled |
| Control Plane Role | `ProjectX-EKSMasterRole` |

### Endpoint Access

The cluster is configured with both public and private endpoints enabled:

- **Public endpoint**: Allows `kubectl` access from developer machines and CI/CD pipelines outside the VPC.
- **Private endpoint**: Allows nodes and pods within the VPC to communicate with the API server without leaving the network.

## Node Groups

### 1. System Node Group

Dedicated to infrastructure workloads such as the Jenkins Master.

```hcl
system = {
  name          = "system"
  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"

  min_size     = 1
  max_size     = 2
  desired_size = 1

  iam_role_arn = data.aws_iam_role.eks_node.arn

  labels = {
    role = "system"
  }
}
```

| Parameter | Value |
|-----------|-------|
| Instance Type | `t3.medium` |
| Capacity Type | On-Demand |
| Min / Max / Desired | 1 / 2 / 1 |
| Node Label | `role=system` |
| Purpose | Jenkins Master and other infrastructure services |

### 2. Runners Node Group

Elastic pool of spot instances for CI/CD job execution, providing significant cost savings.

```hcl
runners = {
  name          = "runners"
  instance_types = ["t3.large"]
  capacity_type  = "SPOT"

  min_size     = 1
  max_size     = 10
  desired_size = 1

  iam_role_arn = data.aws_iam_role.eks_node.arn

  labels = {
    role = "runners"
  }

  taints = [
    {
      key    = "dedicated"
      value  = "runners"
      effect = "NO_SCHEDULE"
    }
  ]
}
```

| Parameter | Value |
|-----------|-------|
| Instance Type | `t3.large` |
| Capacity Type | Spot (~70% cost savings vs On-Demand) |
| Min / Max / Desired | 1 / 10 / 1 |
| Node Label | `role=runners` |
| Taint | `dedicated=runners:NoSchedule` |
| Purpose | CI/CD workers (Jenkins agents, build jobs) |

:::tip
The `dedicated=runners:NoSchedule` taint ensures that only pods with a matching toleration are scheduled on runner nodes. This prevents infrastructure workloads from landing on spot instances that may be reclaimed. CI/CD job pods must include the corresponding toleration:

```yaml
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "runners"
    effect: "NoSchedule"
```
:::

## AWS Auth Configuration

The `aws-auth` ConfigMap is managed by Terraform to control which IAM entities can access the cluster.

```hcl
aws_auth_roles = [
  {
    rolearn  = data.aws_iam_role.infra_provisioner.arn
    username = "infra-provisioner"
    groups   = ["system:masters"]
  }
]
```

| IAM Role | Kubernetes User | Kubernetes Groups | Access Level |
|----------|----------------|-------------------|-------------|
| `InfraProvisionerRole` | `infra-provisioner` | `system:masters` | Full cluster admin |

This means anyone who assumes the `InfraProvisionerRole` (the `anjaly-admin` and `svc-deployer` users from Layer 3) gets full administrative access to the Kubernetes cluster.

## Security

### Node Security Group Rules

A custom security group rule allows the deployer to reach port 443 on worker nodes (for direct API communication or debugging).

```hcl
resource "aws_security_group_rule" "node_ingress_deployer" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_cidr]
  security_group_id = module.eks.node_security_group_id
  description       = "Allow deployer HTTPS access to nodes"
}
```

The `my_ip_cidr` variable is set in `env.tfvars` and should be the deployer's IP address in CIDR notation (e.g., `203.0.113.10/32`).

## Kubernetes Provider Configuration

The Kubernetes and Helm providers are configured to authenticate against the EKS cluster using the AWS CLI token mechanism:

```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
  }
}
```

This avoids storing static credentials and instead generates short-lived tokens via `aws eks get-token`, which respects the caller's IAM identity and role assumptions.

## Commands

```bash
# Initialize Terraform working directory and download providers/modules
make eks-init

# Preview changes without applying
make eks-plan

# Apply the EKS cluster and node groups
make eks-apply

# Update local kubeconfig with cluster credentials
make eks-auth
```

### Post-Apply: Configuring kubectl

After the cluster is created, run `make eks-auth` to update your local kubeconfig. This typically executes:

```bash
aws eks update-kubeconfig \
  --name dev-projectx-cluster \
  --region <region> \
  --role-arn arn:aws:iam::<account-id>:role/InfraProvisionerRole
```

You can then verify access with:

```bash
kubectl get nodes
kubectl get pods -A
```
