module "network" {
  source = "../../modules/network"

  name               = var.name
  cluster_name       = var.name
  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = var.single_nat_gateway
  enable_flow_logs   = var.enable_flow_logs
}

module "eks_cluster" {
  source = "../../modules/eks-cluster"

  name                   = var.name
  kubernetes_version     = var.kubernetes_version
  subnet_ids             = module.network.private_subnet_ids
  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  admin_principal_arns   = var.admin_principal_arns
  node_groups            = var.node_groups
}

module "platform_addons" {
  source = "../../modules/platform-addons"

  cluster_name = module.eks_cluster.cluster_name
  vpc_id       = module.network.vpc_id

  enable_argocd                       = var.enable_argocd
  enable_gitops_bootstrap             = var.enable_argocd
  gitops_repo_url                     = var.gitops_repo_url
  enable_kube_prometheus_stack        = var.enable_kube_prometheus_stack
  enable_metrics_server               = var.enable_metrics_server
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller

  # Helm releases need running nodes and core add-ons; the module output
  # alone is known before nodes exist, so make the ordering explicit.
  depends_on = [module.eks_cluster]
}
