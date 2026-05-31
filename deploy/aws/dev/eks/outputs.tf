output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group IDs attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks.oidc_provider_arn
}

output "ebs_csi_irsa_role_arn" {
  description = "IAM role ARN for the EBS CSI driver"
  value       = module.ebs_csi_irsa_role.iam_role_arn
}

output "efs_csi_irsa_role_arn" {
  description = "IAM role ARN for the EFS CSI driver"
  value       = module.efs_csi_irsa_role.iam_role_arn
}

output "load_balancer_controller_irsa_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = module.load_balancer_controller_irsa_role.iam_role_arn
}

output "jenkins_irsa_role_arn" {
  description = "IAM role ARN for Jenkins"
  value       = module.jenkins_irsa_role.iam_role_arn
}
