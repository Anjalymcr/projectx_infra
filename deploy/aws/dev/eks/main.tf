# 1. Search for our Network Foundation
data "aws_vpc" "network" {
  filter {
    name   = "tag:Name"
    values = ["${var.environment}-vpc"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.network.id]
  }
  filter {
    name   = "tag:kubernetes.io/role/internal-elb"
    values = ["1"]
  }
}

# 2. THE EKS CLUSTER
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3" # Modern Version

  cluster_name    = "${var.environment}-projectx-cluster"
  cluster_version = "1.31"

  vpc_id     = data.aws_vpc.network.id
  subnet_ids = data.aws_subnets.private.ids

  # SECURITY: Access from inside the network only
  cluster_endpoint_public_access  = true # Set to true for learning ease, false for Prod!
  cluster_endpoint_private_access = true

  # COMPUTE: Hybrid Node Groups (Industry Standard)
  eks_managed_node_groups = {
    # Node Group 1: Reliable servers for Jenkins Master
    system = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "system"
      }
    }

    # Node Group 2: Cheap servers for Build Workers (The Muscle)
    runners = {
      min_size     = 1
      max_size     = 10
      desired_size = 2

      instance_types = ["t3.large"]
      capacity_type  = "SPOT" # 70% cheaper!

      labels = {
        role = "runners"
      }

      taints = [{
        key    = "dedicated"
        value  = "runners"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  # --- CLUSTER ACCESS CONTROL (The 'aws-auth' map) ---
  # This tells EKS which AWS Users are allowed to be Admins
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      # This is the "Hat" we discussed creating earlier
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/InfraProvisionerRole"
      username = "infra-admin"
      groups   = ["system:masters"]
    }
  ]

  # PRODUCTION BEST PRACTICE: Allow your laptop to talk to the nodes
  node_security_group_additional_rules = {
    ingress_allow_me = {
      description = "Allow my laptop to talk to nodes"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [var.my_ip_cidr] # In Prod, this would be your specific IP
    }
  }

  tags = local.common_tags
}

data "aws_caller_identity" "current" {}
