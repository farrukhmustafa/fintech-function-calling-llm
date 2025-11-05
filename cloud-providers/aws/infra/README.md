# AWS EKS Infrastructure for LLM Fine-Tuning

**Terraform configuration for deploying the LLM fine-tuning platform on AWS EKS with GPU support.**

---

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** installed and configured
   ```bash
   aws --version
   aws configure
   ```

2. **kubectl** installed
   ```bash
   kubectl version --client
   ```

3. **Terraform** 1.5+ installed
   ```bash
   terraform version
   ```

4. **AWS Permissions** - Your AWS account needs:
   - EKS full access
   - EC2 full access (for nodes)
   - VPC full access
   - IAM role/policy creation
   - EFS full access (if using shared storage)

### Deploy Infrastructure

```bash
# 1. Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Edit with your settings

# 2. Initialize Terraform
terraform init

# 3. Preview changes
terraform plan

# 4. Deploy (takes ~15-20 minutes)
terraform apply

# 5. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name fintech-llm-cluster-dev

# 6. Verify cluster
kubectl get nodes
kubectl get nodes -l node-type=gpu -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'
```

---

## 📋 What Gets Created

### Networking
- **VPC** with `/16` CIDR
- **2 Public Subnets** (for load balancers)
- **2 Private Subnets** (for EKS nodes)
- **2 NAT Gateways** (one per AZ for HA)
- **Internet Gateway**
- **Route Tables** (public + private per AZ)

### EKS Cluster
- **EKS Control Plane** (Kubernetes 1.28)
- **OIDC Provider** (for IAM roles for service accounts)
- **2 Node Groups**:
  - CPU nodes (t3.xlarge): System workloads
  - GPU nodes (p3.2xlarge): Training/inference

### Storage
- **EFS File System** (shared storage)
- **EFS Mount Targets** (one per AZ)
- **EFS CSI Driver** (Helm chart)

### GPU Support
- **NVIDIA Device Plugin** (Helm chart)
- **GPU node taints** (nvidia.com/gpu=true:NoSchedule)
- **GPU node labels** (node-type=gpu, library-solution=k8s-training)

### IAM
- **EKS Cluster Role** (for control plane)
- **EKS Node Role** (for worker nodes)
- **EFS CSI Driver Policy** (for EFS access)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Region (us-east-1)                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  VPC (10.0.0.0/16)                                         │
│  ┌──────────────────────────────────────────────────────┐ │
│  │                                                        │ │
│  │  AZ-A (us-east-1a)         AZ-B (us-east-1b)         │ │
│  │  ┌────────────────┐        ┌────────────────┐        │ │
│  │  │ Public Subnet  │        │ Public Subnet  │        │ │
│  │  │ NAT Gateway    │        │ NAT Gateway    │        │ │
│  │  └────────────────┘        └────────────────┘        │ │
│  │  ┌────────────────┐        ┌────────────────┐        │ │
│  │  │ Private Subnet │        │ Private Subnet │        │ │
│  │  │ EKS Nodes      │        │ EKS Nodes      │        │ │
│  │  │ • CPU Node     │        │ (Standby)      │        │ │
│  │  │ • GPU Node     │        │                │        │ │
│  │  └────────────────┘        └────────────────┘        │ │
│  │                                                        │ │
│  │  EFS (Shared Storage)                                 │ │
│  │  • /mnt/data/outputs (models)                         │ │
│  │  • /mnt/data/datasets                                 │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  EKS Control Plane                                         │
│  • Kubernetes API                                          │
│  • Managed by AWS                                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 💰 Cost Breakdown

### Monthly Cost (24/7 operation):
- **VPC & Networking**: ~$90/month (2 NAT Gateways @ $45 each)
- **EFS**: ~$15/month (50GB @ $0.30/GB-month)
- **EKS Control Plane**: ~$73/month
- **CPU Node (t3.xlarge)**: ~$120/month
- **GPU Node (p3.2xlarge)**: ~$2,200/month
- **Total**: ~$2,500/month (mostly GPU node)

### Cost Optimization:
1. **Scale GPU to 0 when idle**: Save ~$2,200/month
2. **Use Spot Instances**: 70% discount (~$660/month instead of $2,200)
3. **Use Reserved Instances**: Up to 75% discount for 1-year commit

### Typical Demo Cost (8 hours):
- VPC/EKS: ~$6
- CPU node: ~$5
- GPU node: ~$24
- **Total: ~$35 for full 8-hour demo**

