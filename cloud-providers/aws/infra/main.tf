# Main EKS cluster configuration using AWS community modules
# Based on AWS best practices for GPU workloads

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

################
# EKS CLUSTER
################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_full_name
  cluster_version = var.k8s_version

  # EFA support for multi-GPU networking (optional, set to true for p4d/p5)
  enable_efa_support = var.enable_efa_support

  # Cluster access
  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true

  # Authentication
  authentication_mode = "API"

  # Logging (disabled for cost optimization, enable for production)
  cluster_enabled_log_types   = []
  create_cloudwatch_log_group = false

  # Encryption (optional, enable for production)
  cluster_encryption_config = {}

  # VPC configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # EKS Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # Node Groups
  eks_managed_node_groups = {
    # CPU node group for system workloads
    cpu = {
      name           = "${local.cluster_full_name}-cpu"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.cpu_instance_types

      min_size     = var.cpu_nodes_min
      max_size     = var.cpu_nodes_max
      desired_size = var.cpu_nodes_desired

      # Use all private subnets for HA
      subnet_ids = module.vpc.private_subnets

      labels = local.cpu_node_labels

      # SSH access (optional)
      key_name = var.ssh_key_name != "" ? var.ssh_key_name : null

      tags = merge(
        local.common_tags,
        {
          Name = "${local.cluster_full_name}-cpu-node"
        }
      )
    }

    # GPU node group for training/inference
    gpu = {
      name           = "${local.cluster_full_name}-gpu"
      ami_type       = "AL2023_x86_64_NVIDIA"  # NVIDIA drivers pre-installed
      instance_types = var.gpu_instance_types

      min_size     = var.gpu_nodes_min
      max_size     = var.gpu_nodes_max
      desired_size = var.gpu_nodes_desired

      # Use all private subnets for HA
      subnet_ids = module.vpc.private_subnets

      # Capacity reservation (optional, for reserved/capacity block instances)
      capacity_type = var.capacity_reservation_id != "" ? "CAPACITY_BLOCK" : "ON_DEMAND"

      dynamic "instance_market_options" {
        for_each = var.capacity_reservation_id != "" ? [1] : []
        content {
          market_type = "capacity-block"
        }
      }

      dynamic "capacity_reservation_specification" {
        for_each = var.capacity_reservation_id != "" ? [1] : []
        content {
          capacity_reservation_target = {
            capacity_reservation_id = var.capacity_reservation_id
          }
        }
      }

      # EFA support for multi-GPU instances (p4d, p5)
      enable_efa_support = var.enable_efa_support

      labels = merge(
        local.gpu_node_labels,
        {
          "nvidia.com/gpu.present" = "true"
        }
      )

      # GPU nodes should have taints
      taints = {
        gpu = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      # Larger disk for GPU nodes (models, datasets)
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.gpu_disk_size
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            delete_on_termination = true
            encrypted             = true
          }
        }
      }

      # Use instance store (NVMe) if available for temp storage
      # For p4d/p5 instances with large NVMe drives
      cloudinit_pre_nodeadm = var.use_instance_store ? [
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              instance:
                localStorage:
                  strategy: RAID0
          EOT
        }
      ] : []

      # SSH access (optional)
      key_name = var.ssh_key_name != "" ? var.ssh_key_name : null

      tags = merge(
        local.common_tags,
        {
          Name = "${local.cluster_full_name}-gpu-node"
        }
      )
    }
  }

  tags = local.common_tags
}

################
# VPC
################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_full_name}-vpc"
  cidr = var.vpc_cidr

  # Use availability zones from variable or auto-detect
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)

  # Auto-calculate subnets
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 64)]

  # NAT Gateway configuration
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway  # true for cost savings, false for HA

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${local.cluster_full_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${local.cluster_full_name}" = "shared"
  }

  tags = local.common_tags
}
