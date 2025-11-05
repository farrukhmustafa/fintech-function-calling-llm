# Model Training & Evaluation Guide

**Complete guide for fine-tuning LLMs and running comprehensive evaluations on Nebius AI Cloud.**

---

## 📋 Overview

This guide covers the end-to-end workflow for:
1. Fine-tuning LLMs with QLoRA/DoRA on the ToolACE dataset
2. Merging LoRA adapters with base models
3. Deploying merged models to vLLM for inference
4. Running BFCL function calling evaluations
5. Benchmarking inference performance (TTFT, latency, throughput)

**Automation**: The `RUN_MODEL_EVALUATION.sh` script handles steps 2-5 automatically!

---

## 🎯 Training Workflow

### Dataset: Team-ACE/ToolACE
- **Purpose**: Function calling dataset for financial AI agents
- **Format**: Chat template with function definitions and calls
- **Size**: ~2,000 training examples
- **Content**: API calls, parameter extraction, multi-step reasoning

### Base Models Tested
1. **Qwen2.5-7B-Instruct** - Best accuracy (95-98% BFCL)
2. **Mistral-7B-Instruct-v0.3** - Good balance (74-80% BFCL)
3. **Llama-3.1-8B-Instruct** - Alternative option

---

## 🚀 Quick Start - Complete Evaluation Pipeline

The easiest way to train and evaluate a model:

### Option A: Use Existing Trained Model (Fastest)

If you've already trained a model (e.g., `mistral-7b-optimized`):

```bash
cd /Users/farrukhm/Downloads/nebius

# Run complete evaluation pipeline
./RUN_MODEL_EVALUATION.sh \
  "mistral-7b-optimized" \
  "mistralai/Mistral-7B-Instruct-v0.3" \
  "merged-mistral-7b-finetuned"

# Arguments:
# 1. LoRA adapter directory (in /mnt/data/outputs/)
# 2. Base model name from Hugging Face
# 3. Output merged model directory name
```

**What it does:**
1. ✅ Scales down vLLM to free GPU
2. ✅ Merges LoRA adapter with base model (~10 min)
3. ✅ Deploys merged model to vLLM (~5 min)
4. ✅ Sets up persistent port-forward
5. ✅ Runs BFCL evaluation (simple + multiple, ~15 min)
6. ✅ Runs performance benchmarks (16 + 32 concurrent, ~20 min)
7. ✅ Saves all results to `results/` directory

**Total time**: ~50 minutes  
**Output**: Complete evaluation results ready for presentation

### Option B: Train New Model First

To train a new model from scratch:

```bash
cd /Users/farrukhm/Downloads/nebius

# 1. Apply training job (starts immediately)
kubectl apply -f kubernetes/training-job-mistral-7b.yaml

# 2. Monitor training progress
kubectl logs -n mlflow job/training-mistral-7b -f

# 3. Wait for completion (2-4 hours depending on model)
kubectl wait --for=condition=complete job/training-mistral-7b -n mlflow --timeout=6h

# 4. Run evaluation pipeline
./RUN_MODEL_EVALUATION.sh \
  "mistral-7b-optimized" \
  "mistralai/Mistral-7B-Instruct-v0.3" \
  "merged-mistral-7b-finetuned"
```

---

## 📚 Detailed Training Guide

### Available Training Configurations

Three pre-configured training jobs are provided:

#### 1. QLoRA Optimized (Recommended)
```bash
kubectl apply -f kubernetes/training-job-qlora-optimized.yaml
```

**Configuration:**
- **Model**: Qwen2.5-7B-Instruct
- **Method**: QLoRA with 4-bit quantization
- **LoRA Rank**: 128 (high capacity)
- **Target**: All linear layers
- **Epochs**: 5
- **Batch Size**: 1 (gradient accumulation 16)
- **Learning Rate**: 1e-5 with cosine schedule
- **Output**: `/mnt/data/outputs/qlora-optimized-qwen25-7b`

**Results:**
- Training Loss: 0.2356
- Eval Loss: 0.2356
- BFCL Accuracy: 95-98%
- Training Time: ~3 hours

#### 2. DoRA
```bash
kubectl apply -f kubernetes/training-job-dora.yaml
```

**Configuration:**
- Similar to QLoRA but uses DoRA (Weight-Decomposed Low-Rank Adaptation)
- May converge faster but potentially lower accuracy
- Output: `/mnt/data/outputs/dora-qwen25-7b`

#### 3. Mistral-7B
```bash
kubectl apply -f kubernetes/training-job-mistral-7b.yaml
```

**Configuration:**
- Base: Mistral-7B-Instruct-v0.3
- Same QLoRA optimizations as above
- Output: `/mnt/data/outputs/mistral-7b-optimized`

