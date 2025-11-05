# Customer Documentation Package

**Production-ready guides for deploying and using the Nebius AI Cloud LLM Fine-Tuning Platform.**

---

## 📚 Document Overview

This documentation package contains everything needed to deploy, train, and evaluate LLMs on Nebius AI Cloud:

### 1. Infrastructure Deployment Guide
**File**: `1_INFRASTRUCTURE_DEPLOYMENT.md`

**What's covered:**
- Complete Terraform infrastructure setup
- Kubernetes cluster deployment
- GPU operator installation
- MLflow experiment tracking setup
- vLLM inference deployment
- Security best practices
- Troubleshooting common issues

**Who it's for:** DevOps engineers, infrastructure teams  
**Time to deploy:** 30-45 minutes

### 2. Model Training & Evaluation Guide
**File**: `2_MODEL_TRAINING_EVALUATION.md`

**What's covered:**
- LLM fine-tuning with QLoRA/DoRA
- LoRA adapter merging process
- vLLM deployment and configuration
- BFCL benchmark evaluation
- Performance benchmarking (TTFT, latency)
- Complete automation script reference

**Who it's for:** ML engineers, data scientists  
**Time to complete:** 4-6 hours (including training)

---

## 🚀 Quick Start Path

### For First-Time Users

**Day 1: Infrastructure Setup (1 hour)**
1. Read `1_INFRASTRUCTURE_DEPLOYMENT.md`
2. Configure your Nebius credentials
3. Deploy infrastructure with Terraform
4. Verify all components are running

**Day 2: Model Training (4-6 hours)**
1. Read `2_MODEL_TRAINING_EVALUATION.md`
2. Choose a base model and training method
3. Launch training job
4. Monitor progress in MLflow

**Day 3: Evaluation (1-2 hours)**
1. Run the complete evaluation script
2. Review BFCL accuracy results
3. Analyze performance benchmarks
4. Generate presentation materials

### For Quick Demo

If infrastructure is already deployed and you have pre-trained models:

```bash
# One command does everything
cd /path/to/nebius
./RUN_MODEL_EVALUATION.sh \
  "qlora-optimized-qwen25-7b" \
  "Qwen/Qwen2.5-7B-Instruct" \
  "merged-qwen25-7b-finetuned"
```

**Time**: ~50 minutes  
**Output**: Complete evaluation results

---

## 📊 What You Get

### Infrastructure
- ✅ Production-ready Kubernetes cluster
- ✅ 1x H100 GPU node (80GB VRAM)
- ✅ MLflow experiment tracking with PostgreSQL
- ✅ vLLM optimized inference serving
- ✅ Auto-scaling support
- ✅ Persistent storage for models

### Training Capabilities
- ✅ QLoRA 4-bit quantized fine-tuning
- ✅ DoRA (Weight-Decomposed LoRA)
- ✅ Automatic MLflow experiment logging
- ✅ Checkpoint saving every 50 steps
- ✅ Support for Qwen, Mistral, Llama models

### Evaluation & Benchmarking
- ✅ BFCL function calling accuracy tests
- ✅ Performance benchmarks (16-32 concurrent)
- ✅ TTFT (Time-to-First-Token) measurements
- ✅ End-to-end latency analysis
- ✅ Throughput metrics
- ✅ Automated report generation

---

## 🎯 Expected Results

### Model Accuracy (BFCL Benchmark)
- **Qwen2.5-7B + QLoRA Optimized**: 95-98% accuracy ⭐
- **Mistral-7B + QLoRA Optimized**: 74-80% accuracy
- **Baseline (no fine-tuning)**: ~50% accuracy

### Performance (vLLM on H100)
- **TTFT**: 200-300ms (16 concurrent)
- **Latency**: 1.4-1.6s for 200 tokens
- **Throughput**: 300-400 tokens/sec
- **Concurrent Support**: Up to 32 simultaneous requests

### Cost Efficiency
- **Training**: $2-5 per model (2-4 hours @ H100)
- **Inference**: $0.50-1.00 per hour (H100 spot pricing)
- **Storage**: Minimal (<100GB for all models)

---

## 📁 Repository Structure

