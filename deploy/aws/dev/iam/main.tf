# 1. THE ADMINISTRATIVE HAT (The Principal Admin Role)
resource "aws_iam_role" "infra_provisioner" {
  name = "ProjectX-InfraProvisionerRole"

  # TRUST POLICY: Who is allowed to wear this hat?
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/anjaly-admin",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/svc-deployer"
          ]
        }
      }
    ]
  })

  tags = local.common_tags
}

# 2. THE PERMISSIONS (What can the hat DO?)
# We give this role full admin power so it can build EKS, VPC, etc.
resource "aws_iam_role_policy_attachment" "infra_admin_attach" {
  role       = aws_iam_role.infra_provisioner.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- THE CLUSTER BRAIN (Role for the EKS Service itself) ---
resource "aws_iam_role" "eks_master_role" {
  name = "ProjectX-EKSMasterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_master_policy" {
  role       = aws_iam_role.eks_master_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- THE WORKER BEES (Role for the EKS Servers/Nodes) ---
resource "aws_iam_role" "eks_node_role" {
  name = "ProjectX-EKSNodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

# Attach essential policies for the servers to talk to the cluster and ECR
resource "aws_iam_role_policy_attachment" "node_policy_attach" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])

  role       = aws_iam_role.eks_node_role.name
  policy_arn = each.value
}

# --- DATA SOURCES ---
data "aws_caller_identity" "current" {}
