# AWS Configuration
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "fintech-llm-cluster"
}

# Kubernetes Configuration
variable "k8s_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.28"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for EKS (need at least 2). Leave empty to auto-detect."
  type        = list(string)
  default     = []  # Auto-detect from region
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway (cost savings) vs one per AZ (HA)"
  type        = bool
  default     = true  # true for demo/dev, false for production
}

# Node Group Configuration - CPU
variable "cpu_nodes_desired" {
  description = "Desired number of CPU nodes"
  type        = number
  default     = 1
}

variable "cpu_nodes_min" {
  description = "Minimum number of CPU nodes"
  type        = number
  default     = 1
}

variable "cpu_nodes_max" {
  description = "Maximum number of CPU nodes"
  type        = number
  default     = 3
}

variable "cpu_instance_types" {
  description = "Instance types for CPU nodes"
  type        = list(string)
  default     = ["t3.xlarge"] # 4 vCPU, 16GB RAM
}

# Node Group Configuration - GPU
variable "gpu_nodes_desired" {
  description = "Desired number of GPU nodes"
  type        = number
  default     = 1
}

variable "gpu_nodes_min" {
  description = "Minimum number of GPU nodes"
  type        = number
  default     = 0
}

variable "gpu_nodes_max" {
  description = "Maximum number of GPU nodes"
  type        = number
  default     = 2
}

variable "gpu_instance_types" {
  description = "Instance types for GPU nodes"
  type        = list(string)
  default     = ["p3.2xlarge"] # 1x V100 GPU, 8 vCPU, 61GB RAM
  # Options:
  # p3.2xlarge   - 1x V100 (16GB VRAM) - ~$3/hr
  # p3.8xlarge   - 4x V100 (64GB VRAM) - ~$12/hr
  # p4d.24xlarge - 8x A100 (320GB VRAM) - ~$32/hr
  # p5.48xlarge  - 8x H100 (640GB VRAM) - ~$98/hr (if available)
}

variable "gpu_disk_size" {
  description = "Disk size for GPU nodes in GB"
  type        = number
  default     = 200
}

# EFS Configuration
variable "enable_efs" {
  description = "Enable EFS for shared storage"
  type        = bool
  default     = true
}

# Tags
variable "additional_tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

# SSH Access
variable "ssh_key_name" {
  description = "Name of EC2 key pair for SSH access to nodes"
  type        = string
  default     = ""
}

# KubeRay for distributed training
variable "enable_kuberay" {
  description = "Enable KubeRay operator for distributed training"
  type        = bool
  default     = false
}

# Advanced GPU Options
variable "capacity_reservation_id" {
  description = "Capacity Reservation ID for GPU instances (for reserved/capacity block)"
  type        = string
  default     = ""
}

variable "enable_efa_support" {
  description = "Enable EFA (Elastic Fabric Adapter) for multi-GPU networking"
  type        = bool
  default     = false  # Set to true for p4d/p5 instances
}

variable "use_instance_store" {
  description = "Configure instance store (NVMe) as RAID0 for temp storage"
  type        = bool
  default     = false  # Set to true for p4d/p5 with large NVMe drives
}
