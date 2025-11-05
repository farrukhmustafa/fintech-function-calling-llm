# Nebius AI Cloud - Kubernetes Infrastructure Deployment Guide

**Complete guide for deploying production-ready Kubernetes infrastructure for LLM fine-tuning and inference.**

---

## 📋 Overview

This infrastructure provides a complete MLOps platform for LLM fine-tuning with:
- Managed Kubernetes cluster with H100 GPU nodes
- MLflow experiment tracking with PostgreSQL backend
- vLLM optimized inference serving
- Auto-scaling for production workloads
- Persistent storage for datasets and models

---

## 🏗️ Architecture Components

### Compute Resources
- **CPU Node**: 4 vCPU, 16GB RAM (system workloads)
- **GPU Node**: 1x H100 80GB, 16 vCPU, 200GB RAM (training & inference)

### Software Stack
- **Kubernetes**: Managed K8s v1.28+ 
- **GPU Operator**: NVIDIA driver management and device plugin
- **MLflow**: Experiment tracking server (port 5000)
- **PostgreSQL**: MLflow metadata backend (10Gi storage)
- **vLLM**: OpenAI-compatible inference server (port 8000)

### Storage
- **Training Data PVC**: 30Gi, ReadWriteMany
- **Model Storage**: Direct hostPath access to `/mnt/data/outputs`
- **MLflow Artifacts**: 20Gi PVC for experiment artifacts

---

## 🚀 Deployment Steps

### Prerequisites

1. **Nebius Account**: Access to Nebius AI Cloud console
2. **Terraform**: Version 1.5+ installed locally
3. **kubectl**: Kubernetes CLI tool installed
4. **Nebius CLI**: For authentication

```bash
# Install Nebius CLI (macOS)
curl -sSL https://install.cli.nebius.ai/install.sh | bash

# Verify installation
nebius --version
```

### Step 1: Configure Environment

Find your IDs in the Nebius console:
- **Tenant ID**: Organization settings → ID (format: `tenant-xxxxx`)
- **Project ID**: Current project → ID (format: `project-xxxxx`)
- **Region**: Default is `eu-north1`

Set environment variables:

```bash
cd infra/

# Edit environment.sh and set your IDs
export NEBIUS_TENANT_ID='tenant-your-id-here'
export NEBIUS_PROJECT_ID='project-your-id-here'
export NEBIUS_REGION='eu-north1'

# Source the environment script
source ./environment.sh
```

This will:
- ✅ Get your IAM access token (12-hour validity)
- ✅ Set Terraform variables
- ✅ Configure kubectl access

### Step 2: Configure Terraform Variables

Edit `terraform.tfvars` to customize your deployment:

```hcl
# Required: Add your SSH public key for node access
ssh_public_key = {
  key = "ssh-rsa AAAAB3... your-email@example.com"
}

# GPU Configuration (1x H100)
gpu_nodes_count_per_group = 1
gpu_nodes_preset = "1gpu-16vcpu-200gb"
enable_gpu_cluster = false  # Single GPU doesn't need clustering

# Storage (optimized for demo)
filestore_disk_size = 50 * 1024 * 1024 * 1024  # 50GB

# Optional: Enable monitoring
enable_prometheus = true
enable_loki = true
```

**Key Variables:**
- `cpu_nodes_count`: Number of CPU-only nodes (default: 1)
- `gpu_nodes_count_per_group`: Number of GPU nodes (default: 1)
- `gpu_nodes_preset`: GPU node size (default: `1gpu-16vcpu-200gb`)
- `filestore_disk_size`: Shared storage size (default: 50GB)

### Step 3: Deploy Infrastructure

```bash
# Initialize Terraform (downloads providers)
terraform init

# Preview what will be created
terraform plan

# Deploy infrastructure (takes 10-15 minutes)
terraform apply

# Type 'yes' when prompted
```

**What gets created:**
1. VPC network and subnet
2. Kubernetes cluster (control plane)
3. CPU node group (system workloads)
4. GPU node group (1x H100)
5. GPU Operator (NVIDIA drivers)
6. MLflow server with PostgreSQL
7. vLLM inference deployment (placeholder model)

### Step 4: Configure kubectl Access

```bash
# Get cluster credentials
nebius mk8s cluster get-credentials \
  --parent-id=$NEBIUS_PROJECT_ID \
  --name=llm-training-cluster

# Verify access
kubectl get nodes

# Expected output:
# NAME                    STATUS   ROLES    AGE   VERSION
# k8s-control-plane-...   Ready    master   10m   v1.28.x
# k8s-cpu-node-...        Ready    <none>   8m    v1.28.x
# k8s-gpu-node-...        Ready    <none>   8m    v1.28.x
```

### Step 5: Verify Deployment

Check all components are running:

