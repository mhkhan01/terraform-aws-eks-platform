output "argocd_namespace" {
  description = "Namespace Argo CD is installed in, or null when disabled."
  value       = var.enable_argocd ? helm_release.argocd[0].namespace : null
}

output "argocd_port_forward_command" {
  description = "Command to reach the Argo CD UI on http://localhost:8080 (TLS is not terminated in-cluster)."
  value       = var.enable_argocd ? "kubectl -n ${var.argocd_namespace} port-forward svc/argocd-server 8080:80" : null
}

output "argocd_initial_admin_password_command" {
  description = "Command that prints the generated Argo CD admin password."
  value       = var.enable_argocd ? "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" : null
}

output "grafana_admin_password" {
  description = "Generated Grafana admin password."
  value       = var.enable_kube_prometheus_stack ? random_password.grafana_admin[0].result : null
  sensitive   = true
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller through Pod Identity."
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.lbc[0].arn : null
}

output "helm_releases" {
  description = "Names and chart versions of the Helm releases installed by this module."
  value = {
    for r in concat(
      helm_release.argocd,
      helm_release.argocd_apps,
      helm_release.metrics_server,
      helm_release.kube_prometheus_stack,
      helm_release.aws_load_balancer_controller,
    ) : r.name => r.version
  }
}