**Results:**
- BFCL Accuracy: 74-80%
- Faster inference than Qwen
- Good for latency-sensitive use cases

### Monitor Training

```bash
# Watch training logs in real-time
kubectl logs -n mlflow job/training-qlora-optimized -f

# Check training status
kubectl get jobs -n mlflow

# View MLflow experiments (separate terminal)
kubectl port-forward -n mlflow svc/mlflow-server 5000:5000
# Open: http://localhost:5000
```

### Training Outputs

All training artifacts are saved to `/mnt/data/outputs/` on the GPU node:

```
/mnt/data/outputs/
├── qlora-optimized-qwen25-7b/    # LoRA adapter weights
│   ├── adapter_config.json
│   ├── adapter_model.safetensors
│   └── training_args.bin
├── mistral-7b-optimized/         # LoRA adapter weights
└── merged-qwen25-7b-finetuned/   # Full merged model (after merge job)
    ├── config.json
    ├── model.safetensors
    └── tokenizer files...
```

---

## 🔄 Model Merging Process

### Why Merge?

LoRA adapters are lightweight (few hundred MB) but inference servers like vLLM require full models. Merging combines the adapter with the base model.

### Automatic Merging (via RUN_MODEL_EVALUATION.sh)

The script handles this automatically, but here's what happens:

```python
# Pseudocode of merge process
base_model = load_model("Qwen/Qwen2.5-7B-Instruct")  # Download 15GB
lora_adapter = load_lora("/mnt/data/outputs/qlora-optimized-qwen25-7b")
merged = base_model + lora_adapter  # Merge weights
merged.save("/mnt/data/outputs/merged-qwen25-7b-finetuned")  # Save 15GB
```

**Resources:**
- GPU: 1x H100 (required for loading model)
- Memory: 32-64GB RAM
- Time: ~10 minutes
- Disk: 15GB for merged model

### Manual Merging (if needed)

```bash
# Apply merge job directly
cat > /tmp/merge-job.yaml << 'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: merge-lora-model
  namespace: mlflow
spec:
  template:
    spec:
      containers:
      - name: merge
        image: pytorch/pytorch:2.5.1-cuda12.1-cudnn9-devel
        command: ["/bin/bash", "-c"]
        args:
        - |
          pip install transformers peft accelerate sentencepiece protobuf -q
          python << 'PYTHON'
          from transformers import AutoModelForCausalLM, AutoTokenizer
          from peft import PeftModel
          import torch
          
          base = AutoModelForCausalLM.from_pretrained(
              "Qwen/Qwen2.5-7B-Instruct",
              device_map="auto", 
              torch_dtype=torch.bfloat16
          )
          model = PeftModel.from_pretrained(base, "/mnt/data/outputs/qlora-optimized-qwen25-7b")
          merged = model.merge_and_unload()
          merged.save_pretrained("/mnt/data/outputs/merged-qwen25-7b-finetuned")
          
          tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-7B-Instruct")
          tokenizer.save_pretrained("/mnt/data/outputs/merged-qwen25-7b-finetuned")
          PYTHON
        volumeMounts:
        - name: data
          mountPath: /mnt/data
        resources:
          requests:
            nvidia.com/gpu: 1
            memory: 32Gi
      volumes:
      - name: data
        hostPath:
          path: /mnt/data
      nodeSelector:
        library-solution: k8s-training
      restartPolicy: Never
EOF

kubectl apply -f /tmp/merge-job.yaml
kubectl wait --for=condition=complete job/merge-lora-model -n mlflow --timeout=30m
```

---

## 🚀 Inference Deployment (vLLM)

### Automatic Deployment (via script)

The `RUN_MODEL_EVALUATION.sh` script updates vLLM automatically to use your merged model.

### Manual Deployment

```bash
# Edit vLLM deployment to use your model
kubectl edit deployment vllm-serving -n inference

# Change this line:
#   - "--model"
#   - "/models/merged-qwen25-7b-finetuned"

# Or apply updated YAML:
kubectl apply -f kubernetes/vllm-deployment.yaml

# Wait for rollout
kubectl rollout status deployment/vllm-serving -n inference
```

### Test Inference

```bash
# Port-forward (if not already running)
kubectl port-forward -n inference svc/vllm-serving 8000:8000 &

# Test API
curl http://localhost:8000/v1/models

# Sample inference request
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "/models/merged-qwen25-7b-finetuned",
    "prompt": "What is function calling?",
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

---

## 📊 Evaluation - BFCL Benchmark

### What is BFCL?

**Berkeley Function-Calling Leaderboard** - Industry-standard benchmark for evaluating LLM function calling accuracy.

**Test Categories:**
- **Simple**: Single function calls with straightforward parameters
- **Multiple**: Multiple function calls in sequence
- **Parallel**: Concurrent function execution

### Running BFCL Evaluation

The script runs both simple and multiple evaluations automatically:

```bash
# Included in RUN_MODEL_EVALUATION.sh, or run manually:

