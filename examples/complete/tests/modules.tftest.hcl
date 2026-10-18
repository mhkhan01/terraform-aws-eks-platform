# Every provider is mocked: these tests need no AWS credentials, cluster or network.
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "eu-west-2"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
}

mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = {
      certificates = [{ sha1_fingerprint = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280" }]
    }
  }
}

mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "random" {}

# Unit tests: each run plans one module directly so assertions can reach its resources.

# --- modules/network ---------------------------------------------------------

run "network_single_nat_and_elb_tags" {
  command = plan

  module {
    source = "../../modules/network"
  }

  variables {
    name         = "unit"
    cluster_name = "unit"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway=true should create exactly one NAT gateway."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.tags["kubernetes.io/role/elb"] == "1"])
    error_message = "Public subnets need the kubernetes.io/role/elb tag for internet-facing ALBs."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.private : s.tags["kubernetes.io/role/internal-elb"] == "1" && s.tags["kubernetes.io/cluster/unit"] == "shared"])
    error_message = "Private subnets need the internal-elb and cluster discovery tags."
  }

  assert {
    condition     = [for s in aws_subnet.private : s.availability_zone] == ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
    error_message = "Subnets should spread across the three mocked AZs."
  }

  assert {
    condition     = length(aws_flow_log.this) == 1 && aws_cloudwatch_log_group.flow_logs[0].retention_in_days == 365
    error_message = "Flow logs should be on by default with one-year retention."
  }
}

run "network_nat_per_az_when_not_single" {
  command = plan

  module {
    source = "../../modules/network"
  }

  variables {
    name               = "unit"
    cluster_name       = "unit"
    single_nat_gateway = false
    enable_flow_logs   = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "single_nat_gateway=false should create one NAT gateway per AZ."
  }

  assert {
    condition     = length(aws_flow_log.this) == 0 && length(aws_kms_key.flow_logs) == 0
    error_message = "enable_flow_logs=false should skip the flow log, its key and log group."
  }
}

# --- modules/eks-cluster -----------------------------------------------------

run "eks_cluster_node_group_security_and_access" {
  command = plan

  module {
    source = "../../modules/eks-cluster"
  }

  variables {
    name                 = "unit"
    subnet_ids           = ["subnet-aaaa", "subnet-bbbb", "subnet-cccc"]
    admin_principal_arns = ["arn:aws:iam::123456789012:role/PlatformAdmin"]
    node_groups = {
      spot = {
        instance_types = ["t3.large", "m5.large"]
        capacity_type  = "SPOT"
        min_size       = 1
        max_size       = 4
        desired_size   = 2
        labels         = { "node-role" = "workload" }
        taints         = [{ key = "capacity", value = "spot", effect = "NO_SCHEDULE" }]
      }
    }
  }

  # Give the cluster a known OIDC issuer at plan time so the IRSA provider
  # URL can be asserted. (The tls_certificate read itself is deferred to apply
  # because it depends on a resource being created.)
  override_resource {
    target          = aws_eks_cluster.this
    override_during = plan
    values = {
      name                  = "unit"
      certificate_authority = [{ data = "TU9DSy1DQQ==" }]
      identity = [{
        oidc = [{ issuer = "https://oidc.eks.eu-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE" }]
      }]
    }
  }


  # Node group
  assert {
    condition     = aws_eks_node_group.this["spot"].capacity_type == "SPOT"
    error_message = "capacity_type should pass through to the node group."
  }

  assert {
    condition     = aws_eks_node_group.this["spot"].scaling_config[0].min_size == 1 && aws_eks_node_group.this["spot"].scaling_config[0].max_size == 4 && aws_eks_node_group.this["spot"].scaling_config[0].desired_size == 2
    error_message = "Scaling config should match the node group map."
  }

  assert {
    condition     = tolist(aws_eks_node_group.this["spot"].instance_types) == tolist(["t3.large", "m5.large"]) && aws_eks_node_group.this["spot"].labels["node-role"] == "workload"
    error_message = "Instance types and labels should pass through."
  }

  assert {
    condition     = length(aws_eks_node_group.this["spot"].taint) == 1 && one(aws_eks_node_group.this["spot"].taint).effect == "NO_SCHEDULE"
    error_message = "Taints should render as taint blocks."
  }

  assert {
    condition     = toset(aws_eks_node_group.this["spot"].subnet_ids) == toset(["subnet-aaaa", "subnet-bbbb", "subnet-cccc"])
    error_message = "Nodes should run in the supplied private subnets."
  }

  # Launch template: IMDSv2 and encrypted gp3
  assert {
    condition     = aws_launch_template.node["spot"].metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be enforced (http_tokens = required)."
  }

  assert {
    condition     = aws_launch_template.node["spot"].metadata_options[0].http_put_response_hop_limit == 2
    error_message = "IMDS hop limit should be 2."
  }

  assert {
    condition     = aws_launch_template.node["spot"].block_device_mappings[0].ebs[0].encrypted == "true" && aws_launch_template.node["spot"].block_device_mappings[0].ebs[0].volume_type == "gp3"
    error_message = "Root volume must be encrypted gp3."
  }

  # Control plane
  assert {
    condition     = aws_eks_cluster.this.version == "1.33"
    error_message = "Default Kubernetes version should be 1.33."
  }

  assert {
    condition     = toset(aws_eks_cluster.this.encryption_config[0].resources) == toset(["secrets"])
    error_message = "Secrets envelope encryption must be configured."
  }

  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "The cluster CMK must rotate."
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API"
    error_message = "Authentication mode should be API (access entries only)."
  }

  assert {
    condition     = length(aws_eks_cluster.this.enabled_cluster_log_types) == 5
    error_message = "All control plane log types should be enabled by default."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_private_access == true && toset(aws_eks_cluster.this.vpc_config[0].public_access_cidrs) == toset(["203.0.113.10/32"])
    error_message = "Private endpoint should be on and the public endpoint restricted."
  }

  # Access, IAM, add-ons
  assert {
    condition     = length(aws_eks_access_entry.admin) == 1 && aws_eks_access_policy_association.admin["arn:aws:iam::123456789012:role/PlatformAdmin"].policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    error_message = "Each admin principal should get an access entry with the cluster admin policy."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.node) == 4 && aws_iam_role_policy_attachment.node["ssm"].policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "Node role needs the three EKS policies plus SSM."
  }

  assert {
    condition     = toset(keys(aws_eks_addon.before_nodes)) == toset(["vpc-cni", "kube-proxy", "eks-pod-identity-agent"]) && aws_eks_addon.coredns.addon_name == "coredns"
    error_message = "Core managed add-ons should be planned."
  }

  assert {
    condition     = one(aws_eks_addon.ebs_csi.pod_identity_association).service_account == "ebs-csi-controller-sa"
    error_message = "EBS CSI driver should get IAM through a Pod Identity association."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.this.client_id_list == toset(["sts.amazonaws.com"]) && aws_iam_openid_connect_provider.this.url == "https://oidc.eks.eu-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
    error_message = "IRSA OIDC provider should trust STS and use the cluster issuer URL."
  }
}

