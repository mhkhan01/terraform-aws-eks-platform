locals {
  # Installed before node groups: nodes cannot go Ready without the CNI and kube-proxy.
  addons_before_nodes = ["vpc-cni", "kube-proxy", "eks-pod-identity-agent"]
}

resource "aws_eks_addon" "before_nodes" {
  for_each = toset(local.addons_before_nodes)

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.value
  addon_version               = lookup(var.addon_versions, each.value, null)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

# CoreDNS runs as a Deployment, so it needs schedulable nodes.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  addon_version               = lookup(var.addon_versions, "coredns", null)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = lookup(var.addon_versions, "aws-ebs-csi-driver", null)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Pod Identity binds the controller's service account to the IAM role without an OIDC trust policy.
  pod_identity_association {
    role_arn        = aws_iam_role.ebs_csi.arn
    service_account = "ebs-csi-controller-sa"
  }

  tags = var.tags

  depends_on = [
    aws_eks_node_group.this,
    aws_eks_addon.before_nodes, # pod identity agent must be running
  ]
}
