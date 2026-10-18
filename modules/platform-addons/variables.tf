variable "cluster_name" {
  description = "Name of the EKS cluster the add-ons are installed into."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID, passed to the AWS Load Balancer Controller so it does not need IMDS to discover it."
  type        = string
}

variable "tags" {
  description = "Tags merged onto AWS resources created by this module."
  type        = map(string)
  default     = {}
}

# --- Argo CD -----------------------------------------------------------------

variable "enable_argocd" {
  description = "Install Argo CD."
  type        = bool
  default     = true
}

variable "argocd_chart_version" {
  description = "Pinned argo-cd Helm chart version from https://argoproj.github.io/argo-helm."
  type        = string
  default     = "10.10.3"
}

variable "argocd_namespace" {
  description = "Namespace for Argo CD."
  type        = string
  default     = "argocd"
}

variable "enable_gitops_bootstrap" {
  description = "Create the root app-of-apps Application through the argocd-apps chart. Requires enable_argocd."
  type        = bool
  default     = true
}

variable "argocd_apps_chart_version" {
  description = "Pinned argocd-apps Helm chart version."
  type        = string
  default     = "2.0.6"
}

variable "gitops_repo_url" {
  description = "Git repository Argo CD watches for the root Application."
  type        = string
  default     = "https://github.com/mhkhan01/terraform-aws-eks-platform.git"

  validation {
    condition     = can(regex("^(https://|git@)", var.gitops_repo_url))
    error_message = "gitops_repo_url must be an https:// or git@ URL."
  }
}

variable "gitops_target_revision" {
  description = "Branch, tag or commit the root Application tracks."
  type        = string
  default     = "main"
}

variable "gitops_path" {
  description = "Path inside the repo holding the child Application manifests."
  type        = string
  default     = "gitops/bootstrap"
}

# --- Observability -----------------------------------------------------------

variable "enable_kube_prometheus_stack" {
  description = "Install kube-prometheus-stack (Prometheus, Alertmanager, Grafana)."
  type        = bool
  default     = true
}

variable "kube_prometheus_stack_chart_version" {
  description = "Pinned kube-prometheus-stack chart version."
  type        = string
  default     = "92.6.0"
}

variable "monitoring_namespace" {
  description = "Namespace for the monitoring stack."
  type        = string
  default     = "monitoring"
}

variable "prometheus_retention" {
  description = "How long Prometheus keeps metrics locally. Short by default because storage is ephemeral in this lab setup."
  type        = string
  default     = "7d"

  validation {
    condition     = can(regex("^[0-9]+(h|d|w)$", var.prometheus_retention))
    error_message = "prometheus_retention must look like 12h, 7d or 2w."
  }
}

variable "enable_metrics_server" {
  description = "Install metrics-server so HPA and kubectl top work."
  type        = bool
  default     = true
}

variable "metrics_server_chart_version" {
  description = "Pinned metrics-server chart version."
  type        = string
  default     = "3.14.0"
}

# --- AWS Load Balancer Controller --------------------------------------------

variable "enable_aws_load_balancer_controller" {
  description = "Install the AWS Load Balancer Controller so Ingress objects with ingressClassName alb create ALBs."
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_chart_version" {
  description = "Pinned aws-load-balancer-controller chart version from https://aws.github.io/eks-charts."
  type        = string
  default     = "3.5.0"
}
