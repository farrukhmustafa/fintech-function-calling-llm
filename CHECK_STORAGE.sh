#!/bin/bash
# Quick commands to check filesystem storage

echo "=== STORAGE CHECK COMMANDS ==="
echo ""
echo "1. Check training storage (via storage-checker pod):"
echo "   kubectl exec -n mlflow storage-checker -- df -h /mnt/data"
echo "   kubectl exec -n mlflow storage-checker -- du -sh /mnt/data/*"
echo ""
echo "2. Check inference/model storage (via vLLM pod):"
echo "   VLLM_POD=\$(kubectl -n inference get pod -l app=vllm-serving -o jsonpath='{.items[0].metadata.name}')"
echo "   kubectl -n inference exec \$VLLM_POD -- df -h /models"
echo "   kubectl -n inference exec \$VLLM_POD -- du -sh /models/*"
echo ""
echo "3. If storage-checker pod doesn't exist:"
echo "   kubectl apply -f kubernetes/storage-checker-pod.yaml"
echo ""
echo "4. Full breakdown (copy-paste ready):"
cat << 'COMMANDS'

# Training storage
kubectl exec -n mlflow storage-checker -- sh -c 'df -h /mnt/data && echo "" && du -sh /mnt/data/* 2>/dev/null'

# Model storage  
VLLM_POD=$(kubectl -n inference get pod -l app=vllm-serving -o jsonpath='{.items[0].metadata.name}')
kubectl -n inference exec $VLLM_POD -- sh -c 'df -h /models && echo "" && du -sh /models/* | sort -h'

COMMANDS
echo ""
echo "=== CURRENT STATUS ==="
echo ""

# Try to run the commands
echo "Training storage:"
kubectl exec -n mlflow storage-checker -- df -h /mnt/data 2>/dev/null || echo "⚠️  storage-checker pod not running (use: kubectl apply -f kubernetes/storage-checker-pod.yaml)"

echo ""
echo "Model storage:"
VLLM_POD=$(kubectl -n inference get pod -l app=vllm-serving -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$VLLM_POD" ]; then
    kubectl -n inference exec $VLLM_POD -- df -h /models 2>/dev/null
else
    echo "⚠️  vLLM pod not running"
fi

