# Inference deployment for optimized model serving
# Supports vLLM for high-throughput inference with 16-32 concurrent requests

resource "kubernetes_namespace" "inference" {
  metadata {
    name = "inference"
    labels = {
      "library-solution" = "k8s-training"
    }
  }
  depends_on = [nebius_mk8s_v1_cluster.k8s-cluster]
}

# vLLM Deployment for optimized inference
# vLLM provides PagedAttention and continuous batching for high throughput
# NOTE: Starts with a small placeholder model, update to trained model after training completes
resource "kubernetes_deployment" "vllm_serving" {
  # Don't wait for rollout - GPU operator needs time to install drivers  
  wait_for_rollout = false
  
  metadata {
    name      = "vllm-serving"
    namespace = "inference"
    labels = {
      app = "vllm-serving"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "vllm-serving"
      }
    }

    template {
      metadata {
        labels = {
          app = "vllm-serving"
        }
      }

      spec {
        node_selector = {
          "library-solution" = "k8s-training"
        }

        container {
          name  = "vllm"
          image = "vllm/vllm-openai:latest" # Latest vLLM with OpenAI-compatible API

          # Use a small placeholder model initially (facebook/opt-125m is tiny ~250MB)
          # After training, update this to: "/models/finetuned-model"
          args = [
            "--model", "facebook/opt-125m",
            "--port", "8000",
            "--host", "0.0.0.0",
            "--tensor-parallel-size", "1",
            "--gpu-memory-utilization", "0.9",
            "--max-model-len", "4096",
            "--enable-prefix-caching",
            "--trust-remote-code"
          ]

          port {
            container_port = 8000
            name           = "http"
          }

          env {
            name  = "CUDA_VISIBLE_DEVICES"
            value = "0"
          }

          resources {
            requests = {
              cpu    = "8"
              memory = "100Gi"
            }
            limits = {
              cpu    = "16"
              memory = "200Gi"
            }
          }

          # GPU resource is specified via annotation/selector, handled by GPU operator

          volume_mount {
            name       = "model-storage"
            mount_path = "/models"
            read_only  = true
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 60
            period_seconds        = 30
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 90
            period_seconds        = 10
          }
        }

        volume {
          name = "model-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.model_storage.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    module.gpu-operator,
    kubernetes_namespace.inference
  ]
}

# PVC for model storage
resource "kubernetes_persistent_volume_claim" "model_storage" {
  # Do not block Terraform waiting for the PV to bind; it will bind when
  # the first consumer (pod) is scheduled due to StorageClass binding mode
  wait_until_bound = false
  metadata {
    name      = "model-storage-pvc"
    namespace = "inference"
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    # Use the default storage class explicitly
    storage_class_name = "compute-csi-default-sc"
    resources {
      requests = {
        storage = "50Gi" # Reduced for demo - enough for 1-2 model checkpoints
      }
    }
  }
}

# vLLM Service
resource "kubernetes_service" "vllm_serving" {
  metadata {
    name      = "vllm-serving"
    namespace = "inference"
    labels = {
      app = "vllm-serving"
    }
  }

  spec {
    type = "ClusterIP"
    port {
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
      name        = "http"
    }
    selector = {
      app = "vllm-serving"
    }
  }

  depends_on = [kubernetes_deployment.vllm_serving]
}

# Horizontal Pod Autoscaler for handling 16-32 concurrent requests
resource "kubernetes_horizontal_pod_autoscaler_v2" "vllm_autoscaler" {
  metadata {
    name      = "vllm-autoscaler"
    namespace = "inference"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.vllm_serving.metadata[0].name
    }

    min_replicas = 1
    max_replicas = 4 # Scale up to handle 16-32 concurrent requests

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }

    # HPA behavior is configured automatically by Kubernetes
  }

  depends_on = [kubernetes_deployment.vllm_serving]
}

# ServiceMonitor for Prometheus metrics (if Prometheus is installed)
# resource "kubernetes_manifest" "vllm_service_monitor" {
#   manifest = {
#     apiVersion = "monitoring.coreos.com/v1"
#     kind       = "ServiceMonitor"
#     metadata = {
#       name      = "vllm-serving"
#       namespace = "inference"
#     }
#     spec = {
#       selector = {
#         matchLabels = {
#           app = "vllm-serving"
#         }
#       }
#       endpoints = [{
#         port   = "http"
#         path   = "/metrics"
#         interval = "30s"
#       }]
#     }
#   }
# }

