# platform-addons

Cluster add-ons installed with the `helm` and `kubernetes` providers, each behind
an `enable_*` toggle with a pinned chart version: Argo CD plus an app-of-apps root
Application (via the `argocd-apps` chart), kube-prometheus-stack, metrics-server and
the AWS Load Balancer Controller (IAM through EKS Pod Identity, policy in
[`policies/`](policies/) (split into two files to stay under the 6,144-character managed-policy limit).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.38 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 3.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.38 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.6 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_pod_identity_association.lbc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_policy.lbc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.lbc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.lbc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.argocd_apps](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.aws_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.kube_prometheus_stack](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.metrics_server](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace_v1.monitoring](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.grafana_admin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [random_password.grafana_admin](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.lbc_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_argocd_apps_chart_version"></a> [argocd\_apps\_chart\_version](#input\_argocd\_apps\_chart\_version) | Pinned argocd-apps Helm chart version. | `string` | `"2.0.6"` | no |
| <a name="input_argocd_chart_version"></a> [argocd\_chart\_version](#input\_argocd\_chart\_version) | Pinned argo-cd Helm chart version from https://argoproj.github.io/argo-helm. | `string` | `"10.10.3"` | no |
| <a name="input_argocd_namespace"></a> [argocd\_namespace](#input\_argocd\_namespace) | Namespace for Argo CD. | `string` | `"argocd"` | no |
| <a name="input_aws_load_balancer_controller_chart_version"></a> [aws\_load\_balancer\_controller\_chart\_version](#input\_aws\_load\_balancer\_controller\_chart\_version) | Pinned aws-load-balancer-controller chart version from https://aws.github.io/eks-charts. | `string` | `"3.5.0"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster the add-ons are installed into. | `string` | n/a | yes |
| <a name="input_enable_argocd"></a> [enable\_argocd](#input\_enable\_argocd) | Install Argo CD. | `bool` | `true` | no |
| <a name="input_enable_aws_load_balancer_controller"></a> [enable\_aws\_load\_balancer\_controller](#input\_enable\_aws\_load\_balancer\_controller) | Install the AWS Load Balancer Controller so Ingress objects with ingressClassName alb create ALBs. | `bool` | `true` | no |
| <a name="input_enable_gitops_bootstrap"></a> [enable\_gitops\_bootstrap](#input\_enable\_gitops\_bootstrap) | Create the root app-of-apps Application through the argocd-apps chart. Requires enable\_argocd. | `bool` | `true` | no |
| <a name="input_enable_kube_prometheus_stack"></a> [enable\_kube\_prometheus\_stack](#input\_enable\_kube\_prometheus\_stack) | Install kube-prometheus-stack (Prometheus, Alertmanager, Grafana). | `bool` | `true` | no |
| <a name="input_enable_metrics_server"></a> [enable\_metrics\_server](#input\_enable\_metrics\_server) | Install metrics-server so HPA and kubectl top work. | `bool` | `true` | no |
| <a name="input_gitops_path"></a> [gitops\_path](#input\_gitops\_path) | Path inside the repo holding the child Application manifests. | `string` | `"gitops/bootstrap"` | no |
| <a name="input_gitops_repo_url"></a> [gitops\_repo\_url](#input\_gitops\_repo\_url) | Git repository Argo CD watches for the root Application. | `string` | `"https://github.com/mhkhan01/terraform-aws-eks-platform.git"` | no |
| <a name="input_gitops_target_revision"></a> [gitops\_target\_revision](#input\_gitops\_target\_revision) | Branch, tag or commit the root Application tracks. | `string` | `"main"` | no |
| <a name="input_kube_prometheus_stack_chart_version"></a> [kube\_prometheus\_stack\_chart\_version](#input\_kube\_prometheus\_stack\_chart\_version) | Pinned kube-prometheus-stack chart version. | `string` | `"92.6.0"` | no |
| <a name="input_metrics_server_chart_version"></a> [metrics\_server\_chart\_version](#input\_metrics\_server\_chart\_version) | Pinned metrics-server chart version. | `string` | `"3.14.0"` | no |
| <a name="input_monitoring_namespace"></a> [monitoring\_namespace](#input\_monitoring\_namespace) | Namespace for the monitoring stack. | `string` | `"monitoring"` | no |
| <a name="input_prometheus_retention"></a> [prometheus\_retention](#input\_prometheus\_retention) | How long Prometheus keeps metrics locally. Short by default because storage is ephemeral in this lab setup. | `string` | `"7d"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags merged onto AWS resources created by this module. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID, passed to the AWS Load Balancer Controller so it does not need IMDS to discover it. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_argocd_initial_admin_password_command"></a> [argocd\_initial\_admin\_password\_command](#output\_argocd\_initial\_admin\_password\_command) | Command that prints the generated Argo CD admin password. |
| <a name="output_argocd_namespace"></a> [argocd\_namespace](#output\_argocd\_namespace) | Namespace Argo CD is installed in, or null when disabled. |
| <a name="output_argocd_port_forward_command"></a> [argocd\_port\_forward\_command](#output\_argocd\_port\_forward\_command) | Command to reach the Argo CD UI on http://localhost:8080 (TLS is not terminated in-cluster). |
| <a name="output_aws_load_balancer_controller_role_arn"></a> [aws\_load\_balancer\_controller\_role\_arn](#output\_aws\_load\_balancer\_controller\_role\_arn) | IAM role ARN used by the AWS Load Balancer Controller through Pod Identity. |
| <a name="output_grafana_admin_password"></a> [grafana\_admin\_password](#output\_grafana\_admin\_password) | Generated Grafana admin password. |
| <a name="output_helm_releases"></a> [helm\_releases](#output\_helm\_releases) | Names and chart versions of the Helm releases installed by this module. |
<!-- END_TF_DOCS -->
