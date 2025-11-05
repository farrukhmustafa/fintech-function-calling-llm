# Training infrastructure for LLM fine-tuning
# Includes KubeRay support and training job templates

# KubeRay for distributed training (optional but impressive for Nebius)
# Based on Nebius Solutions Library pattern
resource "kubernetes_namespace" "kuberay" {
  count = var.enable_kuberay ? 1 : 0

  metadata {
    name = "kuberay"
    labels = {
      "library-solution" = "k8s-training"
    }
  }
  depends_on = [aws_eks_cluster.main]
}

# KubeRay Operator
resource "helm_release" "kuberay_operator" {
  count = var.enable_kuberay ? 1 : 0

  name       = "kuberay-operator"
  repository = "https://ray-project.github.io/kuberay-helm"
  chart      = "kuberay-operator"
  version    = "1.1.1"
  namespace  = kubernetes_namespace.kuberay[0].metadata[0].name

  depends_on = [
    aws_eks_cluster.main,
    helm_release.nvidia_device_plugin,
  ]
}

# Ray Cluster template for distributed training (commented - use when needed)
# Uncomment and configure for distributed training scenarios
# resource "kubernetes_manifest" "ray_cluster" {
#   count = var.enable_kuberay ? 1 : 0
#   
#   manifest = {
#     apiVersion = "ray.io/v1"
#     kind       = "RayCluster"
#     metadata = {
#       name      = "training-cluster"
#       namespace = kubernetes_namespace.kuberay[0].metadata[0].name
#     }
#     spec = {
#       rayVersion = "2.10.0"
#       enableInTreeAutoscaling = true
#       autoscalerOptions = {
#         idleTimeoutSeconds = 60
#       }
#       headGroupSpec = {
#         serviceType = "ClusterIP"
#         rayStartParams = {
#           dashboard-host = "0.0.0.0"
#         }
#         template = {
#           spec = {
#             containers = [{
#               name  = "ray-head"
#               image = "rayproject/ray:2.10.0"
#               resources = {
#                 requests = {
#                   cpu    = "4"
#                   memory = "8Gi"
#                 }
#                 limits = {
#                   cpu    = "8"
#                   memory = "16Gi"
#                 }
#               }
#             }]
#           }
#         }
#       }
#       workerGroupSpecs = [{
#         replicas    = 0  # Autoscale based on workload
#         minReplicas = 0
#         maxReplicas = 4
#         groupName   = "gpu-workers"
#         rayStartParams = {}
#         template = {
#           spec = {
#             nodeSelector = {
#               "library-solution" = "k8s-training"
#             }
#             containers = [{
#               name  = "ray-worker"
#               image = "rayproject/ray:2.10.0"
#               resources = {
#                 requests = {
#                   nvidia.com/gpu = "1"
#                   cpu            = "16"
#                   memory         = "200Gi"
#                 }
#                 limits = {
#                   nvidia.com/gpu = "1"
#                   cpu            = "16"
#                   memory         = "200Gi"
#                 }
#               }
#             }]
#           }
#         }
#       }]
#     }
#   }
#   
#   depends_on = [helm_release.kuberay_operator]
# }

