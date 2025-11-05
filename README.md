# Financial AI Agent - Function Calling LLM Platform

**Production-ready infrastructure for fine-tuning and deploying LLMs for financial workflow automation.**

[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![MLflow](https://img.shields.io/badge/MLflow-0194E2?style=flat&logo=mlflow&logoColor=white)](https://mlflow.org/)
[![vLLM](https://img.shields.io/badge/vLLM-FE7A16?style=flat&logo=fastapi&logoColor=white)](https://docs.vllm.ai/)

---

## 🎯 Use Case: FinTech Workflow Automation

**Problem**: FinTech startups need AI agents that can execute precise function calls to internal APIs for:
- Fraud detection workflows
- Transaction processing automation
- Risk assessment pipelines
- Customer service operations

**Solution**: Complete end-to-end platform for:
- **Fine-tuning** LLMs on function calling tasks (ToolACE dataset)
- **Evaluating** model accuracy on industry-standard BFCL benchmark
- **Deploying** production-ready inference with vLLM optimization
- **Benchmarking** performance for 16-32 concurrent requests

**Result**: Achieve **95-98% accuracy** on function calling tasks with optimized inference for financial workloads.

---

## 🚀 Quick Start

### 1. Deploy Infrastructure (~30 minutes)

```bash
cd infra/

# Configure your credentials
export NEBIUS_TENANT_ID='tenant-xxxxx'
export NEBIUS_PROJECT_ID='project-xxxxx'
export NEBIUS_REGION='eu-north1'

# Deploy with Terraform
terraform init
terraform apply
```

See **[documentation/1_INFRASTRUCTURE_DEPLOYMENT.md](documentation/1_INFRASTRUCTURE_DEPLOYMENT.md)** for detailed setup.

### 2. Train & Evaluate Models (~4-6 hours)

```bash
# Train a model
kubectl apply -f kubernetes/training-job-qlora-optimized.yaml

# Wait for training to complete (~3 hours)
kubectl wait --for=condition=complete job/training-qlora-optimized -n mlflow --timeout=6h

# Run complete evaluation pipeline (~1 hour)
./RUN_MODEL_EVALUATION.sh \
  "qlora-optimized-qwen25-7b" \
  "Qwen/Qwen2.5-7B-Instruct" \
  "merged-qwen25-7b-finetuned"
```

See **[documentation/2_MODEL_TRAINING_EVALUATION.md](documentation/2_MODEL_TRAINING_EVALUATION.md)** for complete guide.

---

## 📊 Results Achieved

### Model Accuracy (BFCL Benchmark)
| Model | Method | Simple Functions | Multiple Functions | Avg Accuracy |
|-------|--------|-----------------|-------------------|--------------|
| **Qwen2.5-7B** | QLoRA Optimized | **95%** | **98%** | **96.5%** ⭐ |
| Mistral-7B | QLoRA Optimized | 74% | 80% | 77% |
| Baseline | No fine-tuning | ~50% | ~50% | ~50% |

### Performance (H100 GPU)
- **TTFT**: 245ms average (16 concurrent requests)
- **Latency**: 1.4s average for 200 tokens
- **Throughput**: 342 tokens/sec
- **Concurrent Support**: Up to 32 simultaneous requests

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Cloud Infrastructure (GPU-enabled)             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │  CPU Node    │  │  GPU Node    │  │  Control     │    │
│  │  (System)    │  │  (H100 80GB) │  │  Plane       │    │
│  │              │  │              │  │              │    │
│  │  • MLflow    │  │  • Training  │  │  • K8s API   │    │
│  │  • PostgreSQL│  │  • vLLM      │  │  • etcd      │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │              Shared Filestore (50GB)                 │ │
│  │  • Training datasets (ToolACE)                       │ │
│  │  • Model checkpoints                                 │ │
│  │  • MLflow artifacts                                  │ │
│  └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Key Components:**
- **Kubernetes**: Managed K8s cluster (1.28+)
- **MLflow**: Experiment tracking with PostgreSQL backend
- **Axolotl**: LLM fine-tuning framework
- **vLLM**: Optimized inference server (PagedAttention)
- **GPU Operator**: NVIDIA driver management

---

## 📁 Repository Structure

```
nebius/
├── documentation/              # 📖 Customer-facing documentation
│   ├── README.md              # Documentation overview
│   ├── 1_INFRASTRUCTURE_DEPLOYMENT.md  # Complete setup guide
│   └── 2_MODEL_TRAINING_EVALUATION.md  # Training & evaluation guide
│
├── infra/                     # 🏗️ Terraform infrastructure
│   ├── main.tf               # Cluster and node groups
│   ├── variables.tf          # Configuration variables
│   ├── applications.tf       # MLflow deployment
│   ├── inference.tf          # vLLM deployment
│   └── ... (other .tf files)
│
├── kubernetes/                # ☸️ Kubernetes manifests
│   ├── training-job-qlora-optimized.yaml   # QLoRA training
│   ├── training-job-mistral-7b.yaml        # Mistral training
│   ├── training-job-dora.yaml              # DoRA training
│   ├── vllm-deployment.yaml                # vLLM serving
│   └── storage-checker-pod.yaml            # Storage utility
│
├── scripts/                   # 🐍 Python evaluation scripts
│   ├── evaluate_bfcl_real.py    # BFCL benchmark
│   └── benchmark_inference.py   # Performance tests
│
├── data/                      # 📊 Evaluation datasets
│   ├── bfcl_simple_parsed.json
│   └── bfcl_multiple_parsed.json
│
├── results/                   # 📈 Evaluation outputs
│   ├── bfcl_*.json           # Accuracy results
│   └── benchmark_*.log       # Performance results
│
├── docs/                      # 📚 Internal reference docs
│   ├── MASTER_GUIDE.md       # Complete project guide
│   ├── TROUBLESHOOTING_GUIDE.md
│   └── TRAINING_COMPARISON.md
│
├── RUN_MODEL_EVALUATION.sh    # 🚀 Main automation script
├── .gitignore                # Git ignore rules
└── README.md                 # This file
```

---

## 🔑 Key Features

### Infrastructure as Code
✅ Complete Terraform configuration  
✅ Version-controlled infrastructure  
✅ Reproducible deployments  
✅ Easy cleanup and redeployment

### MLOps Best Practices
✅ MLflow experiment tracking  
✅ Automated model versioning  
✅ Checkpoint management  
✅ Artifact storage

### Production-Ready Inference
✅ vLLM with PagedAttention  
✅ OpenAI-compatible API  
✅ Auto-scaling support  
✅ Health checks and monitoring

### Comprehensive Evaluation
✅ BFCL benchmark (function calling)  
✅ Performance under load (16-32 concurrent)  
✅ TTFT and latency measurements  
✅ Detailed metrics and reports

---

## 🛠️ Technologies Used

| Category | Technology | Purpose |
|----------|-----------|---------|
| **Cloud** | GPU-enabled K8s | H100 GPU infrastructure |
| **Orchestration** | Kubernetes 1.28+ | Container orchestration |
| **IaC** | Terraform | Infrastructure deployment |
| **Training** | Axolotl | LLM fine-tuning framework |
| **Inference** | vLLM | Optimized LLM serving |
| **Tracking** | MLflow | Experiment management |
| **Database** | PostgreSQL | MLflow backend |
| **Dataset** | ToolACE | Financial API function calling |
| **Benchmark** | BFCL | Function calling evaluation |

---

## 📖 Documentation

### Customer Deliverables
- **[Documentation README](documentation/README.md)** - Overview of all docs
- **[Infrastructure Guide](documentation/1_INFRASTRUCTURE_DEPLOYMENT.md)** - Complete setup (30 min)
- **[Training Guide](documentation/2_MODEL_TRAINING_EVALUATION.md)** - Fine-tuning workflow (4-6 hrs)

### Internal Reference
- **[Master Guide](docs/MASTER_GUIDE.md)** - Complete project overview
- **[Troubleshooting](docs/TROUBLESHOOTING_GUIDE.md)** - Debug commands and fixes
- **[Training Comparison](docs/TRAINING_COMPARISON.md)** - QLoRA vs DoRA analysis

---

## 🎯 Use Cases

This platform is ideal for:

1. **Financial AI Agents** - Function calling for transaction processing
2. **API Automation** - LLMs that can call internal APIs
3. **Workflow Automation** - Intelligent task execution
4. **Tool-Augmented LLMs** - Models that use external tools
5. **Custom Function Libraries** - Domain-specific API integration

---

## 💡 Training Methods Compared

| Method | Eval Loss | Accuracy | Training Time | GPU Memory |
|--------|-----------|----------|---------------|------------|
| **QLoRA Optimized** | 0.2356 | **95-98%** | 3 hours | 32GB |
| DoRA | 0.3061 | 78-80% | 2.5 hours | 32GB |
| Standard QLoRA | 0.2515 | 82-85% | 3 hours | 32GB |

**Recommendation**: Use QLoRA Optimized for best accuracy.

---

## 🔧 Prerequisites

### Local Environment
- **OS**: macOS, Linux, or Windows (WSL2)
- **Terraform**: 1.5 or higher
- **kubectl**: Latest version
- **Python**: 3.9+ with pip
- **Cloud CLI**: For cloud provider authentication

### Cloud Infrastructure
- **Account**: GPU-enabled cloud provider account (H100 support)
- **Quota**: 1x H100 GPU node minimum
- **Storage**: 50-100GB shared storage
- **Network**: VPC with subnet

---

## 📦 Installation

### 1. Clone Repository

```bash
git clone <your-repo-url>
cd nebius
```

### 2. Install Dependencies

```bash
# Install Nebius CLI (macOS)
curl -sSL https://install.cli.nebius.ai/install.sh | bash

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python packages
pip install -r requirements.txt
```

### 3. Configure Credentials

```bash
cd infra/

# Set your Nebius credentials
export NEBIUS_TENANT_ID='tenant-xxxxx'
export NEBIUS_PROJECT_ID='project-xxxxx'
export NEBIUS_REGION='eu-north1'

# Create terraform.tfvars from template
cp terraform.tfvars.example terraform.tfvars

# Edit with your SSH key
vim terraform.tfvars
```

### 4. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

See **[documentation/1_INFRASTRUCTURE_DEPLOYMENT.md](documentation/1_INFRASTRUCTURE_DEPLOYMENT.md)** for detailed steps.

---

## 🚀 Usage Examples

### Train a Model

```bash
# Apply training job
kubectl apply -f kubernetes/training-job-qlora-optimized.yaml

# Monitor progress
kubectl logs -n mlflow job/training-qlora-optimized -f

# View in MLflow
kubectl port-forward -n mlflow svc/mlflow-server 5000:5000
# Open: http://localhost:5000
```

### Run Complete Evaluation

```bash
# One command for everything
./RUN_MODEL_EVALUATION.sh \
  "qlora-optimized-qwen25-7b" \
  "Qwen/Qwen2.5-7B-Instruct" \
  "merged-qwen25-7b-finetuned"

# Results saved to:
# - results/bfcl_qwen25-7b_simple_100.json
# - results/bfcl_qwen25-7b_multiple_100.json
# - results/benchmark_qwen25-7b_*.log
```

### Test Inference API

```bash
# Port-forward vLLM
kubectl port-forward -n inference svc/vllm-serving 8000:8000 &

# Test request
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "/models/merged-qwen25-7b-finetuned",
    "prompt": "Call the get_stock_price function for AAPL",
    "max_tokens": 100
  }'
```

---

## 🧹 Cleanup

To destroy all infrastructure:

```bash
cd infra/
terraform destroy
```

**Warning**: This deletes all resources including trained models!

---

## 🐛 Troubleshooting

### Common Issues

**GPU not available:**
```bash
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'
```

**Port-forward not working:**
```bash
pkill -f "port-forward.*8000"
/tmp/portforward-wrapper.sh &
```

**Training failed:**
```bash
kubectl logs -n mlflow job/training-qlora-optimized --tail=100
kubectl describe job training-qlora-optimized -n mlflow
```

See **[docs/TROUBLESHOOTING_GUIDE.md](docs/TROUBLESHOOTING_GUIDE.md)** for complete debugging guide.

---

## 📈 Performance Optimization Tips

1. **Training**: Use gradient checkpointing to reduce memory
2. **Inference**: Enable prefix caching in vLLM
3. **Latency**: Reduce max_model_len for faster TTFT
4. **Throughput**: Increase max_num_seqs for higher QPS
5. **Cost**: Use spot instances for non-critical workloads

---

## 🤝 Contributing

This is a production deployment package. For modifications:

1. Test changes in `infra/` with `terraform plan`
2. Validate Kubernetes manifests with `kubectl apply --dry-run`
3. Update documentation in `documentation/`
4. Test complete workflow with `RUN_MODEL_EVALUATION.sh`

---

## 📄 License

This project is provided as-is for educational and demonstration purposes.

---

## 🙏 Acknowledgments

- **Axolotl** - Fine-tuning framework
- **vLLM** - Inference optimization
- **Team-ACE** - ToolACE dataset
- **Berkeley** - BFCL benchmark

---

## 📞 Support

- **Documentation**: See `documentation/` folder
- **Issues**: Check `docs/TROUBLESHOOTING_GUIDE.md`
- **Cloud Provider Docs**: Refer to your cloud provider's documentation

---

**Ready to get started?** Head to **[documentation/README.md](documentation/README.md)** for the complete guide!

---

<div align="center">

**Built for Financial AI Automation**

[Documentation](documentation/) • [Infrastructure](infra/) • [Scripts](scripts/) • [Results](results/)

</div>

