#!/usr/bin/env python3
"""
Benchmark Triton Inference Server Performance
Measures TTFT, latency, and throughput for 16-32 concurrent requests
"""

import argparse
import time
import json
import statistics
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests
import numpy as np

def send_inference_request(triton_url, model_name, prompt, max_tokens=100, request_id=0):
    """Send inference request to Triton"""
    start_time = time.time()
    
    # Triton HTTP/REST API format
    payload = {
        "inputs": [
            {
                "name": "prompt",
                "shape": [1],
                "datatype": "BYTES",
                "data": [prompt]
            },
            {
                "name": "max_tokens",
                "shape": [1],
                "datatype": "INT32",
                "data": [max_tokens]
            }
        ]
    }
    
    try:
        response = requests.post(
            f"{triton_url}/v2/models/{model_name}/infer",
            json=payload,
            timeout=60
        )
        
        end_time = time.time()
        latency = (end_time - start_time) * 1000  # Convert to ms
        
        if response.status_code == 200:
            result = response.json()
            # Parse output
            generated_text = result.get("outputs", [{}])[0].get("data", [""])[0]
            
            return {
                "success": True,
                "latency_ms": latency,
                "ttft_ms": latency,  # For Triton, TTFT ~= latency (no streaming in this example)
                "request_id": request_id,
                "generated_text": generated_text,
                "tokens": len(generated_text.split())  # Rough token estimate
            }
        else:
            return {
                "success": False,
                "latency_ms": latency,
                "error": f"Status {response.status_code}: {response.text}",
                "request_id": request_id
            }
    except Exception as e:
        end_time = time.time()
        return {
            "success": False,
            "latency_ms": (end_time - start_time) * 1000,
            "error": str(e),
            "request_id": request_id
        }

def benchmark_concurrency(triton_url, model_name, concurrency, num_requests, prompts):
    """Benchmark at a specific concurrency level"""
    print(f"\n{'='*60}")
    print(f"Benchmarking with {concurrency} concurrent requests")
    print(f"{'='*60}")
    
    results = []
    start_time = time.time()
    
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = []
        for i in range(num_requests):
            prompt = prompts[i % len(prompts)]
            future = executor.submit(
                send_inference_request,
                triton_url,
                model_name,
                prompt,
                100,
                i
            )
            futures.append(future)
        
        # Collect results
        for future in as_completed(futures):
            result = future.result()
            results.append(result)
            if result["success"]:
                print(f"✓ Request {result['request_id']}: {result['latency_ms']:.0f}ms")
            else:
                print(f"✗ Request {result['request_id']}: {result.get('error', 'Unknown error')}")
    
    end_time = time.time()
    total_time = end_time - start_time
    
    # Calculate metrics
    successful = [r for r in results if r["success"]]
    failed = [r for r in results if not r["success"]]
    
    if not successful:
        print(f"\n⚠ All requests failed at concurrency {concurrency}")
        return None
    
    latencies = [r["latency_ms"] for r in successful]
    ttfts = [r["ttft_ms"] for r in successful]
    total_tokens = sum(r.get("tokens", 0) for r in successful)
    
    metrics = {
        "concurrency": concurrency,
        "total_requests": num_requests,
        "successful_requests": len(successful),
        "failed_requests": len(failed),
        "total_time_seconds": total_time,
        "requests_per_second": len(successful) / total_time,
        "tokens_per_second": total_tokens / total_time,
        "latency": {
            "min_ms": min(latencies),
            "max_ms": max(latencies),
            "mean_ms": statistics.mean(latencies),
            "median_ms": statistics.median(latencies),
            "p50_ms": np.percentile(latencies, 50),
            "p90_ms": np.percentile(latencies, 90),
            "p95_ms": np.percentile(latencies, 95),
            "p99_ms": np.percentile(latencies, 99),
            "stddev_ms": statistics.stdev(latencies) if len(latencies) > 1 else 0
        },
        "ttft": {
            "min_ms": min(ttfts),
            "max_ms": max(ttfts),
            "mean_ms": statistics.mean(ttfts),
            "median_ms": statistics.median(ttfts),
            "p50_ms": np.percentile(ttfts, 50),
            "p90_ms": np.percentile(ttfts, 90),
            "p95_ms": np.percentile(ttfts, 95),
            "p99_ms": np.percentile(ttfts, 99)
        }
    }
    
    # Print summary
    print(f"\n{'─'*60}")
    print(f"Results for Concurrency {concurrency}:")
    print(f"{'─'*60}")
    print(f"  Total Requests:     {metrics['total_requests']}")
    print(f"  Successful:         {metrics['successful_requests']}")
    print(f"  Failed:             {metrics['failed_requests']}")
    print(f"  Success Rate:       {100 * metrics['successful_requests'] / metrics['total_requests']:.1f}%")
    print(f"  Total Time:         {metrics['total_time_seconds']:.2f}s")
    print(f"  Throughput:         {metrics['requests_per_second']:.2f} req/s")
    print(f"  Token Throughput:   {metrics['tokens_per_second']:.1f} tokens/s")
    print(f"\n  Latency:")
    print(f"    Min:              {metrics['latency']['min_ms']:.0f}ms")
    print(f"    Mean:             {metrics['latency']['mean_ms']:.0f}ms")
    print(f"    Median (P50):     {metrics['latency']['p50_ms']:.0f}ms")
    print(f"    P90:              {metrics['latency']['p90_ms']:.0f}ms")
    print(f"    P95:              {metrics['latency']['p95_ms']:.0f}ms")
    print(f"    P99:              {metrics['latency']['p99_ms']:.0f}ms")
    print(f"    Max:              {metrics['latency']['max_ms']:.0f}ms")
    print(f"\n  Time to First Token (TTFT):")
    print(f"    Mean:             {metrics['ttft']['mean_ms']:.0f}ms")
    print(f"    Median (P50):     {metrics['ttft']['p50_ms']:.0f}ms")
    print(f"    P95:              {metrics['ttft']['p95_ms']:.0f}ms")
    
    return metrics