source venv/bin/activate

# Simple function calls (100 samples)
python scripts/evaluate_bfcl_real.py \
  --dataset data/bfcl_simple_parsed.json \
  --model "/models/merged-qwen25-7b-finetuned" \
  --limit 100 \
  --output results/bfcl_qwen25-7b_simple_100.json

# Multiple function calls (100 samples)
python scripts/evaluate_bfcl_real.py \
  --dataset data/bfcl_multiple_parsed.json \
  --model "/models/merged-qwen25-7b-finetuned" \
  --limit 100 \
  --output results/bfcl_qwen25-7b_multiple_100.json
```

### Understanding Results

```json
{
  "dataset": "bfcl_simple_parsed.json",
  "total": 100,
  "correct": 95,
  "incorrect": 5,
  "errors": 0,
  "accuracy": 0.95,
  "success_rate": 1.0
}
```

**Metrics:**
- **Accuracy**: % of correct function calls (most important)
- **Success Rate**: % of requests that didn't error
- **Errors**: API failures or timeouts

**Target Accuracy:**
- **Excellent**: >90% (Qwen2.5-7B achieved 95-98%)
- **Good**: 70-90% (Mistral-7B achieved 74-80%)
- **Needs Improvement**: <70%

---

## ⚡ Performance Benchmarking

### Metrics Measured

1. **TTFT (Time-to-First-Token)**
   - Time from request to first token generation
   - Critical for user experience
   - **Target**: <500ms

2. **End-to-End Latency**
   - Total time to complete request
   - Includes full response generation
   - **Target**: <2000ms for 200 tokens

3. **Throughput**
   - Tokens per second
   - Requests per second
   - **Target**: >100 tokens/sec under load

### Running Benchmarks

```bash
# Included in RUN_MODEL_EVALUATION.sh, or run manually:

source venv/bin/activate

# Test with 16 concurrent requests (100 total)
python scripts/benchmark_inference.py \
  --endpoint http://localhost:8000 \
  --model "/models/merged-qwen25-7b-finetuned" \
  --requests 100 \
  --concurrent 16 \
  --model-version "qwen25-7b"

# Test with 32 concurrent requests
python scripts/benchmark_inference.py \
  --endpoint http://localhost:8000 \
  --model "/models/merged-qwen25-7b-finetuned" \
  --requests 100 \
  --concurrent 32 \
  --model-version "qwen25-7b"
```

### Sample Results

```
============================================================
BENCHMARK RESULTS
============================================================
Requests: 100/100 successful

📊 Time-to-First-Token (TTFT):
  Mean:    245.82 ms
  Median:  238.15 ms
  P95:     312.44 ms
  P99:     401.23 ms

⏱️  End-to-End Latency:
  Mean:    1456.73 ms
  Median:  1422.11 ms
  P95:     1888.92 ms
  P99:     2105.33 ms

🚀 Throughput:
  Tokens/sec: 342.15
  Requests/sec: 12.34

✅ Performance Targets:
  TTFT < 500ms: ✓
  Latency < 2s: ✓
============================================================
```

---

## 📁 Results Structure

After running evaluations, results are saved to:

```
results/
├── bfcl_qwen25-7b_simple_100.json       # BFCL simple accuracy
├── bfcl_qwen25-7b_multiple_100.json     # BFCL multiple accuracy
├── bfcl_mistral-7b_simple_100.json      # Mistral BFCL simple
├── bfcl_mistral-7b_multiple_100.json    # Mistral BFCL multiple
├── vllm_qwen25-7b_16.json               # Performance (16 concurrent)
├── vllm_qwen25-7b_32.json               # Performance (32 concurrent)
├── benchmark_qwen25-7b_16.log           # Detailed benchmark logs
└── benchmark_qwen25-7b_32.log           # Detailed benchmark logs
```

---

## 🎯 Model Comparison

### Qwen2.5-7B (Recommended)
- **BFCL Accuracy**: 95-98%
- **TTFT**: ~245ms
- **Latency**: ~1.4s
- **Training Time**: ~3 hours
- **Best for**: Maximum accuracy

### Mistral-7B
- **BFCL Accuracy**: 74-80%
- **TTFT**: ~880ms
- **Latency**: ~2.2s
- **Training Time**: ~2.5 hours
- **Best for**: Balanced performance

### Training Method Comparison
- **QLoRA Optimized**: Best accuracy (recommended)
- **DoRA**: Faster convergence, slightly lower accuracy
- **Standard QLoRA**: Good baseline

---

## 🔧 Advanced Usage

### Custom Training Configuration

To create your own training job:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: training-custom
  namespace: mlflow
spec:
  template:
    spec:
      containers:
      - name: axolotl
        image: pytorch/pytorch:2.5.1-cuda12.1-cudnn9-devel
        command: ["/bin/bash", "-c"]
        args:
        - |
          pip install axolotl[flash-attn,deepspeed] mlflow -q
          
          cat > /workspace/config.yaml << 'CONFIG'
          base_model: Qwen/Qwen2.5-7B-Instruct
          model_type: Qwen2ForCausalLM
          
          datasets:
            - path: Team-ACE/ToolACE
              type: chat_template
              chat_template: chatml
              field_messages: conversations
              message_field_role: from
              message_field_content: value
          
          adapter: qlora
          lora_r: 128
          lora_alpha: 256
          lora_target_modules: all-linear
          
          # Add your custom hyperparameters here
          num_epochs: 5
          micro_batch_size: 1
          gradient_accumulation_steps: 16
          learning_rate: 0.00001
          
          output_dir: /mnt/data/outputs/custom-model
          CONFIG
          
          accelerate launch -m axolotl.cli.train /workspace/config.yaml
        volumeMounts:
        - name: data
          mountPath: /mnt/data
        resources:
          requests:
            nvidia.com/gpu: 1
      volumes:
      - name: data
        hostPath:
          path: /mnt/data
      nodeSelector:
        library-solution: k8s-training
      restartPolicy: Never
```

