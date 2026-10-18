# eks-cluster

EKS control plane and managed node groups built from raw `aws_*` resources:
KMS envelope encryption for Secrets, control plane logging to an encrypted log
group, API-only access entries, launch templates enforcing IMDSv2 and encrypted
gp3 root volumes, EKS managed add-ons (vpc-cni, kube-proxy, coredns,
eks-pod-identity-agent, aws-ebs-csi-driver with Pod Identity) and an IRSA OIDC provider.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eks_access_entry.admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_addon.before_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_addon.coredns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_addon.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_launch_template.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.cluster_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.node_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.pod_identity_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [tls_certificate.oidc](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addon_versions"></a> [addon\_versions](#input\_addon\_versions) | Optional pinned versions for EKS managed add-ons, keyed by add-on name. Omitted add-ons use the default version for the cluster's Kubernetes version. | `map(string)` | `{}` | no |
| <a name="input_admin_principal_arns"></a> [admin\_principal\_arns](#input\_admin\_principal\_arns) | IAM role/user ARNs granted cluster-admin through EKS access entries. Empty means only the cluster creator (bootstrap) has access. | `list(string)` | `[]` | no |
| <a name="input_bootstrap_cluster_creator_admin_permissions"></a> [bootstrap\_cluster\_creator\_admin\_permissions](#input\_bootstrap\_cluster\_creator\_admin\_permissions) | Give the identity running Terraform cluster-admin automatically. Disable once admin\_principal\_arns covers your operators. | `bool` | `true` | no |
| <a name="input_cluster_log_retention_days"></a> [cluster\_log\_retention\_days](#input\_cluster\_log\_retention\_days) | Retention for the control plane CloudWatch log group. | `number` | `365` | no |
| <a name="input_cluster_log_types"></a> [cluster\_log\_types](#input\_cluster\_log\_types) | Control plane log types shipped to CloudWatch. | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator",<br/>  "controllerManager",<br/>  "scheduler"<br/>]</pre> | no |
| <a name="input_endpoint_private_access"></a> [endpoint\_private\_access](#input\_endpoint\_private\_access) | Expose the Kubernetes API on a private endpoint inside the VPC. Keeps node-to-control-plane traffic off the internet. | `bool` | `true` | no |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | Expose the Kubernetes API on a public endpoint. Convenient for a lab; restrict with public\_access\_cidrs or disable and use a VPN/bastion in production. | `bool` | `true` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes minor version for the control plane and managed node groups. | `string` | `"1.33"` | no |
| <a name="input_name"></a> [name](#input\_name) | EKS cluster name, also used as the prefix for IAM roles, KMS aliases and node groups. | `string` | n/a | yes |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Managed node groups keyed by name. All nodes run in the private subnets with IMDSv2 enforced and an encrypted gp3 root volume. | <pre>map(object({<br/>    instance_types = optional(list(string), ["t3.medium"])<br/>    capacity_type  = optional(string, "ON_DEMAND")<br/>    ami_type       = optional(string, "AL2023_x86_64_STANDARD")<br/>    min_size       = optional(number, 1)<br/>    max_size       = optional(number, 3)<br/>    desired_size   = optional(number, 2)<br/>    disk_size_gib  = optional(number, 30)<br/>    labels         = optional(map(string), {})<br/>    taints = optional(list(object({<br/>      key    = string<br/>      value  = optional(string)<br/>      effect = string<br/>    })), [])<br/>  }))</pre> | <pre>{<br/>  "default": {}<br/>}</pre> | no |
| <a name="input_node_root_volume_kms_key_arn"></a> [node\_root\_volume\_kms\_key\_arn](#input\_node\_root\_volume\_kms\_key\_arn) | Optional CMK for node root volumes. Null uses the account's default aws/ebs key, which avoids extra key-policy grants for the Auto Scaling service-linked role. | `string` | `null` | no |
| <a name="input_public_access_cidrs"></a> [public\_access\_cidrs](#input\_public\_access\_cidrs) | CIDRs allowed to reach the public API endpoint. Set this to your own IP/32. 0.0.0.0/0 is rejected. | `list(string)` | <pre>[<br/>  "203.0.113.10/32"<br/>]</pre> | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Private subnet IDs for the control plane ENIs and the managed node groups. Use at least two AZs. | `list(string)` | n/a | yes |
| <a name="input_support_type"></a> [support\_type](#input\_support\_type) | EKS upgrade policy. STANDARD avoids the extended-support surcharge by forcing upgrades at end of standard support. | `string` | `"STANDARD"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags merged onto every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the EKS cluster. |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64-encoded cluster CA certificate, used by the helm and kubernetes providers. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Kubernetes API server endpoint. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the EKS cluster. |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Security group EKS created for the control plane and managed nodes. |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | Kubernetes version of the control plane. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the CMK used for Secrets encryption and control plane logs. |
| <a name="output_kubeconfig_command"></a> [kubeconfig\_command](#output\_kubeconfig\_command) | Command that writes a kubeconfig entry for this cluster. |
| <a name="output_node_group_names"></a> [node\_group\_names](#output\_node\_group\_names) | Map of node group key to EKS node group name. |
| <a name="output_node_role_arn"></a> [node\_role\_arn](#output\_node\_role\_arn) | IAM role ARN shared by the managed node groups. |
| <a name="output_oidc_issuer_url"></a> [oidc\_issuer\_url](#output\_oidc\_issuer\_url) | OIDC issuer URL of the cluster. |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the IAM OIDC provider for IRSA. |
<!-- END_TF_DOCS -->
