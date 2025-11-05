# EFS File System for shared storage (datasets, models, artifacts)
resource "aws_efs_file_system" "shared" {
  count = var.enable_efs ? 1 : 0

  creation_token = "${local.cluster_full_name}-efs"
  encrypted      = true

  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_full_name}-efs"
    }
  )
}

# EFS Mount Targets (one per AZ/subnet)
resource "aws_efs_mount_target" "shared" {
  count = var.enable_efs ? length(var.availability_zones) : 0

  file_system_id  = aws_efs_file_system.shared[0].id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs[0].id]
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  count = var.enable_efs ? 1 : 0

  name        = "${local.cluster_full_name}-efs-sg"
  description = "Allow NFS traffic from EKS nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "NFS from EKS nodes"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_full_name}-efs-sg"
    }
  )
}

# EFS CSI Driver IAM Policy
resource "aws_iam_policy" "efs_csi_driver" {
  count = var.enable_efs ? 1 : 0

  name        = "${local.cluster_full_name}-efs-csi-driver-policy"
  description = "Policy for EFS CSI driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:CreateAccessPoint",
          "elasticfilesystem:DeleteAccessPoint",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# Attach EFS CSI policy to node role
resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  count = var.enable_efs ? 1 : 0

  policy_arn = aws_iam_policy.efs_csi_driver[0].arn
  role       = aws_iam_role.node.name
}