### Debug Failed Training

```bash
# Check job status
kubectl get jobs -n mlflow

# View logs
kubectl logs -n mlflow job/training-qlora-optimized

# Describe job for events
kubectl describe job training-qlora-optimized -n mlflow

# Check GPU allocation
kubectl describe pod -n mlflow -l job-name=training-qlora-optimized | grep nvidia.com/gpu
```

---

## 🐛 Troubleshooting

### Port-Forward Not Working

```bash
# Kill existing port-forwards
pkill -f "port-forward.*8000"

# Restart wrapper script
/tmp/portforward-wrapper.sh &

# Check logs
tail -f /tmp/vllm-pf.log
```

### Evaluation Script Errors

```bash
# Ensure virtual environment is activated
source venv/bin/activate

# Install missing dependencies
pip install datasets mlflow transformers requests

# Test connection
curl http://localhost:8000/v1/models
```

### Model Not Found Error

```bash
# Check if merge completed
kubectl logs -n mlflow job/merge-lora-model --tail=50

# Verify model exists on node
kubectl exec -n mlflow storage-checker -- ls -lh /mnt/data/outputs/

# Check vLLM is using correct path
kubectl get deployment vllm-serving -n inference -o yaml | grep model
```

---

## 📈 Best Practices

### Training
1. Start with QLoRA Optimized configuration
2. Monitor training in MLflow UI
3. Check eval_loss convergence
4. Save checkpoints every 50 steps

### Evaluation
1. Always evaluate on the same dataset splits
2. Run multiple evaluation runs for consistency
3. Compare across different model sizes
4. Document hyperparameter changes

### Production
1. Use merged models for inference
2. Set appropriate resource limits
3. Enable auto-scaling for production load
4. Monitor GPU memory utilization
5. Set up alerts for high latency

---

## 📚 Additional Resources

- **Axolotl Docs**: https://github.com/OpenAccess-AI-Collective/axolotl
- **vLLM Docs**: https://docs.vllm.ai/
- **BFCL Leaderboard**: https://gorilla.cs.berkeley.edu/leaderboard.html
- **ToolACE Dataset**: https://huggingface.co/datasets/Team-ACE/ToolACE

---

## 🎓 Script Reference

### RUN_MODEL_EVALUATION.sh

**Purpose**: End-to-end evaluation pipeline from LoRA adapter to benchmark results.

**Usage:**
```bash
./RUN_MODEL_EVALUATION.sh <lora_dir> <base_model> <output_dir>
```

**Example:**
```bash
./RUN_MODEL_EVALUATION.sh \
  "qlora-optimized-qwen25-7b" \
  "Qwen/Qwen2.5-7B-Instruct" \
  "merged-qwen25-7b-finetuned"
```

**Phases:**
1. **Phase 0**: Scale down vLLM (free GPU)
2. **Phase 1**: Merge LoRA adapter (~10 min)
3. **Phase 2**: Deploy merged model to vLLM (~5 min)
4. **Phase 3**: Setup persistent port-forward
5. **Phase 4**: Run BFCL evaluations (~15 min)
6. **Phase 5**: Run performance benchmarks (~20 min)

**Output**: All results saved to `results/` directory.

---

**Questions?** Check the main troubleshooting guide in `docs/TROUBLESHOOTING_GUIDE.md`.

