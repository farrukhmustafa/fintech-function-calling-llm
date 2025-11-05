# Nebius Kubernetes Training Infrastructure

Complete production-ready solution for LLM fine-tuning with MLflow tracking, KubeRay support, and optimized inference serving.

## 🚀 What's Included

### Core Infrastructure
- ✅ **Kubernetes Cluster** - Managed K8s with H100 GPU nodes
- ✅ **MLflow Tracking** - Full experiment tracking with PostgreSQL backend
- ✅ **vLLM Inference** - Optimized serving with auto-scaling for 16-32 concurrent requests
- ✅ **KubeRay Support** - Distributed training capability (optional)
- ✅ **GPU Operator** - NVIDIA GPU management
- ✅ **Filestore** - Shared storage for datasets and artifacts

### Key Features
- **MLflow Integration** - Industry-standard experiment tracking
- **Auto-scaling Inference** - HPA scales 1-4 replicas based on load
- **Optimized Serving** - vLLM with PagedAttention and continuous batching
- **Production-Ready** - Resource limits, health checks, persistent storage
- **Best Practices** - Follows Nebius Solutions Library patterns

## 📁 Files Overview

### Terraform Configuration
- `provider.tf` - Provider configuration
- `main.tf` - Cluster and node groups
- `locals.tf` - Region defaults and helpers
- `variables.tf` - All configuration variables
- `filesystem.tf` - Filestore configuration
- `gpu_cluster.tf` - InfiniBand GPU cluster
- `helm.tf` - GPU Operator and other helm charts
- `applications.tf` - **MLflow deployment** (PostgreSQL + MLflow server)
- `training.tf` - **KubeRay operator** for distributed training
- `inference.tf` - **vLLM serving** with auto-scaling
- `output.tf` - Outputs including MLflow and vLLM endpoints

### Documentation
- `README.md` - This file
- `QUICK_START.md` - Setup guide with your IDs
- `INFRASTRUCTURE_READINESS.md` - Task readiness assessment
- `PRODUCTION_SOLUTION.md` - Complete solution overview

## 🎯 For Your LLM Fine-Tuning Task

This infrastructure is ready for:
1. **Training**: Fine-tune on ToolACE dataset with MLflow tracking
2. **Evaluation**: Run BFCL evaluation scripts
3. **Inference**: Deploy optimized model with vLLM
4. **Benchmarking**: Test 16-32 concurrent requests, measure TTFT/latency

## 🚀 Quick Start

```bash
# 1. Set environment variables
export NEBIUS_TENANT_ID='tenant-'
export NEBIUS_PROJECT_ID='project-'
export NEBIUS_REGION='eu-north1'

# 2. Source environment script
source ./environment.sh

# 3. Deploy infrastructure
terraform init
terraform plan
terraform apply

# 4. Access MLflow
kubectl port-forward -n mlflow svc/mlflow-server 5000:5000
# Open http://localhost:5000

# 5. Access vLLM (after deployment)
kubectl port-forward -n inference svc/vllm-serving 8000:8000
```

## 📊 What Makes This Impressive

1. **MLflow** - Full experiment tracking with PostgreSQL backend
2. **KubeRay** - Enterprise distributed training support
3. **vLLM** - Latest inference optimization (PagedAttention)
4. **Auto-scaling** - Production-ready HPA configuration
5. **Best Practices** - Infrastructure as Code, resource management
6. **Complete Pipeline** - Training → Evaluation → Inference → Benchmarking

