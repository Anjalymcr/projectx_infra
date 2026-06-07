# =============================================================
# 1. DATA SOURCES
# =============================================================

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

data "aws_caller_identity" "current" {}

# =============================================================
# 2. EKS CLUSTER
# =============================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "${var.environment}-projectx-cluster"
  cluster_version = "1.31"

  vpc_id     = data.aws_vpc.network.id
  subnet_ids = data.aws_subnets.private.ids

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    system = {
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      labels         = { role = "system" }
    }
    runners = {
      min_size       = 1
      max_size       = 10
      desired_size   = 2
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
      labels         = { role = "runners" }
      taints = [{
        key    = "dedicated"
        value  = "runners"
        effect = "NO_SCHEDULE"
      }]
      tags = {
        "k8s.io/cluster-autoscaler/enabled"                             = "true"
        "k8s.io/cluster-autoscaler/${var.environment}-projectx-cluster" = "owned"
      }
    }
  }

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ProjectX-InfraProvisionerRole"
      username = "infra-admin"
      groups   = ["system:masters"]
    }
  ]

  node_security_group_additional_rules = {
    ingress_allow_me = {
      description = "Allow my laptop to talk to nodes"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [var.my_ip_cidr]
    }
  }

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
    aws-ebs-csi-driver = {
      most_recent                 = true
      service_account_role_arn    = module.ebs_csi_irsa_role.iam_role_arn
      resolve_conflicts_on_create = "OVERWRITE"
    }
    aws-efs-csi-driver = {
      most_recent                 = true
      service_account_role_arn    = module.efs_csi_irsa_role.iam_role_arn
      resolve_conflicts_on_create = "OVERWRITE"
    }
  }

  tags = local.common_tags
}

# =============================================================
# 3. CLUSTER ADDON IRSA (CSI Drivers)
# =============================================================

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
  role_name             = "${var.environment}-ebs-csi-role"
  attach_ebs_csi_policy = true
  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "efs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
  role_name             = "${var.environment}-efs-csi-role"
  attach_efs_csi_policy = true
  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
}

# =============================================================
# 4. CLUSTER INFRASTRUCTURE (Load Balancer Controller)
# =============================================================

module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
  role_name                              = "${var.environment}-lb-controller-role"
  attach_load_balancer_controller_policy = true
  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  # Individual 'set' blocks
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.load_balancer_controller_irsa_role.iam_role_arn
  }

  # Meta-arguments should ideally go at the bottom
  depends_on = [module.eks]
}

# =============================================================
# 5. APPLICATION IRSA (Jenkins)
# =============================================================

resource "aws_iam_policy" "jenkins_s3" {
  name = "${var.environment}-jenkins-s3-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::projectx-jenkins-artifacts-${var.environment}-*",
          "arn:aws:s3:::projectx-jenkins-artifacts-${var.environment}-*/*",
          "arn:aws:s3:::projectx-release-${var.environment}-*",
          "arn:aws:s3:::projectx-release-${var.environment}-*/*"
        ]
      }
    ]
  })
  tags = local.common_tags
}

module "jenkins_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
  role_name = "${var.environment}-jenkins-role"
  role_policy_arns = {
    S3Access  = aws_iam_policy.jenkins_s3.arn
    ECRAccess = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  }
  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["jenkins:jenkins"]
    }
  }
}

# =============================================================
  # 6. CLUSTER INFRASTRUCTURE (Secrets Store CSI Driver)
  # =============================================================

  resource "helm_release" "secrets_store_csi_driver" {
    name       = "secrets-store-csi-driver"
    repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
    chart      = "secrets-store-csi-driver"
    namespace  = "kube-system"
    version    = "1.4.7"

    set {
      name  = "syncSecret.enabled"
      value = "true"
    }

    set {
      name  = "enableSecretRotation"
      value = "true"
    }

    depends_on = [module.eks]
  }

  resource "helm_release" "secrets_store_csi_driver_provider_aws" {
    name       = "secrets-store-csi-driver-provider-aws"
    repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws/"
    chart      = "secrets-store-csi-driver-provider-aws"
    namespace  = "kube-system"
    version    = "0.3.11"

    depends_on = [helm_release.secrets_store_csi_driver]
  }

# =============================================================
  # 7. CLUSTER INFRASTRUCTURE (Cluster Autoscaler)
# =============================================================

  module "cluster_autoscaler_irsa_role" {
    source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    version = "~> 5.0"

    role_name                        = "${var.environment}-cluster-autoscaler-role"
    attach_cluster_autoscaler_policy = true
    cluster_autoscaler_cluster_names = [module.eks.cluster_name]

    oidc_providers = {
      ex = {
        provider_arn               = module.eks.oidc_provider_arn
        namespace_service_accounts = ["kube-system:${var.environment}-cluster-autoscaler-aws-cluster-autoscaler"]
      }
    }
  }

  resource "helm_release" "cluster_autoscaler" {
    name       = "${var.environment}-cluster-autoscaler"
    repository = "https://kubernetes.github.io/autoscaler"
    chart      = "cluster-autoscaler"
    namespace  = "kube-system"
    version    = "9.43.2"

    set {
      name  = "rbac.create"
      value = "true"
    }

    set {
      name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.cluster_autoscaler_irsa_role.iam_role_arn
    }

    set {
      name  = "cloudProvider"
      value = "aws"
    }

    set {
      name  = "awsRegion"
      value = var.region
    }

    set {
      name  = "autoDiscovery.clusterName"
      value = module.eks.cluster_name
    }

    set {
      name  = "autoDiscovery.enabled"
      value = "true"
    }

    set {
      name  = "nodeSelector.role"
      value = "system"
    }

    depends_on = [module.eks]
  }


# =============================================================
  # 8. CLUSTER INFRASTRUCTURE (Fluent Bit — Log Shipping)
  # =============================================================

  resource "aws_iam_policy" "fluentbit_cloudwatch" {
    name = "${var.environment}-fluentbit-cloudwatch"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams",
            "logs:PutRetentionPolicy"
          ]
          Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/eks/${var.environment}-projectx-cluster/*"
        }
      ]
    })
    tags = local.common_tags
  }

  module "fluentbit_irsa_role" {
    source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    version = "~> 5.0"

    role_name ="${var.environment}-fluentbit-role"
    role_policy_arns = {
      CloudWatch = aws_iam_policy.fluentbit_cloudwatch.arn
    }

    oidc_providers = {
      ex = {
        provider_arn               = module.eks.oidc_provider_arn
        namespace_service_accounts = ["kube-system:${var.environment}-fluent-bit"]
      }
    }
  }

  resource "helm_release" "fluent_bit"{
    name       = "${var.environment}-fluent-bit"
    repository = "https://fluent.github.io/helm-charts"
    chart      = "fluent-bit"
    namespace  = "kube-system"
    version    = "0.47.10"

    set {
      name  = "serviceAccount.create"
      value = "true"
    }

    set {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.fluentbit_irsa_role.iam_role_arn
    }

    set {
      name  = "tolerations[0].key"
      value = "dedicated"
    }

    set {
      name  = "tolerations[0].value"
      value = "runners"
    }

    set {
      name  = "tolerations[0].effect"
      value = "NoSchedule"
    }

    values = [<<-YAML
      config:
        outputs: |
          [OUTPUT]
              Name       cloudwatch_logs
              Match      *
              region     ${var.region}
              log_group_name /eks/${var.environment}-projectx-cluster/containers
              log_stream_prefix  fluent-bit-
              auto_create_group true
    YAML
    ]

    depends_on = [module.eks]
  }