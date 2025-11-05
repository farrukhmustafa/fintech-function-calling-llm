# Cloud Provider Infrastructure

**Choose your cloud provider for deploying the LLM fine-tuning platform.**

This repository supports multiple cloud providers with identical Kubernetes workloads and evaluation scripts.

---

## 🌐 Supported Cloud Providers

### 1. Nebius AI Cloud
**Location:** `cloud-providers/nebius/`

**Best for:**
- H100 GPU availability
- European data residency
- Managed Kubernetes with GPU optimization
- Cost-effective GPU compute

**Infrastructure:**
- Terraform configurations in `nebius/infra/`
- Custom Nebius modules in `nebius/modules/`
- Optimized for 1x H100 GPU node

**Quick Start:**
```bash
cd cloud-providers/nebius/infra/
source ./environment.sh
terraform init
terraform apply
```

**Documentation:** See [documentation/1_INFRASTRUCTURE_DEPLOYMENT.md](../documentation/1_INFRASTRUCTURE_DEPLOYMENT.md)

---

### 2. AWS (Amazon EKS)
**Location:** `cloud-providers/aws/`

**Best for:**
- Global availability
- Enterprise compliance requirements
- Integration with existing AWS infrastructure
- AWS credits/contracts

**Infrastructure:**
- Terraform configurations in `aws/infra/`
- Uses standard AWS EKS with GPU node groups
- Optimized for p4d.24xlarge (8x A100) or p5.48xlarge (8x H100)

**Quick Start:**
```bash
cd cloud-providers/aws/infra/
terraform init
terraform apply
```

**Status:** 🚧 In development

---

## 📦 What's Shared Across All Clouds

The following resources work identically on any cloud provider:

- **`/kubernetes/`** - All Kubernetes manifests (training jobs, deployments)
- **`/scripts/`** - Python evaluation scripts (BFCL, benchmarks)
- **`/data/`** - Training and evaluation datasets
- **`/documentation/`** - Complete setup and usage guides
- **`RUN_MODEL_EVALUATION.sh`** - Automated evaluation pipeline

**Only the infrastructure layer changes per cloud provider!**

---

## 🔄 Switching Cloud Providers

To switch from one cloud provider to another:

1. Deploy infrastructure in your chosen cloud directory
2. Configure kubectl to point to the new cluster
3. All Kubernetes manifests work without modification!

Example:
```bash
# Deploy on Nebius
cd cloud-providers/nebius/infra/
terraform apply
nebius mk8s cluster get-credentials ...

# Or deploy on AWS
cd cloud-providers/aws/infra/
terraform apply
aws eks update-kubeconfig ...

# Then use the same Kubernetes resources
kubectl apply -f ../../../kubernetes/training-job-qlora-optimized.yaml
../../../RUN_MODEL_EVALUATION.sh ...
```

---

## 📊 Infrastructure Comparison

| Feature | Nebius | AWS EKS |
|---------|--------|---------|
| **GPU** | 1x H100 (80GB) | 8x A100/H100 (p4d/p5) |
| **Managed K8s** | ✅ Nebius MK8s | ✅ EKS |
| **Auto-scaling** | ✅ Node groups | ✅ Node groups + Karpenter |
| **Storage** | Filestore | EFS |
| **Networking** | VPC + Subnet | VPC + Multi-AZ subnets |
| **GPU Operator** | Custom modules | NVIDIA Helm chart |
| **Cost (estimated)** | ~$2-3/hour | ~$30-40/hour (p4d.24xlarge) |
| **Setup Time** | ~30 min | ~30 min |

---

## 🚀 Adding New Cloud Providers

To add support for another cloud (GCP, Azure, etc.):

1. Create new directory: `cloud-providers/<provider>/infra/`
2. Copy AWS or Nebius infra as template
3. Update Terraform provider and resources
4. Update this README with provider details
5. Test with shared Kubernetes manifests

**Pull requests welcome!**

---

## 🎯 Recommendation

**For this demo:**
- **Nebius**: Best accuracy results achieved (96.5% BFCL)
- **AWS**: Alternative for organizations with AWS requirements

**For production:**
- Choose based on your organization's cloud strategy
- All providers achieve similar model accuracy
- Infrastructure costs vary significantly

---

## 📖 Documentation

- **Infrastructure Setup**: [../documentation/1_INFRASTRUCTURE_DEPLOYMENT.md](../documentation/1_INFRASTRUCTURE_DEPLOYMENT.md)
- **Training Guide**: [../documentation/2_MODEL_TRAINING_EVALUATION.md](../documentation/2_MODEL_TRAINING_EVALUATION.md)
- **Main README**: [../README.md](../README.md)

---

**Need help choosing?** Consider:
- Geographic requirements → Nebius (EU), AWS (global)
- Existing cloud contracts → Use your contracted provider
- GPU availability → Check current availability
- Cost sensitivity → Nebius typically more cost-effective for GPUs

