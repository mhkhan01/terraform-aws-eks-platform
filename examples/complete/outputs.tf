output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDRs."
  value       = module.network.private_subnet_cidrs
}

output "public_subnet_cidrs" {
  description = "Public subnet CIDRs."
  value       = module.network.public_subnet_cidrs
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks_cluster.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Run this to point kubectl at the cluster."
  value       = module.eks_cluster.kubeconfig_command
}

output "argocd_port_forward_command" {
  description = "Port-forward to the Argo CD UI."
  value       = module.platform_addons.argocd_port_forward_command
}

output "argocd_initial_admin_password_command" {
  description = "Prints the Argo CD initial admin password."
  value       = module.platform_addons.argocd_initial_admin_password_command
}

output "helm_releases" {
  description = "Installed Helm releases and chart versions."
  value       = module.platform_addons.helm_releases
}

output "grafana_admin_password" {
  description = "Generated Grafana admin password (user admin)."
  value       = module.platform_addons.grafana_admin_password
  sensitive   = true
}
