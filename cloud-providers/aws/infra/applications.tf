# Applications and workloads for ML training and inference
# Production-ready setup for LLM fine-tuning with MLflow tracking

# MLflow Deployment for Experiment Tracking
resource "kubernetes_namespace" "mlflow" {
  metadata {
    name = "mlflow"
    labels = {
      "library-solution" = "k8s-training"
    }
  }
  depends_on = [aws_eks_cluster.main]
}

# PostgreSQL for MLflow backend (simple Deployment for demo, no PVC)
resource "kubernetes_deployment" "postgresql" {
  # Don't wait for rollout
  wait_for_rollout = false
  
  metadata {
    name      = "postgresql"
    namespace = "mlflow"
    labels = {
      app = "postgresql"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgresql"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgresql"
        }
      }
      spec {
        container {
          name  = "postgresql"
          image = "postgres:16-alpine"

          env {
            name  = "POSTGRES_DB"
            value = "mlflow"
          }
          env {
            name  = "POSTGRES_USER"
            value = "mlflow"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "mlflow-change-me"
          }

          port {
            container_port = 5432
            name           = "tcp-postgresql"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
            sub_path   = "pgdata"  # Use subdirectory to avoid lost+found issue
          }
          liveness_probe {
            tcp_socket {
              port = 5432
            }
            initial_delay_seconds = 20
            period_seconds        = 10
          }
          readiness_probe {
            tcp_socket {
              port = 5432
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgresql_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = "mlflow"
    labels = {
      app = "postgresql"
    }
  }
  spec {
    selector = {
      app = "postgresql"
    }
    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
      name        = "tcp-postgresql"
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_deployment.postgresql]
}

# MLflow Tracking Server
resource "kubernetes_deployment" "mlflow_server" {
  # Don't wait for rollout - let it deploy in background
  wait_for_rollout = false
  
  metadata {
    name      = "mlflow-server"
    namespace = "mlflow"
    labels = {
      app = "mlflow-server"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mlflow-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "mlflow-server"
        }
      }

      spec {
        # Init container to install psycopg2
        init_container {
          name  = "install-psycopg2"
          image = "ghcr.io/mlflow/mlflow:v2.14.1"
          command = ["sh", "-c"]
          args = [
            "pip install --target=/deps psycopg2-binary"
          ]
          
          volume_mount {
            name       = "python-deps"
            mount_path = "/deps"
          }
        }
        
        container {
          name  = "mlflow"
          image = "ghcr.io/mlflow/mlflow:v2.14.1"

          command = ["sh", "-c"]
          args = [
            "export PYTHONPATH=/deps:$PYTHONPATH && mlflow server --backend-store-uri postgresql://mlflow:mlflow-change-me@postgresql:5432/mlflow --default-artifact-root file:///mlflow-artifacts --host 0.0.0.0 --port 5000 --serve-artifacts"
          ]

          port {
            container_port = 5000
            name           = "http"
          }

          env {
            name  = "MLFLOW_TRACKING_URI"
            value = "http://mlflow-server:5000"
          }

          resources {
            requests = {
              memory = "2Gi"
              cpu    = "1"
            }
            limits = {
              memory = "4Gi"
              cpu    = "2"
            }
          }

          volume_mount {
            name       = "mlflow-artifacts"
            mount_path = "/mlflow-artifacts"
          }
          
          volume_mount {
            name       = "python-deps"
            mount_path = "/deps"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }

        volume {
          name = "mlflow-artifacts"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mlflow_artifacts.metadata[0].name
          }
        }
        
        volume {
          name = "python-deps"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment.postgresql,
    kubernetes_namespace.mlflow
  ]
}

# PVC for PostgreSQL data - Production best practice
resource "kubernetes_persistent_volume_claim" "postgresql_data" {
  wait_until_bound = false
  metadata {
    name      = "postgresql-data-pvc"
    namespace = "mlflow"
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "compute-csi-default-sc"
    resources {
      requests = {
        storage = "10Gi" # Small but production-ready for PostgreSQL metadata
      }
    }
  }
}

# PVC for MLflow artifacts - Production best practice
resource "kubernetes_persistent_volume_claim" "mlflow_artifacts" {
  wait_until_bound = false
  metadata {
    name      = "mlflow-artifacts-pvc"
    namespace = "mlflow"
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "compute-csi-default-sc"
    resources {
      requests = {
        storage = "20Gi" # For experiment artifacts, logs, plots
      }
    }
  }
}

# PVC for training datasets - Production best practice
resource "kubernetes_persistent_volume_claim" "training_data" {
  wait_until_bound = false
  metadata {
    name      = "training-data-pvc"
    namespace = "mlflow"
  }
  spec {
    access_modes       = ["ReadWriteMany"] # Multiple pods can read
    storage_class_name = "compute-csi-default-sc"
    resources {
      requests = {
        storage = "30Gi" # For ToolACE dataset and preprocessed data
      }
    }
  }
}

# MLflow Service
resource "kubernetes_service" "mlflow_server" {
  metadata {
    name      = "mlflow-server"
    namespace = "mlflow"
    labels = {
      app = "mlflow-server"
    }
  }

  spec {
    type = "ClusterIP"
    port {
      port        = 5000
      target_port = 5000
      protocol    = "TCP"
      name        = "http"
    }
    selector = {
      app = "mlflow-server"
    }
  }

  depends_on = [kubernetes_deployment.mlflow_server]
}

# MLflow Ingress (optional - for external access)
# Uncomment if you want external access to MLflow UI
# resource "kubernetes_ingress_v1" "mlflow" {
#   metadata {
#     name      = "mlflow-ingress"
#     namespace = kubernetes_namespace.mlflow.metadata[0].name
#     annotations = {
#       "kubernetes.io/ingress.class"                = "nginx"
#       "nginx.ingress.kubernetes.io/ssl-redirect"    = "true"
#       "cert-manager.io/cluster-issuer"             = "letsencrypt-prod"
#     }
#   }
# 
#   spec {
#     ingress_class_name = "nginx"
#     tls {
#       hosts       = ["mlflow.yourcompany.com"]
#       secret_name = "mlflow-tls"
#     }
#     rule {
#       host = "mlflow.yourcompany.com"
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"
#           backend {
#             service {
#               name = kubernetes_service.mlflow_server.metadata[0].name
#               port {
#                 number = 5000
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# 
#   depends_on = [
#     kubernetes_service.mlflow_server,
#     helm_release.nginx_ingress  # If you add nginx ingress
#   ]
# }
