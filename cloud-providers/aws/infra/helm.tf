# Install NVIDIA Device Plugin for GPU support
resource "helm_release" "nvidia_device_plugin" {
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  namespace  = "kube-system"
  version    = "0.14.3"

  set {
    name  = "nodeSelector.node-type"
    value = "gpu"
  }

  set {
    name  = "tolerations[0].key"
    value = "nvidia.com/gpu"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [
    aws_eks_node_group.gpu
  ]
}

# Install EFS CSI Driver (if EFS is enabled)
resource "helm_release" "efs_csi_driver" {
  count = var.enable_efs ? 1 : 0

  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
  chart      = "aws-efs-csi-driver"
  namespace  = "kube-system"
  version    = "2.5.0"

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_efs_file_system.shared
  ]
}

# Create StorageClass for EFS
resource "kubernetes_storage_class" "efs" {
  count = var.enable_efs ? 1 : 0

  metadata {
    name = "efs-sc"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.shared[0].id
    directoryPerms   = "700"
  }

  depends_on = [helm_release.efs_csi_driver]
}
