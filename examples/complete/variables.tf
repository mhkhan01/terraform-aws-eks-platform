variable "name" {
  description = "Name of the platform; used as the cluster name and resource prefix."
  type        = string
  default     = "eks-platform"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "name must be 3-32 characters, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment label applied through default_tags."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "Share one NAT gateway across AZs to save cost (lab default)."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.33"
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API publicly (restricted by public_access_cidrs)."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Replace with your IP/32."
  type        = list(string)
  default     = ["203.0.113.10/32"]
}

variable "admin_principal_arns" {
  description = "IAM principals granted cluster-admin via access entries."
  type        = list(string)
  default     = []
}

variable "node_groups" {
  description = "Managed node groups; see modules/eks-cluster for the full object shape."
  type        = any
  default = {
    system = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      labels         = { "node-role" = "system" }
    }
    spot = {
      instance_types = ["t3.large", "t3a.large", "m5.large"]
      capacity_type  = "SPOT"
      min_size       = 0
      max_size       = 3
      desired_size   = 1
      labels         = { "node-role" = "workload" }
      taints = [{
        key    = "capacity"
        value  = "spot"
        effect = "NO_SCHEDULE"
      }]
    }
  }
}

variable "enable_argocd" {
  description = "Install Argo CD and bootstrap the root Application."
  type        = bool
  default     = true
}

variable "enable_kube_prometheus_stack" {
  description = "Install kube-prometheus-stack."
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Install metrics-server."
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Install the AWS Load Balancer Controller."
  type        = bool
  default     = true
}

variable "gitops_repo_url" {
  description = "Repository Argo CD syncs from."
  type        = string
  default     = "https://github.com/mhkhan01/terraform-aws-eks-platform.git"
}
