locals {
  # Cluster name with environment suffix
  cluster_full_name = "${var.cluster_name}-${var.environment}"

  # Availability zones (use from variable or auto-detect)
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)

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

  # Node labels (compatible with existing Kubernetes manifests)
  cpu_node_labels = {
    "node-type"        = "cpu"
    "workload"         = "system"
    "library-solution" = "k8s-training" # Keep same label for K8s manifests compatibility
  }

  gpu_node_labels = {
    "node-type"        = "gpu"
    "workload"         = "ml-training"
    "library-solution" = "k8s-training" # Keep same label for K8s manifests compatibility
  }
}