---

## 🔧 Configuration Options

### GPU Instance Types

| Instance Type | GPUs | GPU Model | VRAM | vCPU | RAM | Cost/hr | Best For |
|--------------|------|-----------|------|------|-----|---------|----------|
| p3.2xlarge | 1 | V100 | 16GB | 8 | 61GB | ~$3 | Testing, small models |
| p3.8xlarge | 4 | V100 | 64GB | 32 | 244GB | ~$12 | Medium models |
| p4d.24xlarge | 8 | A100 | 320GB | 96 | 1152GB | ~$32 | Large models, multi-GPU |
| p5.48xlarge | 8 | H100 | 640GB | 192 | 2048GB | ~$98 | Largest models (limited availability) |

**Recommendation for this demo:** Start with `p3.2xlarge` (1x V100, 16GB VRAM)

### Scaling Configuration

```hcl
# Auto-scale GPU nodes based on demand
gpu_nodes_desired = 1  # Start with 1
gpu_nodes_min     = 0  # Scale to 0 when idle
gpu_nodes_max     = 2  # Scale up to 2 if needed

# Auto-scale CPU nodes
cpu_nodes_desired = 1
cpu_nodes_min     = 1
cpu_nodes_max     = 3
```

---

## 🚀 Deploying Applications

After infrastructure is deployed, deploy the ML workloads:

```bash
# Navigate back to root
cd ../../../

# Deploy MLflow
kubectl apply -f kubernetes/training-job-qlora-optimized.yaml

# Monitor training
kubectl logs -n mlflow -f job/training-qlora-optimized

# Run evaluation
./RUN_MODEL_EVALUATION.sh \
  "qlora-optimized-qwen25-7b" \
  "Qwen/Qwen2.5-7B-Instruct" \
  "merged-qwen25-7b-finetuned"
```

**All Kubernetes manifests work identically on AWS EKS!**

---

## 📊 Monitoring

### View Cluster Status
```bash
# All nodes
kubectl get nodes -o wide

# GPU nodes specifically
kubectl get nodes -l node-type=gpu

# Check GPU allocation
kubectl describe nodes -l node-type=gpu | grep -A 5 "Allocated resources"

# View all pods
kubectl get pods -A
```

### CloudWatch Integration
```bash
# Enable CloudWatch Container Insights
aws eks update-cluster-config \
  --name fintech-llm-cluster-dev \
  --region us-east-1 \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

---

## 🔒 Security Best Practices

1. **Private Node Networking**: Nodes are in private subnets
2. **IAM Roles**: Least-privilege IAM roles for nodes
3. **Encryption**: EFS encrypted at rest
4. **Security Groups**: Restrictive security groups on EFS
5. **OIDC Provider**: For fine-grained IAM permissions

---

## 🐛 Troubleshooting

### Nodes Not Joining Cluster
```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name fintech-llm-cluster-dev \
  --nodegroup-name fintech-llm-cluster-dev-gpu-nodes

# View node group events
kubectl get events -n kube-system
```

### GPU Not Detected
```bash
# Check NVIDIA device plugin
kubectl get pods -n kube-system -l name=nvidia-device-plugin

# Check GPU availability
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'

# If no GPUs shown, check AMI supports GPUs
```

### EFS Mount Issues
```bash
# Check EFS CSI driver
kubectl get pods -n kube-system -l app=efs-csi-controller

# Check mount targets
aws efs describe-mount-targets \
  --file-system-id fs-xxxxx
```

---

## 🧹 Cleanup

To destroy all infrastructure:

```bash
# Delete all Kubernetes resources first
kubectl delete all --all -n mlflow
kubectl delete all --all -n inference

# Destroy Terraform resources
terraform destroy

# Confirm deletion
# Type 'yes' when prompted
```

**Warning**: This will delete everything including trained models!

---

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [NVIDIA Device Plugin](https://github.com/NVIDIA/k8s-device-plugin)
- [EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver)
- [AWS Pricing Calculator](https://calculator.aws/)

---

## 🔄 Migrating from Nebius

All Kubernetes manifests are compatible! The only changes needed:

1. Deploy this AWS infrastructure
2. Configure kubectl to use EKS cluster
3. Apply the same Kubernetes YAML files
4. Run the same evaluation scripts

**No changes to training jobs, inference deployments, or evaluation scripts!**

---

**Questions?** See [cloud-providers/README.md](../README.md) for cloud provider comparison.