def main():
    parser = argparse.ArgumentParser(description="Benchmark Triton Inference Server")
    parser.add_argument("--triton_url", default="http://localhost:8000", help="Triton server URL")
    parser.add_argument("--model", default="qwen-function-calling", help="Model name")
    parser.add_argument("--concurrency", default="1,8,16,24,32", help="Comma-separated concurrency levels")
    parser.add_argument("--num_requests", type=int, default=100, help="Number of requests per concurrency")
    parser.add_argument("--output_file", default="results/triton_performance.json", help="Output JSON file")
    
    args = parser.parse_args()
    
    # Test prompts for function calling
    prompts = [
        "Call the get_weather function for San Francisco",
        "Execute get_stock_price for AAPL ticker",
        "Call send_email with recipient john@example.com and subject 'Meeting'",
        "Run calculate_tax for income 75000 and state CA",
        "Execute create_invoice with customer_id 12345 and amount 599.99",
        "Call search_database for query 'recent transactions'",
        "Run validate_transaction with transaction_id tx_98765",
        "Execute get_user_info for user_id 5432",
        "Call process_payment with amount 299.50 and currency USD",
        "Run generate_report for date_range last_30_days"
    ]
    
    print("="*60)
    print("Triton Inference Server Performance Benchmark")
    print("="*60)
    print(f"Triton URL:      {args.triton_url}")
    print(f"Model:           {args.model}")
    print(f"Requests/level:  {args.num_requests}")
    print(f"Concurrency:     {args.concurrency}")
    
    # Test connection
    print("\nTesting Triton connection...")
    try:
        response = requests.get(f"{args.triton_url}/v2/health/ready", timeout=5)
        if response.status_code == 200:
            print("✓ Triton server is ready")
        else:
            print(f"⚠ Triton returned status {response.status_code}")
    except Exception as e:
        print(f"✗ Cannot connect to Triton: {e}")
        return
    
    # Parse concurrency levels
    concurrency_levels = [int(c.strip()) for c in args.concurrency.split(",")]
    
    # Run benchmarks
    all_results = {}
    for concurrency in concurrency_levels:
        metrics = benchmark_concurrency(
            args.triton_url,
            args.model,
            concurrency,
            args.num_requests,
            prompts
        )
        if metrics:
            all_results[f"concurrency_{concurrency}"] = metrics
    
    # Save results
    import os
    os.makedirs(os.path.dirname(args.output_file) if os.path.dirname(args.output_file) else ".", exist_ok=True)
    
    with open(args.output_file, "w") as f:
        json.dump(all_results, f, indent=2)
    
    print(f"\n{'='*60}")
    print(f"✓ Results saved to: {args.output_file}")
    print(f"{'='*60}")
    
    # Print comparison table
    print("\n" + "="*80)
    print("PERFORMANCE COMPARISON TABLE")
    print("="*80)
    print(f"{'Concurrency':<15} {'Throughput':<15} {'Mean Latency':<15} {'P95 Latency':<15} {'TTFT P95':<15}")
    print("-"*80)
    for key, metrics in all_results.items():
        conc = metrics['concurrency']
        throughput = f"{metrics['requests_per_second']:.1f} req/s"
        mean_lat = f"{metrics['latency']['mean_ms']:.0f}ms"
        p95_lat = f"{metrics['latency']['p95_ms']:.0f}ms"
        ttft_p95 = f"{metrics['ttft']['p95_ms']:.0f}ms"
        print(f"{conc:<15} {throughput:<15} {mean_lat:<15} {p95_lat:<15} {ttft_p95:<15}")
    print("="*80)

if __name__ == "__main__":
    main()

