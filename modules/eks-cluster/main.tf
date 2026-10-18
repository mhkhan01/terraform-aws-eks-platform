data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  log_group_name = "/aws/eks/${var.name}/cluster"
}

# ---------------------------------------------------------------------------
# KMS: one CMK for Kubernetes Secrets envelope encryption and control plane logs.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "kms" {
  # checkov:skip=CKV_AWS_109: Key policy; "*" resource means this key only and account-root admin is the AWS-recommended default.
  # checkov:skip=CKV_AWS_111: Key policy; "*" resource means this key only.
  # checkov:skip=CKV_AWS_356: Key policy; KMS key policies cannot name the key ARN as resource.
  # Key policies must use "*" as the resource; it always means "this key".
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowCloudWatchLogsForThisCluster"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${local.log_group_name}"]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "${var.name} EKS secrets and control plane logs"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = var.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/eks/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}

# Created before the cluster so Terraform owns retention and encryption rather
# than EKS auto-creating an unencrypted, never-expiring group.
resource "aws_cloudwatch_log_group" "cluster" {
  name              = local.log_group_name
  retention_in_days = var.cluster_log_retention_days
  kms_key_id        = aws_kms_key.this.arn
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# Control plane
# ---------------------------------------------------------------------------

resource "aws_eks_cluster" "this" {
  # checkov:skip=CKV_AWS_39: Public endpoint is a toggle (endpoint_public_access) restricted to public_access_cidrs, which rejects 0.0.0.0/0; disable it for production.
  name     = var.name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  enabled_cluster_log_types = var.cluster_log_types

  # We install vpc-cni, kube-proxy and coredns as managed add-ons below, so
  # skip the unmanaged defaults to avoid two owners for the same DaemonSets.
  bootstrap_self_managed_addons = false

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  access_config {
    # API-only: access entries replace the aws-auth ConfigMap, so access is
    # managed by IAM/Terraform and cannot drift via kubectl edits.
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.this.arn
    }
  }

  upgrade_policy {
    support_type = var.support_type
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

# ---------------------------------------------------------------------------
# Access entries: cluster-admin for the listed IAM principals.
# ---------------------------------------------------------------------------

resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"
  tags          = var.tags
}

resource "aws_eks_access_policy_association" "admin" {
  for_each = toset(var.admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admin[each.key].principal_arn
  policy_arn    = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# ---------------------------------------------------------------------------
# IRSA: OIDC provider for workloads that still need web identity federation.
# New workloads in this repo use EKS Pod Identity instead.
# ---------------------------------------------------------------------------

data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
  tags            = var.tags
}