```bash
# Check GPU nodes have the correct label
kubectl get nodes -l library-solution=k8s-training

# Check GPU Operator
kubectl get pods -n gpu-operator

# Check MLflow
kubectl get pods -n mlflow
kubectl get svc -n mlflow

# Check vLLM
kubectl get pods -n inference
kubectl get svc -n inference

# Verify GPU is available
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'
```

### Step 6: Access Services

**MLflow UI:**
```bash
# Port-forward MLflow (in a separate terminal)
kubectl port-forward -n mlflow svc/mlflow-server 5000:5000

# Open browser: http://localhost:5000
```

**vLLM API:**
```bash
# Port-forward vLLM (in a separate terminal)
kubectl port-forward -n inference svc/vllm-serving 8000:8000

# Test API
curl http://localhost:8000/v1/models
```

---

## 📊 Infrastructure Outputs

After deployment, Terraform outputs useful information:

```bash
terraform output

# Key outputs:
# - cluster_endpoint: K8s API endpoint
# - mlflow_service: MLflow connection details
# - vllm_inference: vLLM connection details
```

---

## 🔧 Common Operations

### Scale GPU Nodes

```bash
# Scale down (save costs during idle time)
kubectl -n inference scale deployment vllm-serving --replicas=0

# Scale up
kubectl -n inference scale deployment vllm-serving --replicas=1
```

### View Logs

```bash
# MLflow logs
kubectl logs -n mlflow deployment/mlflow-server -f

# vLLM logs
kubectl logs -n inference deployment/vllm-serving -f

# Training job logs (when running)
kubectl logs -n mlflow job/training-qlora-optimized -f
```

### Restart Services

```bash
# Restart MLflow
kubectl rollout restart deployment/mlflow-server -n mlflow

# Restart vLLM
kubectl rollout restart deployment/vllm-serving -n inference
```

---

## 🔒 Security Best Practices

1. **IAM Tokens**: Tokens expire after 12 hours - re-run `source ./environment.sh`
2. **SSH Keys**: Only add trusted public keys to `terraform.tfvars`
3. **Network Access**: Use port-forward for services, avoid public exposure
4. **Resource Limits**: All pods have memory/CPU limits to prevent resource exhaustion

---

## 🧹 Cleanup

To destroy all infrastructure:

```bash
cd infra/

# Preview what will be deleted
terraform plan -destroy

# Destroy infrastructure
terraform destroy

# Type 'yes' when prompted
```

**Warning**: This will delete:
- Kubernetes cluster (all pods, services)
- All persistent volumes (data loss!)
- GPU compute resources
- Network resources

---

## 📚 File Structure

```
infra/
├── provider.tf          # Terraform provider config
├── main.tf             # Cluster and node groups
├── locals.tf           # Region-specific defaults
├── variables.tf        # Input variables
├── terraform.tfvars    # Your configuration values
├── filesystem.tf       # Shared storage (filestore)
├── gpu_cluster.tf      # InfiniBand GPU cluster config
├── helm.tf            # GPU Operator modules
├── applications.tf    # MLflow + PostgreSQL
├── inference.tf       # vLLM deployment
├── output.tf          # Terraform outputs
├── environment.sh     # Helper script for env setup
└── README.md          # Original infrastructure docs
```

---

## 🐛 Troubleshooting

### GPU Node Not Ready

```bash
# Check GPU operator status
kubectl get pods -n gpu-operator

# Check driver installation
kubectl logs -n gpu-operator -l app=nvidia-driver-daemonset

# Verify GPU devices
kubectl describe node -l library-solution=k8s-training | grep nvidia.com/gpu
```

### MLflow Connection Failed

```bash
# Check PostgreSQL
kubectl get pods -n mlflow | grep postgresql

# Check MLflow logs
kubectl logs -n mlflow deployment/mlflow-server --tail=50
```

### vLLM Pod Stuck Pending

```bash
# Check events
kubectl describe pod -n inference -l app=vllm-serving

# Common issue: GPU not available
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'

# Solution: Scale down other GPU workloads first
kubectl -n mlflow delete job training-qlora-optimized
```

---

## 📖 Next Steps

After infrastructure is deployed, proceed to:
- **Document 2**: Model Training & Evaluation Guide
- Train models using the provided Kubernetes job YAML files
- Evaluate using the `RUN_MODEL_EVALUATION.sh` script

---

## 💡 Production Recommendations

For production deployments, consider:

1. **High Availability**: Increase `etcd_cluster_size` to 3
2. **Multi-GPU**: Increase `gpu_nodes_count_per_group` and enable `enable_gpu_cluster`
3. **Auto-scaling**: Enable HPA for vLLM with appropriate metrics
4. **Monitoring**: Enable `enable_prometheus` and `enable_loki`
5. **Backups**: Configure MLflow artifact backup to object storage
6. **Service Accounts**: Create dedicated IAM service accounts instead of user tokens

---

**Questions or issues?** Check `docs/TROUBLESHOOTING_GUIDE.md` for detailed debugging steps.

