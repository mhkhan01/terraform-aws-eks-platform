variable "name" {
  description = "EKS cluster name, also used as the prefix for IAM roles, KMS aliases and node groups."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "name must be 3-32 characters, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the control plane and managed node groups."
  type        = string
  default     = "1.33"

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "kubernetes_version must look like 1.33."
  }
}

variable "subnet_ids" {
  description = "Private subnet IDs for the control plane ENIs and the managed node groups. Use at least two AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS needs subnets in at least two Availability Zones."
  }
}

variable "endpoint_private_access" {
  description = "Expose the Kubernetes API on a private endpoint inside the VPC. Keeps node-to-control-plane traffic off the internet."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API on a public endpoint. Convenient for a lab; restrict with public_access_cidrs or disable and use a VPN/bastion in production."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Set this to your own IP/32. 0.0.0.0/0 is rejected."
  type        = list(string)
  default     = ["203.0.113.10/32"] # RFC 5737 documentation range, replace with your IP.

  validation {
    condition     = alltrue([for c in var.public_access_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "public_access_cidrs must be valid IPv4 CIDRs and must not include 0.0.0.0/0."
  }
}

variable "cluster_log_types" {
  description = "Control plane log types shipped to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  validation {
    condition     = alltrue([for t in var.cluster_log_types : contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], t)])
    error_message = "cluster_log_types may only contain api, audit, authenticator, controllerManager or scheduler."
  }
}

variable "cluster_log_retention_days" {
  description = "Retention for the control plane CloudWatch log group."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cluster_log_retention_days)
    error_message = "cluster_log_retention_days must be a value CloudWatch Logs accepts."
  }
}

variable "support_type" {
  description = "EKS upgrade policy. STANDARD avoids the extended-support surcharge by forcing upgrades at end of standard support."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXTENDED"], var.support_type)
    error_message = "support_type must be STANDARD or EXTENDED."
  }
}

variable "admin_principal_arns" {
  description = "IAM role/user ARNs granted cluster-admin through EKS access entries. Empty means only the cluster creator (bootstrap) has access."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for a in var.admin_principal_arns : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:(role|user)/.+$", a))])
    error_message = "admin_principal_arns must be IAM role or user ARNs."
  }
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Give the identity running Terraform cluster-admin automatically. Disable once admin_principal_arns covers your operators."
  type        = bool
  default     = true
}

variable "node_groups" {
  description = "Managed node groups keyed by name. All nodes run in the private subnets with IMDSv2 enforced and an encrypted gp3 root volume."
  type = map(object({
    instance_types = optional(list(string), ["t3.medium"])
    capacity_type  = optional(string, "ON_DEMAND")
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")
    min_size       = optional(number, 1)
    max_size       = optional(number, 3)
    desired_size   = optional(number, 2)
    disk_size_gib  = optional(number, 30)
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))
  default = {
    default = {}
  }

  validation {
    condition     = alltrue([for ng in values(var.node_groups) : contains(["ON_DEMAND", "SPOT"], ng.capacity_type)])
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }

  validation {
    condition     = alltrue([for ng in values(var.node_groups) : ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size && ng.max_size >= 1])
    error_message = "Each node group needs min_size <= desired_size <= max_size and max_size >= 1."
  }

  validation {
    condition = alltrue(flatten([for ng in values(var.node_groups) : [
      for t in ng.taints : contains(["NO_SCHEDULE", "NO_EXECUTE", "PREFER_NO_SCHEDULE"], t.effect)
    ]]))
    error_message = "Taint effect must be NO_SCHEDULE, NO_EXECUTE or PREFER_NO_SCHEDULE."
  }
}

variable "node_root_volume_kms_key_arn" {
  description = "Optional CMK for node root volumes. Null uses the account's default aws/ebs key, which avoids extra key-policy grants for the Auto Scaling service-linked role."
  type        = string
  default     = null
}

variable "addon_versions" {
  description = "Optional pinned versions for EKS managed add-ons, keyed by add-on name. Omitted add-ons use the default version for the cluster's Kubernetes version."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags merged onto every resource."
  type        = map(string)
  default     = {}
}
