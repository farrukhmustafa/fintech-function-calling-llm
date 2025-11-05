# EKS Cluster Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# EFS Outputs
output "efs_id" {
  description = "EFS file system ID"
  value       = var.enable_efs ? aws_efs_file_system.shared[0].id : null
}

output "efs_dns_name" {
  description = "EFS DNS name"
  value       = var.enable_efs ? aws_efs_file_system.shared[0].dns_name : null
}

# Node Group Outputs
output "eks_managed_node_groups" {
  description = "Map of managed node groups"
  value       = module.eks.eks_managed_node_groups
}

# kubectl Configuration
output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Verification Commands
output "verify_cluster" {
  description = "Commands to verify cluster"
  value = <<-EOT
    # Configure kubectl
    aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}
    
    # Verify nodes
    kubectl get nodes -o wide
    
    # Verify GPU nodes (should show 1 GPU)
    kubectl get nodes -l node-type=gpu -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'
    
    # Verify CPU nodes
    kubectl get nodes -l node-type=cpu
    
    # Check all pods
    kubectl get pods -A
  EOT
}

# MLflow Access
output "mlflow_access" {
  description = "How to access MLflow"
  value = <<-EOT
    # Port-forward to MLflow
    kubectl port-forward -n mlflow svc/mlflow-server 5000:5000
    
    # Open in browser
    open http://localhost:5000
  EOT
}

# vLLM Inference Access
output "vllm_inference" {
  description = "How to access vLLM inference"
  value = <<-EOT
    # Port-forward to vLLM
    kubectl port-forward -n inference svc/vllm-serving 8000:8000
    
    # Test API
    curl http://localhost:8000/v1/models
  EOT
}

# Training Commands
output "training_commands" {
  description = "Commands to start training"
  value = <<-EOT
    # Apply training job
    kubectl apply -f ../../../kubernetes/training-job-qlora-optimized.yaml
    
    # Monitor training
    kubectl logs -n mlflow -f job/training-qlora-optimized
    
    # Run complete evaluation
    cd ../../../
    ./RUN_MODEL_EVALUATION.sh "qlora-optimized-qwen25-7b" "Qwen/Qwen2.5-7B-Instruct" "merged-qwen25-7b-finetuned"
  EOT
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost (approximate)"
  value = <<-EOT
    Estimated AWS costs (on-demand pricing):
    - VPC & Networking: ~$50/month (NAT Gateway)
    - EFS: ~$0.30/GB-month (first 50GB)
    - CPU nodes (t3.xlarge): ~$120/month per node (24/7)
    - GPU nodes (p3.2xlarge): ~$2,200/month per node (24/7)
    
    Recommendations:
    - Use EC2 Spot instances for 70% cost savings on GPU nodes
    - Scale GPU nodes to 0 when not training
    - Use on-demand only for critical workloads
    
    Typical demo cost (8 hours):
    - 1x CPU node: ~$5
    - 1x GPU node (p3.2xlarge): ~$24
    - Total: ~$30 for 8-hour demo
  EOT
}
