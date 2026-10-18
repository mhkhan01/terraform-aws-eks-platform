# A launch template per node group so IMDSv2 and disk encryption are enforced
# rather than left to the EKS defaults.
resource "aws_launch_template" "node" {
  # checkov:skip=CKV_AWS_341: Hop limit 2 is the EKS-recommended value so containerised agents can reach IMDSv2; tokens are still required.
  for_each = var.node_groups

  name_prefix            = "${var.name}-${each.key}-"
  description            = "EKS managed node group ${each.key} for ${var.name}"
  update_default_version = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only; blocks SSRF-style credential theft via IMDSv1.
    # 2 hops lets containers that are not on the host network still reach IMDS
    # (e.g. the VPC CNI on older images). Pods should use Pod Identity, not node creds.
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = each.value.disk_size_gib
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.node_root_volume_kms_key_arn
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-${each.key}" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name}-${each.key}" })
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  version         = var.kubernetes_version

  ami_type       = each.value.ami_type
  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types
  labels         = each.value.labels

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  dynamic "taint" {
    for_each = each.value.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = var.tags

  lifecycle {
    # Cluster Autoscaler / Karpenter or HPA-driven scaling owns desired_size after creation.
    ignore_changes = [scaling_config[0].desired_size]
  }

  # Networking add-ons must exist before nodes can report Ready, because the
  # cluster was created without the self-managed defaults.
  depends_on = [
    aws_iam_role_policy_attachment.node,
    aws_eks_addon.before_nodes,
  ]
}
