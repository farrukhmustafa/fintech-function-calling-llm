# NOTE: The reference implementation uses modules from ../modules/
# For now, we're setting up the structure. You can either:
# 1. Clone the nebius-solutions-library and use modules from there
# 2. Implement the helm releases directly here
# 3. Create your own modules directory

# Network Operator Module (Nebius Solutions Library)
module "network-operator" {
  depends_on = [
    nebius_mk8s_v1_node_group.cpu-only,
    nebius_mk8s_v1_node_group.gpu,
  ]
  source     = "../modules/network-operator"
  parent_id  = var.parent_id
  cluster_id = nebius_mk8s_v1_cluster.k8s-cluster.id
}

# GPU Operator Module (Nebius Solutions Library)
module "gpu-operator" {
  count = var.gpu_nodes_driverfull_image ? 0 : 1
  depends_on = [
    module.network-operator,
  ]
  source       = "../modules/gpu-operator"
  parent_id    = var.parent_id
  cluster_id   = nebius_mk8s_v1_cluster.k8s-cluster.id
  mig_strategy = var.mig_strategy
}

# Device Plugin Module (for driverfull images - enabled when using pre-installed drivers)
module "device-plugin" {
  count = var.gpu_nodes_driverfull_image ? 1 : 0
  depends_on = [
    module.network-operator,
  ]
  source     = "../modules/device-plugin"
  parent_id  = var.parent_id
  cluster_id = nebius_mk8s_v1_cluster.k8s-cluster.id
}

# Observability Module (Prometheus, Grafana, Loki)
# module "o11y" {
#   source          = "../modules/o11y"
#   parent_id       = var.parent_id
#   tenant_id       = var.tenant_id
#   cluster_id      = nebius_mk8s_v1_cluster.k8s-cluster.id
#   cpu_nodes_count = var.cpu_nodes_count
#   gpu_nodes_count = var.gpu_nodes_count_per_group * var.gpu_node_groups
#
#   o11y = {
#     loki = {
#       enabled            = var.enable_loki
#       replication_factor = var.loki_custom_replication_factor
#       region             = var.region
#     }
#     prometheus = {
#       enabled = var.enable_prometheus
#       pv_size = "25Gi"
#     }
#   }
#   test_mode = var.test_mode
# }

# GPU Operator is now deployed via module above (using Nebius Application Marketplace)

# Nebius GPU Health Checker
# NOTE: Chart is not available by default. You'll need to download the chart from Nebius or use the modules
# Uncomment and configure when chart is available
# resource "helm_release" "nebius_gpu_health_checker" {
#   count = var.gpu_health_checker ? 1 : 0
#
#   depends_on = [
#     nebius_mk8s_v1_node_group.gpu,
#   ]
#
#   name      = "nebius-gpu-health-checker"
#   chart     = "${path.module}/npd-helm/nebius-npd-0.2.0.tgz"
#   namespace = "default"
#
#   set {
#     name  = "hardware.profile"
#     value = local.platform_preset_to_hardware_profile[local.hardware_profile_key]
#   }
# }

