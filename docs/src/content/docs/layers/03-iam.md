---
title: "Layer 3: IAM (Roles & Policies)"
---

## Purpose

Layer 3 establishes identity and access management for the infrastructure. It creates the IAM roles and policy attachments required for Terraform operations, EKS cluster management, and EKS worker node permissions. These roles are referenced by Layer 4 (EKS) when provisioning the cluster and node groups.

## Directory Structure

```
deploy/aws/dev/iam/
├── main.tf          # IAM roles, policies, and trust relationships
├── variables.tf     # Input variable declarations
├── locals.tf        # Local values and computed expressions
└── env.tfvars       # Environment-specific variable values
```

## IAM Roles

This layer creates three IAM roles, each with a specific trust relationship and set of policies.

### 1. InfraProvisionerRole

The role assumed by human operators and CI/CD service accounts to run Terraform and manage infrastructure.

```hcl
resource "aws_iam_role" "infra_provisioner" {
  name = "InfraProvisionerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${local.account_id}:user/anjaly-admin",
            "arn:aws:iam::${local.account_id}:user/svc-deployer"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "infra_provisioner_admin" {
  role       = aws_iam_role.infra_provisioner.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
```

| Parameter | Value |
|-----------|-------|
| Role Name | `InfraProvisionerRole` |
| Trusted Principals | `anjaly-admin` (human), `svc-deployer` (CI/CD service account) |
| Attached Policy | `AdministratorAccess` |
| Use Case | Terraform operations, infrastructure provisioning |

### 2. EKS Master Role (ProjectX-EKSMasterRole)

The IAM role assumed by the EKS control plane service.

```hcl
resource "aws_iam_role" "eks_master" {
  name = "ProjectX-EKSMasterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_master_policy" {
  role       = aws_iam_role.eks_master.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
```

| Parameter | Value |
|-----------|-------|
| Role Name | `ProjectX-EKSMasterRole` |
| Service Principal | `eks.amazonaws.com` |
| Attached Policy | `AmazonEKSClusterPolicy` |
| Use Case | EKS cluster control plane operations |

### 3. EKS Node Role (ProjectX-EKSNodeRole)

The IAM role assumed by EC2 instances running as EKS worker nodes.

```hcl
resource "aws_iam_role" "eks_node" {
  name = "ProjectX-EKSNodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_node_ssm" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

| Parameter | Value |
|-----------|-------|
| Role Name | `ProjectX-EKSNodeRole` |
| Service Principal | `ec2.amazonaws.com` |
| Attached Policies | `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonSSMManagedInstanceCore` |
| Use Case | EKS worker node operations, CNI networking, ECR image pulls, SSM access |

#### Node Role Policies Explained

| Policy | Purpose |
|--------|---------|
| `AmazonEKSWorkerNodePolicy` | Allows worker nodes to connect to the EKS cluster |
| `AmazonEKS_CNI_Policy` | Manages ENIs and IP addresses for pod networking via the VPC CNI plugin |
| `AmazonEC2ContainerRegistryReadOnly` | Allows pulling container images from ECR |
| `AmazonSSMManagedInstanceCore` | Enables SSM Session Manager access for node troubleshooting without SSH |

## IAM ARN Format

:::note
AWS-managed policy ARNs follow the format:

```
arn:aws:iam::aws:policy/PolicyName
```

Note the double colon (`::`) with no account ID, which indicates these are AWS-managed (global) policies rather than customer-managed policies. Customer-managed policies include the account ID: `arn:aws:iam::<account-id>:policy/PolicyName`.
:::

## Commands

```bash
# Initialize Terraform working directory and download providers/modules
make iam-init

# Preview changes without applying
make iam-plan

# Apply the IAM roles and policies
make iam-apply
```
