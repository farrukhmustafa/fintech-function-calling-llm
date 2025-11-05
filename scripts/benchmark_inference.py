#!/usr/bin/env python3
"""
Inference Benchmarking Script
Measures TTFT (time-to-first-token) and latency for concurrent requests
Tests 16-32 concurrent requests as required
"""

import asyncio
import aiohttp
import time
import json
import statistics
import argparse
from typing import List, Tuple
# import mlflow  # Not needed for benchmarking
import os

VLLM_ENDPOINT = os.getenv("VLLM_ENDPOINT", "http://vllm-serving.inference.svc.cluster.local:8000/v1")


async def single_request(
    session: aiohttp.ClientSession,
    request_id: int,
    prompt: str,
    endpoint: str,
    model_name: str,
    stream: bool = True
) -> Tuple[int, float, float, int]:
    """
    Make single inference request and measure metrics
    Returns: (request_id, ttft, latency, tokens_received)
    """
    start_time = time.time()
    ttft = None
    tokens_received = 0
    
    try:
        if stream:
            # Streaming request to measure TTFT
            async with session.post(
                f"{endpoint}/v1/completions",
                json={
                    "model": model_name,
                    "prompt": prompt,
                    "max_tokens": 200,
                    "temperature": 0.7,
                    "stream": True
                },
                timeout=aiohttp.ClientTimeout(total=120)
            ) as response:
                response.raise_for_status()
                
                async for line in response.content:
                    if line:
                        if ttft is None:
                            ttft = time.time() - start_time
                        tokens_received += 1
                
        else:
            # Non-streaming request
            async with session.post(
                f"{endpoint}/v1/completions",
                json={
                    "model": model_name,
                    "prompt": prompt,
                    "max_tokens": 200,
                    "temperature": 0.7
                },
                timeout=aiohttp.ClientTimeout(total=120)
            ) as response:
                response.raise_for_status()
                result = await response.json()
                ttft = time.time() - start_time  # Approximate for non-streaming
                tokens_received = len(result.get("choices", [{}])[0].get("text", "").split())
        
        total_latency = time.time() - start_time
        
        if ttft is None:
            ttft = total_latency
        
        return (request_id, ttft, total_latency, tokens_received)
        
    except Exception as e:
        print(f"✗ Request {request_id} failed: {e}")
        return (request_id, None, None, 0)


async def benchmark(
    endpoint: str,
    model_name: str,
    num_requests: int,
    concurrent: int,
    prompt: str = "What is function calling in AI? Explain how LLMs can call functions.",
    stream: bool = True
) -> List[Tuple[int, float, float, int]]:
    """
    Run benchmark with specified number of concurrent requests
    """
    print(f"\n{'='*60}")
    print(f"Benchmarking Inference Performance")
    print(f"{'='*60}")
    print(f"Endpoint: {endpoint}")
    print(f"Model: {model_name}")
    print(f"Total requests: {num_requests}")
    print(f"Concurrent requests: {concurrent}")
    print(f"Streaming: {stream}")
    print(f"{'='*60}\n")
    
    async with aiohttp.ClientSession() as session:
        # Create semaphore to limit concurrency
        semaphore = asyncio.Semaphore(concurrent)
        
        async def bounded_request(request_id):
            async with semaphore:
                return await single_request(session, request_id, prompt, endpoint, model_name, stream)
        
        # Run all requests
        tasks = [bounded_request(i) for i in range(num_requests)]
        results = await asyncio.gather(*tasks)
    
    return results


def calculate_metrics(results: List[Tuple[int, float, float, int]]) -> dict:
    """Calculate statistics from results"""
    # Filter out failed requests
    valid_results = [r for r in results if r[1] is not None and r[2] is not None]
    
    if not valid_results:
        return {"error": "No successful requests"}
    
    ttft_values = [r[1] for r in valid_results]
    latency_values = [r[2] for r in valid_results]
    tokens = [r[3] for r in valid_results]
    
    metrics = {
        "total_requests": len(results),
        "successful_requests": len(valid_results),
        "failed_requests": len(results) - len(valid_results),
        
        # TTFT (Time-to-First-Token) metrics
        "ttft_mean": statistics.mean(ttft_values),
        "ttft_median": statistics.median(ttft_values),
        "ttft_p95": statistics.quantiles(ttft_values, n=20)[18] if len(ttft_values) > 1 else ttft_values[0],
        "ttft_p99": statistics.quantiles(ttft_values, n=100)[98] if len(ttft_values) > 1 else ttft_values[0],
        "ttft_min": min(ttft_values),
        "ttft_max": max(ttft_values),
        
        # Latency (end-to-end) metrics
        "latency_mean": statistics.mean(latency_values),
        "latency_median": statistics.median(latency_values),
        "latency_p95": statistics.quantiles(latency_values, n=20)[18] if len(latency_values) > 1 else latency_values[0],
        "latency_p99": statistics.quantiles(latency_values, n=100)[98] if len(latency_values) > 1 else latency_values[0],
        "latency_min": min(latency_values),
        "latency_max": max(latency_values),
        
        # Throughput
        "tokens_per_second_mean": statistics.mean([t / l for t, l in zip(tokens, latency_values) if l > 0]),
        "requests_per_second": len(valid_results) / max(latency_values) if latency_values else 0,
    }
    
    return metrics


