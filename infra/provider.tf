terraform {
  required_version = ">= 1.5"

  required_providers {
    nebius = {
      source = "terraform-provider.storage.eu-north1.nebius.cloud/nebius/nebius"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "<3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "nebius" {
  domain = "api.eu.nebius.cloud:443"
  # Token is automatically read from NEBIUS_IAM_TOKEN environment variable (recommended)
  # Alternatively, uncomment below to use token from variable:
  # token = var.iam_token
}

provider "helm" {
  kubernetes {
    host                   = nebius_mk8s_v1_cluster.k8s-cluster.status.control_plane.endpoints.public_endpoint
    cluster_ca_certificate = nebius_mk8s_v1_cluster.k8s-cluster.status.control_plane.auth.cluster_ca_certificate
    token                  = var.iam_token
  }
}

provider "kubernetes" {
  host                   = nebius_mk8s_v1_cluster.k8s-cluster.status.control_plane.endpoints.public_endpoint
  cluster_ca_certificate = nebius_mk8s_v1_cluster.k8s-cluster.status.control_plane.auth.cluster_ca_certificate
  token                  = var.iam_token
}

