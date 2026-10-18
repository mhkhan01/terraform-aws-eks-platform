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

# Full example plan: network + cluster + add-ons wired together.

run "default_plan_wires_network_cluster_and_addons" {
  command = plan

  assert {
    condition     = output.private_subnet_cidrs == ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
    error_message = "Private subnets should be three /20s carved from the start of the VPC CIDR."
  }

  assert {
    condition     = output.public_subnet_cidrs == ["10.0.48.0/24", "10.0.49.0/24", "10.0.50.0/24"]
    error_message = "Public subnets should be three /24s placed after the private range."
  }

  assert {
    condition     = output.kubeconfig_command == "aws eks update-kubeconfig --region eu-west-2 --name eks-platform"
    error_message = "kubeconfig_command should target the cluster in eu-west-2."
  }

  assert {
    condition     = length(output.helm_releases) == 5
    error_message = "All five Helm releases should be planned by default."
  }

  assert {
    condition     = output.helm_releases["argocd"] == "10.10.3"
    error_message = "Argo CD chart version should be pinned."
  }
}

run "all_addons_disabled_plans_no_helm_releases" {
  command = plan

  variables {
    enable_argocd                       = false
    enable_kube_prometheus_stack        = false
    enable_metrics_server               = false
    enable_aws_load_balancer_controller = false
  }

  assert {
    condition     = length(output.helm_releases) == 0
    error_message = "Disabling every toggle should leave no Helm releases."
  }

  assert {
    condition     = output.argocd_port_forward_command == null
    error_message = "Argo CD outputs should be null when Argo CD is disabled."
  }
}

run "environment_validation_rejects_unknown_value" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}