def print_results(metrics: dict):
    """Print benchmark results"""
    print(f"\n{'='*60}")
    print("BENCHMARK RESULTS")
    print(f"{'='*60}")
    print(f"Requests: {metrics['successful_requests']}/{metrics['total_requests']} successful")
    
    print(f"\n📊 Time-to-First-Token (TTFT):")
    print(f"  Mean:    {metrics['ttft_mean']*1000:.2f} ms")
    print(f"  Median:  {metrics['ttft_median']*1000:.2f} ms")
    print(f"  P95:     {metrics['ttft_p95']*1000:.2f} ms")
    print(f"  P99:     {metrics['ttft_p99']*1000:.2f} ms")
    print(f"  Min:     {metrics['ttft_min']*1000:.2f} ms")
    print(f"  Max:     {metrics['ttft_max']*1000:.2f} ms")
    
    print(f"\n⏱️  End-to-End Latency:")
    print(f"  Mean:    {metrics['latency_mean']*1000:.2f} ms")
    print(f"  Median:  {metrics['latency_median']*1000:.2f} ms")
    print(f"  P95:     {metrics['latency_p95']*1000:.2f} ms")
    print(f"  P99:     {metrics['latency_p99']*1000:.2f} ms")
    print(f"  Min:     {metrics['latency_min']*1000:.2f} ms")
    print(f"  Max:     {metrics['latency_max']*1000:.2f} ms")
    
    print(f"\n🚀 Throughput:")
    print(f"  Tokens/sec: {metrics['tokens_per_second_mean']:.2f}")
    print(f"  Requests/sec: {metrics['requests_per_second']:.2f}")
    
    # Check against targets
    print(f"\n✅ Performance Targets:")
    ttft_ok = metrics['ttft_mean'] < 0.5
    latency_ok = metrics['latency_mean'] < 2.0
    print(f"  TTFT < 500ms: {'✓' if ttft_ok else '✗'} ({metrics['ttft_mean']*1000:.2f} ms)")
    print(f"  Latency < 2s: {'✓' if latency_ok else '✗'} ({metrics['latency_mean']*1000:.2f} ms)")
    
    print(f"{'='*60}\n")


def main():
    parser = argparse.ArgumentParser(description="Benchmark inference performance")
    parser.add_argument(
        "--endpoint",
        default=VLLM_ENDPOINT,
        help="vLLM endpoint URL"
    )
    parser.add_argument(
        "--requests",
        type=int,
        default=32,
        help="Total number of requests"
    )
    parser.add_argument(
        "--concurrent",
        type=int,
        default=16,
        choices=[16, 32],
        help="Number of concurrent requests (16 or 32)"
    )
    parser.add_argument(
        "--prompt",
        default="What is function calling? Explain how to use LLMs for API calls.",
        help="Test prompt"
    )
    parser.add_argument(
        "--no-stream",
        action="store_true",
        help="Disable streaming (for comparison)"
    )
    parser.add_argument(
        "--model-version",
        default="qlora",
        help="Model version being benchmarked"
    )
    parser.add_argument(
        "--model",
        default="/models/merged-qwen25-7b-finetuned",
        help="Model name/path for inference"
    )
    
    args = parser.parse_args()
    
    # Setup MLflow
    # mlflow_uri = os.getenv("MLFLOW_TRACKING_URI", "http://mlflow-server.mlflow.svc.cluster.local:5000")
    # mlflow.set_tracking_uri(mlflow_uri)
    # mlflow.set_experiment("inference-benchmarking")
    
    # Run benchmark
    results = asyncio.run(
        benchmark(
            args.endpoint,
            args.model,
            args.requests,
            args.concurrent,
            args.prompt,
            stream=not args.no_stream
        )
    )
    
    # Calculate metrics
    metrics = calculate_metrics(results)
    
    if "error" in metrics:
        print(f"✗ {metrics['error']}")
        return
    
    # Print results
    print_results(metrics)
    
    # Log to MLflow
    # with mlflow.start_run(run_name=f"benchmark-{args.model_version}-{args.concurrent}concurrent"):
    #     mlflow.log_param("model_version", args.model_version)
    #     mlflow.log_param("concurrent_requests", args.concurrent)
    #     mlflow.log_param("total_requests", args.requests)
    #     mlflow.log_param("endpoint", args.endpoint)
    #     mlflow.log_param("streaming", not args.no_stream)
    #     
    #     # Log all metrics
    #     for key, value in metrics.items():
    #         if isinstance(value, (int, float)):
    #             mlflow.log_metric(key, value)
        
    # print("✓ Results logged to MLflow")
    
    # Save results
    results_file = f"benchmark_results_{args.model_version}_{args.concurrent}concurrent.json"
    with open(results_file, "w") as f:
        json.dump(metrics, f, indent=2)
    
    print(f"✓ Results saved to {results_file}")
    #print(f"✓ View in MLflow: {mlflow_uri}")


if __name__ == "__main__":
    main()

