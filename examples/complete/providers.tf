provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "mhkhan01"
      Repository  = "https://github.com/mhkhan01/terraform-aws-eks-platform"
    }
  }
}

# The helm and kubernetes providers are configured from the cluster module's
# outputs. Terraform can plan this in one root because exec auth defers token
# retrieval until the provider is used, but the cluster must exist before the
# add-ons apply: run `terraform apply -target=module.eks_cluster` first on a
# fresh account (see README "Two-stage apply"). In production, split the
# cluster and the add-ons into separate states instead.
provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name, "--region", var.region]
    }
  }
}
