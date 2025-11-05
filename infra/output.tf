output "kube_cluster" {
  description = "Kubernetes cluster info."
  value = {
    id        = try(nebius_mk8s_v1_cluster.k8s-cluster.id, null)
    name      = try(nebius_mk8s_v1_cluster.k8s-cluster.name, null)
    endpoints = nebius_mk8s_v1_cluster.k8s-cluster.status.control_plane.endpoints
  }
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = nebius_mk8s_v1_cluster.k8s-cluster.status.control_plane.endpoints.public_endpoint
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "nebius mk8s v1 cluster get-credentials --id ${nebius_mk8s_v1_cluster.k8s-cluster.id} --external"
}

output "verify_cluster" {
  description = "Commands to verify cluster"
  value       = <<-EOT
    # Configure kubectl
    nebius mk8s v1 cluster get-credentials --id ${nebius_mk8s_v1_cluster.k8s-cluster.id} --external
    
    # Verify cluster
    kubectl cluster-info
    kubectl get nodes
    
    # Check GPU nodes
    kubectl get nodes -l library-solution=k8s-training
    kubectl describe node -l library-solution=k8s-training | grep -i gpu
  EOT
}

output "mlflow_service" {
  description = "MLflow tracking server connection info"
  value = {
    service_name = try(kubernetes_service.mlflow_server.metadata[0].name, null)
    namespace    = try(kubernetes_namespace.mlflow.metadata[0].name, null)
    tracking_uri = "http://${try(kubernetes_service.mlflow_server.metadata[0].name, "mlflow-server")}.${try(kubernetes_namespace.mlflow.metadata[0].name, "mlflow")}.svc.cluster.local:5000"
  }
}

output "mlflow_access" {
  description = "How to access MLflow UI"
  value       = <<-EOT
    # Port-forward to access MLflow UI locally:
    kubectl port-forward -n mlflow svc/mlflow-server 5000:5000
    
    # Then open: http://localhost:5000
    
    # Or use ClusterIP from within pods:
    # MLFLOW_TRACKING_URI=http://mlflow-server.mlflow.svc.cluster.local:5000
  EOT
}

output "vllm_inference" {
  description = "vLLM inference server connection info"
  value = {
    service_name = try(kubernetes_service.vllm_serving.metadata[0].name, null)
    namespace    = try(kubernetes_namespace.inference.metadata[0].name, null)
    endpoint     = "http://${try(kubernetes_service.vllm_serving.metadata[0].name, "vllm-serving")}.${try(kubernetes_namespace.inference.metadata[0].name, "inference")}.svc.cluster.local:8000"
    openai_api   = "http://${try(kubernetes_service.vllm_serving.metadata[0].name, "vllm-serving")}.${try(kubernetes_namespace.inference.metadata[0].name, "inference")}.svc.cluster.local:8000/v1"
  }
}

output "benchmark_inference" {
  description = "How to benchmark inference performance"
  value       = <<-EOT
    # Port-forward to access vLLM locally:
    kubectl port-forward -n inference svc/vllm-serving 8000:8000
    
    # Test OpenAI-compatible API:
    curl http://localhost:8000/v1/completions \\
      -H "Content-Type: application/json" \\
      -d '{
        "model": "finetuned-model",
        "prompt": "What is function calling?",
        "max_tokens": 100,
        "temperature": 0.7
      }'
    
    # Run load test (16-32 concurrent requests):
    # Use tools like: locust, k6, or Python asyncio
    # Measure TTFT (time-to-first-token) and end-to-end latency
  EOT
}

# Grafana password output (when observability module is enabled)
# output "grafana_password" {
#   sensitive = true
#   value     = module.o11y.grafana_password
# }

