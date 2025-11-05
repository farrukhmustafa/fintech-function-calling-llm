#!/usr/bin/env python3
"""
BFCL Real Evaluation - Using Actual BFCL v3 Dataset
Evaluates fine-tuned model on real BFCL simple/multiple/parallel categories
"""

import os
import sys
import json
import time
import requests
import argparse
import re
from typing import Dict, List, Tuple, Any

def load_bfcl_dataset(filepath: str, limit: int = 100) -> List[Dict]:
    """Load parsed BFCL dataset"""
    print(f"\nLoading BFCL dataset from: {filepath}")
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    data = data[:limit]
    print(f"✓ Loaded {len(data)} samples")
    return data


def format_functions_for_prompt(functions: List[Dict]) -> str:
    """Format function definitions for the prompt"""
    formatted = []
    for func in functions:
        params_desc = []
        if 'parameters' in func and 'properties' in func['parameters']:
            for param_name, param_info in func['parameters']['properties'].items():
                param_type = param_info.get('type', 'any')
                param_desc = param_info.get('description', '')
                params_desc.append(f"  - {param_name} ({param_type}): {param_desc}")
        
        func_str = f"{func['name']}: {func.get('description', 'No description')}"
        if params_desc:
            func_str += "\n" + "\n".join(params_desc)
        formatted.append(func_str)
    
    return "\n\n".join(formatted)