run "eks_cluster_rejects_invalid_capacity_type" {
  command = plan

  module {
    source = "../../modules/eks-cluster"
  }

  variables {
    name       = "unit"
    subnet_ids = ["subnet-aaaa", "subnet-bbbb"]
    node_groups = {
      bad = { capacity_type = "FOO" }
    }
  }

  expect_failures = [var.node_groups]
}

run "eks_cluster_rejects_open_public_endpoint" {
  command = plan

  module {
    source = "../../modules/eks-cluster"
  }

  variables {
    name                = "unit"
    subnet_ids          = ["subnet-aaaa", "subnet-bbbb"]
    public_access_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.public_access_cidrs]
}

# --- modules/platform-addons -------------------------------------------------

run "addons_all_enabled" {
  command = plan

  module {
    source = "../../modules/platform-addons"
  }

  variables {
    cluster_name = "unit"
    vpc_id       = "vpc-0123456789abcdef0"
  }

  assert {
    condition = (
      length(helm_release.argocd) == 1 &&
      length(helm_release.argocd_apps) == 1 &&
      length(helm_release.kube_prometheus_stack) == 1 &&
      length(helm_release.metrics_server) == 1 &&
      length(helm_release.aws_load_balancer_controller) == 1
    )
    error_message = "Every add-on should be planned when all toggles are on."
  }

  assert {
    condition     = helm_release.argocd[0].repository == "https://argoproj.github.io/argo-helm" && helm_release.argocd[0].chart == "argo-cd"
    error_message = "Argo CD should come from the official argo-helm repository."
  }

  assert {
    condition     = yamldecode(helm_release.argocd_apps[0].values[0]).applications.root.source.path == "gitops/bootstrap"
    error_message = "Root Application should point at the gitops/bootstrap folder."
  }

  assert {
    condition     = aws_eks_pod_identity_association.lbc[0].service_account == "aws-load-balancer-controller" && aws_eks_pod_identity_association.lbc[0].namespace == "kube-system"
    error_message = "Load Balancer Controller should get IAM via Pod Identity."
  }

  assert {
    condition     = alltrue([for p in aws_iam_policy.lbc : jsondecode(p.policy).Version == "2012-10-17"]) && length(aws_iam_policy.lbc) == 2
    error_message = "Load Balancer Controller policy should load from the module's JSON file."
  }
}

run "addons_toggles_change_release_counts" {
  command = plan

  module {
    source = "../../modules/platform-addons"
  }

  variables {
    cluster_name                        = "unit"
    vpc_id                              = "vpc-0123456789abcdef0"
    enable_argocd                       = false
    enable_kube_prometheus_stack        = false
    enable_aws_load_balancer_controller = false
  }

  assert {
    condition     = length(helm_release.argocd) == 0 && length(helm_release.argocd_apps) == 0
    error_message = "Disabling Argo CD must also skip the GitOps bootstrap."
  }

  assert {
    condition     = length(helm_release.kube_prometheus_stack) == 0 && length(kubernetes_secret_v1.grafana_admin) == 0
    error_message = "Disabling the monitoring stack should skip Grafana's secret too."
  }

  assert {
    condition     = length(helm_release.aws_load_balancer_controller) == 0 && length(aws_iam_role.lbc) == 0
    error_message = "Disabling the Load Balancer Controller should skip its IAM role."
  }

  assert {
    condition     = length(helm_release.metrics_server) == 1
    error_message = "metrics-server should stay installed when only other toggles are off."
  }
}
