locals {
  # Cluster name with environment suffix
  cluster_full_name = "${var.cluster_name}-${var.environment}"

  # Common tags
  common_tags = merge(
    {
      "kubernetes.io/cluster/${local.cluster_full_name}" = "owned"
      Project                                             = "fintech-llm-function-calling"
      ManagedBy                                           = "Terraform"
      Environment                                         = var.environment
    },
    var.additional_tags
  )

  # Subnet CIDRs (split VPC into 4 subnets - 2 public, 2 private)
  public_subnet_cidrs  = [cidrsubnet(var.vpc_cidr, 2, 0), cidrsubnet(var.vpc_cidr, 2, 1)]
  private_subnet_cidrs = [cidrsubnet(var.vpc_cidr, 2, 2), cidrsubnet(var.vpc_cidr, 2, 3)]

  # Node labels
  cpu_node_labels = {
    "node-type"         = "cpu"
    "workload"          = "system"
    "library-solution"  = "k8s-training" # Keep same label for K8s manifests compatibility
  }

  gpu_node_labels = {
    "node-type"        = "gpu"
    "workload"         = "ml-training"
    "library-solution" = "k8s-training" # Keep same label for K8s manifests compatibility
  }

  # GPU taints
  gpu_taints = [{
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NO_SCHEDULE"
  }]
}
