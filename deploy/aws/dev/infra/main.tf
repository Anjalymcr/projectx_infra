module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # PRODUCTION BEST PRACTICE: High Availability
  # We use 3 NAT Gateways (one per AZ) so that if an entire AWS Data Center
  # goes down, your other subnets still have internet access.
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true


  # COMPLIANCE: Centralized Tagging
  tags = local.common_tags

  # K8S INTEGRATION: These tags are required for the AWS Load Balancer
  # Controller to find your subnets automatically.
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.environment}-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                               = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.environment}-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                      = "1"
  }
}
# Add VPC end point for s3 bucket access
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  tags              = local.common_tags
}

# Connect the Endpoint to your Route Tables
# This tells the private subnets to use the S3 Gateway

resource "aws_vpc_endpoint_route_table_association" "s3_default" {
  route_table_id  = module.vpc.default_route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint_route_table_association" "s3_private_infra" {
  count           = length(module.vpc.private_route_table_ids)
  route_table_id  = module.vpc.private_route_table_ids[count.index]
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}
 
# OUTPUTS (For the Database and EKS Layers)
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}
