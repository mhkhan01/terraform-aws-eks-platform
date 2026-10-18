data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  bootstrap_gitops = var.enable_argocd && var.enable_gitops_bootstrap
}

# ---------------------------------------------------------------------------
# Argo CD
# ---------------------------------------------------------------------------

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true
  atomic           = true
  timeout          = 600

  values = [yamlencode({
    configs = {
      params = {
        # TLS is terminated at the ALB/port-forward in this setup.
        "server.insecure" = true
      }
    }
    server = {
      service = { type = "ClusterIP" } # reach it with kubectl port-forward, no public LB by default
    }
    dex = { enabled = false } # SSO is out of scope; avoids an extra Deployment
  })]
}

# App of apps: one root Application that syncs every child Application under gitops_path.
resource "helm_release" "argocd_apps" {
  count = local.bootstrap_gitops ? 1 : 0

  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = var.argocd_namespace
  atomic     = true

  values = [yamlencode({
    applications = {
      root = {
        namespace  = var.argocd_namespace
        project    = "default"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.gitops_target_revision
          path           = var.gitops_path
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = var.argocd_namespace
        }
        syncPolicy = {
          automated   = { prune = true, selfHeal = true }
          syncOptions = ["CreateNamespace=true"]
        }
      }
    }
  })]

  # The Application CRD is installed by the argo-cd chart.
  depends_on = [helm_release.argocd]
}

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------

resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version
  namespace  = "kube-system"
  atomic     = true
}

resource "kubernetes_namespace_v1" "monitoring" {
  count = var.enable_kube_prometheus_stack ? 1 : 0

  metadata {
    name = var.monitoring_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Generated admin password instead of the chart's well-known default.
resource "random_password" "grafana_admin" {
  count = var.enable_kube_prometheus_stack ? 1 : 0

  length  = 24
  special = false
}

resource "kubernetes_secret_v1" "grafana_admin" {
  count = var.enable_kube_prometheus_stack ? 1 : 0

  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }

  data = {
    admin-user     = "admin"
    admin-password = random_password.grafana_admin[0].result
  }
}

resource "helm_release" "kube_prometheus_stack" {
  count = var.enable_kube_prometheus_stack ? 1 : 0

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version
  namespace  = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  atomic     = true
  timeout    = 900

  values = [yamlencode({
    grafana = {
      admin = {
        existingSecret = kubernetes_secret_v1.grafana_admin[0].metadata[0].name
        userKey        = "admin-user"
        passwordKey    = "admin-password"
      }
    }
    prometheus = {
      prometheusSpec = {
        retention = var.prometheus_retention
        # Pick up ServiceMonitors from every namespace, not only this release's.
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
      }
    }
    # EKS does not expose these control plane endpoints; scraping them only produces alerts.
    kubeControllerManager = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeEtcd              = { enabled = false }
  })]
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller (IAM via EKS Pod Identity)
# ---------------------------------------------------------------------------

locals {
  lbc_service_account = "aws-load-balancer-controller"
}

data "aws_iam_policy_document" "lbc_assume" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "lbc" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name               = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume[0].json
  tags               = var.tags
}

# Kept as JSON so it can be diffed against the upstream policy on each controller upgrade.
# Split in two because a managed policy is capped at 6,144 characters (tflint aws_iam_policy_too_long_policy).
locals {
  lbc_policies = var.enable_aws_load_balancer_controller ? {
    discovery-sg = "aws-load-balancer-controller-discovery-sg.json"
    elb          = "aws-load-balancer-controller-elb.json"
  } : {}
}

resource "aws_iam_policy" "lbc" {
  for_each = local.lbc_policies

  name        = "${var.cluster_name}-aws-load-balancer-controller-${each.key}"
  description = "Least-privilege policy (${each.key}) for the AWS Load Balancer Controller on ${var.cluster_name}"
  policy      = jsonencode(jsondecode(file("${path.module}/policies/${each.value}")))
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "lbc" {
  for_each = aws_iam_policy.lbc

  role       = aws_iam_role.lbc[0].name
  policy_arn = each.value.arn
}

resource "aws_eks_pod_identity_association" "lbc" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = local.lbc_service_account
  role_arn        = aws_iam_role.lbc[0].arn
  tags            = var.tags
}

resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_chart_version
  namespace  = "kube-system"
  atomic     = true

  values = [yamlencode({
    clusterName = var.cluster_name
    region      = data.aws_region.current.region
    vpcId       = var.vpc_id
    serviceAccount = {
      create = true
      name   = local.lbc_service_account
    }
  })]

  # Credentials must be resolvable before the controller pods start.
  depends_on = [
    aws_eks_pod_identity_association.lbc,
    aws_iam_role_policy_attachment.lbc,
  ]
}