```
nebius/
├── documentation/                 # 👈 Customer deliverables
│   ├── README.md                 # This file
│   ├── 1_INFRASTRUCTURE_DEPLOYMENT.md
│   └── 2_MODEL_TRAINING_EVALUATION.md
│
├── infra/                        # Terraform infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   └── ... (other .tf files)
│
├── kubernetes/                   # K8s job definitions
│   ├── training-job-qlora-optimized.yaml
│   ├── training-job-mistral-7b.yaml
│   ├── vllm-deployment.yaml
│   └── merge-lora-job.yaml
│
├── scripts/                      # Evaluation scripts
│   ├── evaluate_bfcl_real.py
│   └── benchmark_inference.py
│
├── data/                         # BFCL evaluation datasets
│   ├── bfcl_simple_parsed.json
│   └── bfcl_multiple_parsed.json
│
├── results/                      # Output directory
│   ├── bfcl_*.json              # Accuracy results
│   └── benchmark_*.log          # Performance results
│
├── RUN_MODEL_EVALUATION.sh       # Main automation script
└── docs/                         # Internal reference docs
```

---

## 🔑 Key Features

### 1. Infrastructure as Code
- Complete Terraform configuration
- Version-controlled infrastructure
- Reproducible deployments
- Easy cleanup and redeployment

### 2. MLOps Best Practices
- MLflow experiment tracking
- Automated model versioning
- Checkpoint management
- Artifact storage

### 3. Production-Ready Inference
- vLLM with PagedAttention optimization
- OpenAI-compatible API
- Auto-scaling support
- Health checks and monitoring

### 4. Comprehensive Evaluation
- Industry-standard BFCL benchmark
- Real-world function calling tests
- Performance under concurrent load
- Detailed metrics and reports

---

## 🛠️ System Requirements

### Local Machine
- **OS**: macOS, Linux, or Windows (WSL2)
- **Tools**: Terraform 1.5+, kubectl, nebius CLI
- **Python**: 3.9+ with pip
- **Disk**: 2GB for local files

### Nebius Cloud
- **Account**: Active Nebius AI Cloud account
- **Quota**: 1x H100 GPU node
- **Storage**: 50-100GB filestore
- **Network**: VPC with subnet

---

## 📞 Support & Resources

### Documentation
- **Infrastructure Guide**: Detailed Terraform setup
- **Training Guide**: Complete fine-tuning workflow
- **Troubleshooting**: Common issues and solutions

### External Resources
- [Nebius AI Cloud Docs](https://docs.nebius.com/)
- [Axolotl GitHub](https://github.com/OpenAccess-AI-Collective/axolotl)
- [vLLM Documentation](https://docs.vllm.ai/)
- [BFCL Leaderboard](https://gorilla.cs.berkeley.edu/leaderboard.html)

### Community
- Nebius AI Slack/Discord
- GitHub Issues (for bugs)
- Email support

---

## ⚠️ Important Notes

### Security
- IAM tokens expire after 12 hours
- Use port-forward for service access (not public IPs)
- Rotate SSH keys regularly
- Enable audit logging for production

### Cost Management
- Scale down GPU nodes when not in use
- Use spot instances for training
- Delete unused persistent volumes
- Monitor billing dashboard

### Data Privacy
- Training data stays in your VPC
- Models stored in your namespace
- No data sent to external services
- Compliance with data regulations

---

## 🎯 Success Criteria

After completing this guide, you should be able to:

- ✅ Deploy complete Kubernetes infrastructure on Nebius
- ✅ Fine-tune LLMs on custom datasets (ToolACE)
- ✅ Merge LoRA adapters with base models
- ✅ Deploy models to production inference serving
- ✅ Evaluate model accuracy on BFCL benchmark
- ✅ Measure and optimize inference performance
- ✅ Generate comprehensive evaluation reports

---

## 📈 Next Steps

### For Production Deployment
1. Review security hardening guide
2. Set up monitoring and alerting
3. Configure backup and disaster recovery
4. Implement CI/CD pipelines
5. Scale to multi-GPU configurations

### For Advanced Use Cases
1. Try larger models (70B+)
2. Implement custom evaluation metrics
3. Add reinforcement learning (RLHF)
4. Deploy to multiple regions
5. Build model serving APIs

---

## 📝 Document Versions

- **v1.0** (Nov 2025): Initial release
  - Complete infrastructure guide
  - Training and evaluation workflows
  - Qwen2.5 and Mistral support
  - BFCL benchmark integration

---

**Ready to get started?** Open `1_INFRASTRUCTURE_DEPLOYMENT.md` and follow the step-by-step guide!

**Questions or feedback?** Contact your Nebius support team or check the troubleshooting guide.