def call_vllm_inference(question: str, functions: List[Dict], endpoint: str, model_name: str) -> Dict:
    """Call vLLM inference with proper formatting for Qwen model"""
    
    # Format functions
    functions_text = format_functions_for_prompt(functions)
    
    # Use Qwen chat template format (similar to ToolACE training)
    prompt = f"""<|im_start|>system
You are a helpful assistant that can call functions. When asked to perform a task, respond with a JSON function call in this format:
{{"function": "function_name", "param1": value1, "param2": value2}}

Only respond with the JSON, nothing else.<|im_end|>
<|im_start|>user
Available functions:

{functions_text}

User request: {question}

Respond with the function call in JSON format.<|im_end|>
<|im_start|>assistant
"""
    
    try:
        response = requests.post(
            f"{endpoint}/v1/completions",
            json={
                "model": model_name,
                "prompt": prompt,
                "max_tokens": 512,
                "temperature": 0.0,
                "stop": ["<|im_end|>", "<|endoftext|>", "\n\n\n"]
            },
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            return {
                "success": True,
                "text": result["choices"][0]["text"].strip()
            }
        else:
            return {
                "success": False,
                "error": f"HTTP {response.status_code}"
            }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


def extract_json_from_text(text: str) -> Dict:
    """Extract JSON object from text"""
    try:
        # Try direct JSON parse
        return json.loads(text)
    except:
        pass
    
    # Try to find JSON in text
    json_pattern = r'\{[^{}]*\}'
    matches = re.findall(json_pattern, text)
    
    for match in matches:
        try:
            return json.loads(match)
        except:
            continue
    
    # Try to extract nested JSON
    if '{' in text and '}' in text:
        start = text.find('{')
        end = text.rfind('}') + 1
        try:
            return json.loads(text[start:end])
        except:
            pass
    
    return {}


def normalize_function_name(name: str) -> str:
    """Normalize function name for comparison"""
    return name.lower().replace('_', '').replace('.', '').replace('-', '')


def evaluate_response(predicted: Dict, expected_functions: List[Dict], question: str) -> Tuple[bool, str, Dict]:
    """Evaluate if predicted response matches any expected function"""
    
    if not predicted:
        return False, "No valid JSON found", {}
    
    # Get predicted function name
    pred_func = predicted.get('function', predicted.get('name', ''))
    if not pred_func:
        return False, "No function name in response", predicted
    
    pred_func_norm = normalize_function_name(pred_func)
    
    # Check against all expected functions
    for expected_func in expected_functions:
        exp_func_name = expected_func['name']
        exp_func_norm = normalize_function_name(exp_func_name)
        
        if pred_func_norm != exp_func_norm:
            continue
        
        # Function name matches - check parameters
        # Extract parameters from response (can be at root or in "parameters" field)
        pred_params = predicted.get('parameters', predicted.get('arguments', {}))
        if not pred_params:
            pred_params = {k: v for k, v in predicted.items() if k not in ['function', 'name']}
        
        # Get expected parameters
        exp_params = expected_func.get('parameters', {}).get('properties', {})
        required_params = expected_func.get('parameters', {}).get('required', [])
        
        # Check if all required parameters are present
        missing = []
        for req_param in required_params:
            if req_param not in pred_params:
                # Try normalized names
                pred_keys_norm = {k.lower().replace('_', ''): k for k in pred_params.keys()}
                req_param_norm = req_param.lower().replace('_', '')
                
                if req_param_norm not in pred_keys_norm:
                    missing.append(req_param)
        
        if missing:
            return False, f"Missing required params: {missing}", predicted
        
        # Success!
        return True, "Correct function and parameters", predicted
    
    # Function name doesn't match any expected
    expected_names = [f['name'] for f in expected_functions]
    return False, f"Wrong function. Expected one of: {expected_names}, got: {pred_func}", predicted


def run_evaluation(dataset_path: str, endpoint: str, model_name: str, limit: int = 100, output_file: str = "results/bfcl_real_results.json"):
    """Run complete BFCL evaluation"""
    
    print("\n" + "="*70)
    print("BFCL EVALUATION - REAL DATASET")
    print("="*70)
    print(f"Dataset: {dataset_path}")
    print(f"Endpoint: {endpoint}")
    print(f"Model: {model_name}")
    print(f"Limit: {limit} samples")
    
    # Load data
    dataset = load_bfcl_dataset(dataset_path, limit)
    
    results = {
        "dataset": dataset_path,
        "total": len(dataset),
        "correct": 0,
        "incorrect": 0,
        "errors": 0,
        "details": []
    }
    
    print(f"\nEvaluating {len(dataset)} samples...")
    print("-" * 70)
    
    for i, sample in enumerate(dataset):
        print(f"[{i+1}/{len(dataset)}] ", end="", flush=True)
        
        # Extract question (it's in a nested structure)
        question_data = sample.get('question', [[]])[0]
        if question_data:
            question = question_data[0].get('content', '')
        else:
            question = ""
        
        if not question:
            print("✗ No question")
            results["errors"] += 1
            continue
        
        functions = sample.get('function', [])
        if not functions:
            print("✗ No functions")
            results["errors"] += 1
            continue
        
        # Call model
        response = call_vllm_inference(question, functions, endpoint, model_name)
        
        if not response["success"]:
            print(f"✗ API Error")
            results["errors"] += 1
            results["details"].append({
                "id": sample.get('id', f'sample_{i}'),
                "question": question,
                "error": response.get("error", "Unknown"),
                "status": "error"
            })
            continue
        
        # Parse response
        predicted = extract_json_from_text(response["text"])
        
        # Evaluate
        is_correct, message, parsed = evaluate_response(predicted, functions, question)
        
        if is_correct:
            results["correct"] += 1
            print("✓")
        else:
            results["incorrect"] += 1
            print("✗")
        
        results["details"].append({
            "id": sample.get('id', f'sample_{i}'),
            "question": question,
            "expected_functions": [f['name'] for f in functions],
            "predicted_response": response["text"],
            "parsed": parsed,
            "correct": is_correct,
            "message": message
        })
        
        # Rate limiting
        time.sleep(0.05)
    
    # Calculate metrics
    results["accuracy"] = results["correct"] / results["total"] if results["total"] > 0 else 0
    results["success_rate"] = (results["correct"] + results["incorrect"]) / results["total"] if results["total"] > 0 else 0
    
    # Save results
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    # Print summary
    print("\n" + "="*70)
    print("BFCL EVALUATION RESULTS")
    print("="*70)
    print(f"Dataset:          {os.path.basename(dataset_path)}")
    print(f"Total Samples:    {results['total']}")
    print(f"Correct:          {results['correct']}")
    print(f"Incorrect:        {results['incorrect']}")
    print(f"Errors:           {results['errors']}")
    print(f"\n📊 Accuracy:      {results['accuracy']*100:.2f}%")
    print(f"✅ Success Rate:  {results['success_rate']*100:.2f}%")
    print("="*70)
    print(f"\n✓ Detailed results saved to: {output_file}")
    
    return results


def main():
    parser = argparse.ArgumentParser(description="Run BFCL evaluation on real dataset")
    parser.add_argument("--dataset", default="data/bfcl_simple_parsed.json", help="Path to BFCL dataset")
    parser.add_argument("--endpoint", default="http://localhost:8000", help="vLLM endpoint")
    parser.add_argument("--model", default="/models/merged-qwen25-7b-finetuned", help="Model name/path")
    parser.add_argument("--limit", type=int, default=100, help="Number of samples")
    parser.add_argument("--output", default="results/bfcl_real_results.json", help="Output file")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.dataset):
        print(f"✗ Dataset not found: {args.dataset}")
        print("Please run the download script first")
        sys.exit(1)
    
    run_evaluation(args.dataset, args.endpoint, args.model, args.limit, args.output)


if __name__ == "__main__":
    main()

