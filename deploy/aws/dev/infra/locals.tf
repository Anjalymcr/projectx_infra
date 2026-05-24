locals {
  common_tags = {
    Project     = "ProjectX-Infra"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "Infra-Team"
    CostCenter  = "Engineering-101"
  }
}
