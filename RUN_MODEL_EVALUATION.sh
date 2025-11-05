#!/bin/bash
set -e

# Usage: ./RUN_MODEL_EVALUATION.sh <lora_adapter_dir> <base_model_name> <output_merged_dir>
# Example: ./RUN_MODEL_EVALUATION.sh mistral-7b-optimized "mistralai/Mistral-7B-Instruct-v0.3" merged-mistral-7b-finetuned

LORA_DIR="${1:-qlora-optimized-qwen25-7b}"
BASE_MODEL="${2:-Qwen/Qwen2.5-7B-Instruct}"
MERGED_DIR="${3:-merged-qwen25-7b-finetuned}"

echo "========================================="
echo "Complete Model Evaluation Pipeline"
echo "========================================="
echo ""
echo "LoRA Adapter: $LORA_DIR"
echo "Base Model: $BASE_MODEL"
echo "Output: $MERGED_DIR"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Phase 0: Scale down vLLM to free GPU for merge
echo "========================================="
echo "PHASE 0: Preparing for Merge"
echo "========================================="
echo ""
echo "Scaling down vLLM to free GPU..."
kubectl -n inference scale deployment vllm-serving --replicas=0
sleep 5
echo "✓ vLLM scaled down"
echo ""

# Phase 1: Merge LoRA
echo "========================================="
echo "PHASE 1: Merging LoRA Adapter"
echo "========================================="
echo ""

