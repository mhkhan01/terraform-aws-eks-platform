output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate, used by the helm and kubernetes providers."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes version of the control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Security group EKS created for the control plane and managed nodes."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the cluster."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "kms_key_arn" {
  description = "ARN of the CMK used for Secrets encryption and control plane logs."
  value       = aws_kms_key.this.arn
}

output "node_role_arn" {
  description = "IAM role ARN shared by the managed node groups."
  value       = aws_iam_role.node.arn
}

output "node_group_names" {
  description = "Map of node group key to EKS node group name."
  value       = { for k, ng in aws_eks_node_group.this : k => ng.node_group_name }
}

output "kubeconfig_command" {
  description = "Command that writes a kubeconfig entry for this cluster."
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${aws_eks_cluster.this.name}"
}
