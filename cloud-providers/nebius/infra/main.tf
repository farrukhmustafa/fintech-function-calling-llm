resource "nebius_mk8s_v1_cluster" "k8s-cluster" {
  parent_id = var.parent_id
  name      = join("-", ["k8s-training", local.release-suffix])
  control_plane = {
    endpoints = {
      public_endpoint = {}
    }
    etcd_cluster_size = var.etcd_cluster_size
    # Use created subnet if subnet_id not provided, otherwise use provided one
    subnet_id = var.subnet_id != "" ? var.subnet_id : nebius_vpc_v1_subnet.training_subnet.id
    version   = var.k8s_version
  }
  
  # Configure Kubernetes network with smaller CIDR for demo
  # Use /24 prefix length for services (256 IPs) instead of default /16
  # This allows Nebius to auto-allocate a smaller CIDR from available pool
  kube_network = {
    service_cidrs = ["/24"]  # Use prefix length - Nebius will auto-allocate
  }
}

data "nebius_iam_v1_group" "editors" {
  count     = var.enable_k8s_node_group_sa ? 1 : 0
  name      = "editors"
  parent_id = var.tenant_id
}

resource "nebius_iam_v1_service_account" "k8s_node_group_sa" {
  count     = var.enable_k8s_node_group_sa ? 1 : 0
  parent_id = var.parent_id
  name      = join("-", ["k8s_node_group_sa", local.release-suffix])
}

resource "nebius_iam_v1_group_membership" "k8s_node_group_sa-admin" {
  count     = var.enable_k8s_node_group_sa ? 1 : 0
  parent_id = data.nebius_iam_v1_group.editors[0].id
  member_id = nebius_iam_v1_service_account.k8s_node_group_sa[count.index].id
}

################
# CPU NODE GROUP
################
resource "nebius_mk8s_v1_node_group" "cpu-only" {
  fixed_node_count = var.cpu_nodes_count
  parent_id        = nebius_mk8s_v1_cluster.k8s-cluster.id
  name             = join("-", ["k8s-ng-cpu", local.release-suffix])
  labels = {
    "library-solution" = "k8s-training"
  }
  version = var.k8s_version
  template = {
    boot_disk = {
      size_gibibytes = var.cpu_disk_size
      type           = var.cpu_disk_type
    }

    service_account_id = var.enable_k8s_node_group_sa ? nebius_iam_v1_service_account.k8s_node_group_sa[0].id : null

    network_interfaces = [
      {
        public_ip_address = {}
        subnet_id = var.subnet_id != "" ? var.subnet_id : nebius_vpc_v1_subnet.training_subnet.id
      }
    ]
    resources = {
      platform = local.cpu_nodes_platform
      preset   = local.cpu_nodes_preset
    }
    preemptible = var.cpu_nodes_preemptible ? {
      on_preemption = "STOP"
      priority      = 1
    } : null
    filesystems = var.enable_filestore ? [
      {
        attach_mode         = "READ_WRITE"
        mount_tag           = "data"
        existing_filesystem = nebius_compute_v1_filesystem.shared-filesystem[0]
      }
    ] : null
    underlay_required = false
    metadata = {
      ssh-keys = "${var.ssh_user_name}:${local.ssh_public_key}"
    }
  }
}

#################
# GPU NODE GROUPS
#################
resource "nebius_mk8s_v1_node_group" "gpu" {
  count            = var.gpu_node_groups
  fixed_node_count = var.gpu_nodes_count_per_group
  parent_id        = nebius_mk8s_v1_cluster.k8s-cluster.id
  name             = join("-", ["k8s-ng-gpu", local.release-suffix, count.index])
  labels = {
    "library-solution" = "k8s-training"
  }
  version = var.k8s_version
  template = {
    metadata = {
      labels = var.mig_parted_config != null ? {
        "nvidia.com/mig.config" = var.mig_parted_config
      } : {}
      ssh-keys = "${var.ssh_user_name}:${local.ssh_public_key}"
    }

    boot_disk = {
      size_gibibytes = var.gpu_disk_size
      type           = var.gpu_disk_type
    }

    service_account_id = var.enable_k8s_node_group_sa ? nebius_iam_v1_service_account.k8s_node_group_sa[0].id : null

    network_interfaces = [
      {
        subnet_id = var.subnet_id != "" ? var.subnet_id : nebius_vpc_v1_subnet.training_subnet.id
        public_ip_address = var.gpu_nodes_assign_public_ip ? {} : null
      }
    ]
    resources = {
      platform = local.gpu_nodes_platform
      preset   = local.gpu_nodes_preset
    }
    preemptible = var.gpu_nodes_preemptible ? {
      on_preemption = "STOP"
      priority      = 1
    } : null
    filesystems = var.enable_filestore ? [
      {
        attach_mode         = "READ_WRITE"
        mount_tag           = "data"
        existing_filesystem = nebius_compute_v1_filesystem.shared-filesystem[0]
      }
    ] : null
    gpu_cluster  = var.enable_gpu_cluster ? nebius_compute_v1_gpu_cluster.fabric_2[0] : null
    gpu_settings = var.gpu_nodes_driverfull_image ? { drivers_preset = local.device_preset } : null

    underlay_required = false
  }
}