# Check if model is already merged by checking if merge job succeeded recently
echo "Checking if model is already merged..."
RECENT_MERGE=$(kubectl -n mlflow get job merge-lora-model -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")

if [ "$RECENT_MERGE" = "1" ]; then
    echo "✓ Merge job completed successfully (assuming model exists at: $MERGED_DIR)"
    echo "  Cleaning up old merge job..."
    kubectl delete job merge-lora-model -n mlflow 2>/dev/null || true
    sleep 2
    echo "  Note: Run with fresh merge if you want to re-merge"
    echo "  Skipping merge step..."
    echo ""
else
    echo "No successful merge job found. Starting merge..."
    # Clean up any failed jobs
    kubectl delete job merge-lora-model -n mlflow 2>/dev/null || true
    sleep 2
    echo ""

cat > /tmp/merge-job.yaml << EOF
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
        command:
        - /bin/bash
        - -c
        - |
          set -ex
          echo "Installing dependencies..."
          pip install transformers peft accelerate sentencepiece protobuf -q
          
          echo "Merging LoRA adapter with base model..."
          python << 'PYTHON'
          from transformers import AutoModelForCausalLM, AutoTokenizer
          from peft import PeftModel
          import torch
          
          print("Loading base model: $BASE_MODEL")
          base_model = AutoModelForCausalLM.from_pretrained(
              "$BASE_MODEL",
              device_map="auto",
              torch_dtype=torch.bfloat16
          )
          
          print("Loading LoRA adapter from: /mnt/data/outputs/$LORA_DIR")
          model = PeftModel.from_pretrained(
              base_model,
              "/mnt/data/outputs/$LORA_DIR"
          )
          
          print("Merging...")
          merged_model = model.merge_and_unload()
          
          print("Saving merged model to: /mnt/data/outputs/$MERGED_DIR")
          merged_model.save_pretrained("/mnt/data/outputs/$MERGED_DIR")
          
          print("Saving tokenizer...")
          tokenizer = AutoTokenizer.from_pretrained("$BASE_MODEL")
          tokenizer.save_pretrained("/mnt/data/outputs/$MERGED_DIR")
          
          print("✓ Model merged successfully!")
          PYTHON
          
          echo "Model size:"
          du -sh /mnt/data/outputs/$MERGED_DIR
        volumeMounts:
        - name: data
          mountPath: /mnt/data
        resources:
          requests:
            nvidia.com/gpu: 1
            memory: 32Gi
          limits:
            nvidia.com/gpu: 1
            memory: 64Gi
      volumes:
      - name: data
        hostPath:
          path: /mnt/data
          type: DirectoryOrCreate
      nodeSelector:
        library-solution: k8s-training
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      restartPolicy: Never
  backoffLimit: 2
EOF

# Delete old merge job if exists
kubectl delete job merge-lora-model -n mlflow 2>/dev/null || true
sleep 2

# Apply merge job
kubectl apply -f /tmp/merge-job.yaml
echo "Waiting for merge to complete..."
kubectl wait --for=condition=complete job/merge-lora-model -n mlflow --timeout=600s
echo "✓ Model merged successfully"
echo ""
fi  # End of merge check

# Phase 2: Deploy to vLLM
echo "========================================="
echo "PHASE 2: Deploying to vLLM"
echo "========================================="
echo ""
echo "Scaling up vLLM with new model..."

cat > /tmp/vllm-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-serving
  namespace: inference
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-serving
  template:
    metadata:
      labels:
        app: vllm-serving
    spec:
      nodeSelector:
        library-solution: k8s-training
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        args:
        - "--model"
        - "/models/$MERGED_DIR"
        - "--port"
        - "8000"
        - "--host"
        - "0.0.0.0"
        - "--tensor-parallel-size"
        - "1"
        - "--gpu-memory-utilization"
        - "0.9"
        - "--max-model-len"
        - "4096"
        - "--enable-prefix-caching"
        - "--trust-remote-code"
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: CUDA_VISIBLE_DEVICES
          value: "0"
        resources:
          requests:
            nvidia.com/gpu: 1
            cpu: 8
            memory: 64Gi
          limits:
            nvidia.com/gpu: 1
            cpu: 16
            memory: 128Gi
        volumeMounts:
        - name: model-data
          mountPath: /models
          readOnly: true
      volumes:
      - name: model-data
        hostPath:
          path: /mnt/data/outputs
          type: Directory
EOF

kubectl apply -f /tmp/vllm-deployment.yaml
echo "Scaling vLLM to 1 replica..."
kubectl -n inference scale deployment vllm-serving --replicas=1
echo "Waiting for vLLM to be ready..."
kubectl rollout status deployment/vllm-serving -n inference --timeout=300s
echo "✓ vLLM deployment ready"
echo ""

# Phase 3: Port-forward
echo "========================================="
echo "PHASE 3: Setting up Port-Forward"
echo "========================================="
echo ""

# Setup persistent port-forward with auto-restart
echo "Setting up persistent port-forward..."

# Kill any existing port-forwards
pkill -f "port-forward.*8000" 2>/dev/null || true
sleep 2

# Create a wrapper script that auto-restarts port-forward if it crashes
cat > /tmp/portforward-wrapper.sh << 'PFSCRIPT'
#!/bin/bash
while true; do
    echo "[$(date)] Starting port-forward..." >> /tmp/vllm-pf.log
    kubectl port-forward -n inference svc/vllm-serving 8000:8000 >> /tmp/vllm-pf.log 2>&1
    echo "[$(date)] Port-forward died, restarting in 3s..." >> /tmp/vllm-pf.log
    sleep 3
done
PFSCRIPT
chmod +x /tmp/portforward-wrapper.sh

# Start the persistent port-forward wrapper in background
nohup /tmp/portforward-wrapper.sh > /dev/null 2>&1 &
PF_PID=$!
sleep 10

# Verify it started
if lsof -i:8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "✓ Persistent port-forward started (PID: $PF_PID)"
else
    echo "⚠ Port-forward failed to start. Check /tmp/vllm-pf.log"
    tail -20 /tmp/vllm-pf.log
    exit 1
fi
echo ""

# Test connection with retries
echo "Testing connection to vLLM..."
MAX_RETRIES=10
for i in $(seq 1 $MAX_RETRIES); do
    if curl -s --max-time 5 http://localhost:8000/v1/models 2>&1 | grep -q "$MERGED_DIR"; then
        echo "✓ vLLM is responding correctly with model: $MERGED_DIR"
        break
    else
        if [ $i -eq $MAX_RETRIES ]; then
            echo "⚠ vLLM not responding after $MAX_RETRIES attempts"
            echo "Response:"
            curl -s --max-time 5 http://localhost:8000/v1/models 2>&1 || echo "Connection failed"
            echo ""
            echo "Port-forward logs:"
            tail -20 /tmp/vllm-pf.log
            exit 1
        fi
        echo "  Attempt $i/$MAX_RETRIES - waiting..."
        sleep 5
    fi
done
echo ""

# Phase 4: BFCL Evaluation
echo "========================================="
echo "PHASE 4: BFCL Evaluation"
echo "========================================="
echo ""

source venv/bin/activate

MODEL_SHORTNAME=$(echo $MERGED_DIR | sed 's/merged-//' | sed 's/-finetuned//')
MODEL_PATH="/models/$MERGED_DIR"

echo "Running BFCL simple evaluation..."
python scripts/evaluate_bfcl_real.py \
  --dataset data/bfcl_simple_parsed.json \
  --model "$MODEL_PATH" \
  --limit 100 \
  --output results/bfcl_${MODEL_SHORTNAME}_simple_100.json

echo ""
echo "Running BFCL multiple evaluation..."
python scripts/evaluate_bfcl_real.py \
  --dataset data/bfcl_multiple_parsed.json \
  --model "$MODEL_PATH" \
  --limit 100 \
  --output results/bfcl_${MODEL_SHORTNAME}_multiple_100.json

echo "✓ BFCL evaluation complete"
echo ""

# Phase 5: Performance Benchmarks
echo "========================================="
echo "PHASE 5: Performance Benchmarks"
echo "========================================="
echo ""

echo "Running 16 concurrent benchmark..."
python scripts/benchmark_inference.py \
  --endpoint http://localhost:8000 \
  --model "$MODEL_PATH" \
  --requests 100 \
  --concurrent 16 \
  --model-version "$MERGED_DIR" 2>&1 | tee results/benchmark_${MODEL_SHORTNAME}_16.log

if [ -f "benchmark_results_${MERGED_DIR}_16concurrent.json" ]; then
    mv "benchmark_results_${MERGED_DIR}_16concurrent.json" results/vllm_${MODEL_SHORTNAME}_16.json
fi

echo ""
echo "Running 32 concurrent benchmark..."
python scripts/benchmark_inference.py \
  --endpoint http://localhost:8000 \
  --model "$MODEL_PATH" \
  --requests 100 \
  --concurrent 32 \
  --model-version "$MERGED_DIR" 2>&1 | tee results/benchmark_${MODEL_SHORTNAME}_32.log

if [ -f "benchmark_results_${MERGED_DIR}_32concurrent.json" ]; then
    mv "benchmark_results_${MERGED_DIR}_32concurrent.json" results/vllm_${MODEL_SHORTNAME}_32.json
fi

echo "✓ Performance benchmarks complete"
echo ""

# Final Summary
echo "========================================="
echo "✅ EVALUATION COMPLETE!"
echo "========================================="
echo ""
echo "Model: $BASE_MODEL"
echo "Results saved to results/*${MODEL_SHORTNAME}*"
echo ""
echo "BFCL Results:"
ls -lh results/bfcl_${MODEL_SHORTNAME}_*.json
echo ""
echo "Performance Results:"
ls -lh results/vllm_${MODEL_SHORTNAME}_*.json results/benchmark_${MODEL_SHORTNAME}_*.log
echo ""
echo "Port-forward PID: $PF_PID (kill $PF_PID to stop)"
echo "========================================="

