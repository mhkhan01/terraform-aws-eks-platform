variable "name" {
  description = "Name prefix applied to every resource in this module."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "name must be 3-32 characters, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "cluster_name" {
  description = "EKS cluster name used for the kubernetes.io/cluster/<name> subnet tag so the AWS Load Balancer Controller can discover subnets."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC. A /16 gives three /20 private subnets (4,091 usable IPs each) for pod IPs from the VPC CNI."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "vpc_cidr must be a valid IPv4 CIDR no smaller than /20."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 (EKS requires subnets in at least two AZs)."
  }
}

variable "private_subnet_newbits" {
  description = "Bits added to the VPC prefix for private (node and pod) subnets. 4 on a /16 gives /20s."
  type        = number
  default     = 4
}

variable "public_subnet_newbits" {
  description = "Bits added to the VPC prefix for public (load balancer and NAT) subnets. 8 on a /16 gives /24s."
  type        = number
  default     = 8
}

variable "public_subnet_offset" {
  description = "netnum offset for public subnets so they never overlap the private range. With the defaults, public subnets start at x.x.48.0/24, after the three /20s."
  type        = number
  default     = 48
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ. Saves roughly two NAT gateway charges a month at the cost of AZ-level egress resilience. Good for labs; set false for production."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to an encrypted CloudWatch log group. Costs CloudWatch ingestion per GB, so it is a toggle."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention for the flow log group in days."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_logs_retention_days)
    error_message = "flow_logs_retention_days must be a value CloudWatch Logs accepts."
  }
}

variable "tags" {
  description = "Tags merged onto every resource."
  type        = map(string)
  default     = {}
}
