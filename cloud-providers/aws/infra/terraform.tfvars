# SSH config
ssh_user_name = "ubuntu" # Username you want to use to connect to the nodes
ssh_public_key = {
  key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDQE1oESIjdF6tk66jvjZDxdRomjiM6KdsS9p/yl9RPthmabFoDcqCBQI/vRwHoPbWuUpdPc3Mb8h+DwfqEGfu32qoq2cmhYu9j9At1YC2UfE/ZdmCHddEjygLV79+61HMWbAhTrA/KkuNzOWg9genP1176KcwQb/V2BhDtFIfKCB7QZ7tHDTr4zRd45nxG4ega4EiI04UcHFnGJUP1RVZRZaJZUGrF0M4jQt1YYwg3/P3N90jJbl9TVAsW53v9g7jH0yeW7MeMvovMpG0oMW+w2T1BIV5fYLVsk1GQor8/Ti9y4ZTqMh3uM/qucxLMpXoVVyyfmJALQJ4j80ev1Mrbr7uv9A0E9V0GpEL1d0n1PkOX8EBg4LmuVfZobMaWEBs8kmsUhsrOz9NqN1PR7hkYXG2I/O66wgQNGnLa76RDNVEa37+XUsLQoBGqMljFDIudBQ80Rw8XMsZQo7SQTVyeHWuTQ5Os0fig+loSdMgkNLKUbCosDB4zdNFoufpshHcMDDWJRLS9nQe5ooqo1Q1Fjj4NLqXqxRx/PYGrX5OtVzKIg+GMVZo0obl4NLjfJ61Oi0r8WXBRUO4mLXZgCbw6AQhxDezA+1sGyR8lCNtoo0cgjWqrSLatq0z8AWZkNKrSWeTvo+fOPvx35D2DssxmS0ii/FA5VXL4HPhwOGtl7Q== farrukhmust@gmail.com"
  # path = "put path to public ssh key here"
}

# K8s nodes
cpu_nodes_count           = 2 # Number of CPU nodes
gpu_nodes_count_per_group = 1 # Number of GPU nodes per group (1 H100 node as required)
gpu_node_groups           = 1 # In case you need more then 100 nodes in cluster you have to put multiple node groups

# CPU platform and presets: https://docs.nebius.com/compute/virtual-machines/types#cpu-configurations
cpu_nodes_platform = "cpu-d3"     # CPU nodes platform
cpu_nodes_preset   = "4vcpu-16gb" # CPU nodes preset

# GPU platform and preset: https://docs.nebius.com/compute/virtual-machines/types#gpu-configurations
gpu_nodes_platform = "gpu-h100-sxm"        # GPU nodes platform: gpu-h100-sxm, gpu-h200-sxm, gpu-b200-sxm
gpu_nodes_preset   = "1gpu-16vcpu-200gb"   # GPU nodes preset: 1 GPU node (as required: 1xH100)

# Infiniband fabrics: https://docs.nebius.com/compute/clusters/gpu#fabrics
infiniband_fabric = "" # Infiniband fabric name (leave empty to use region default)

enable_gpu_cluster = false  # Disabled: Single GPU nodes don't support GPU clustering/InfiniBand
gpu_nodes_driverfull_image = false
enable_k8s_node_group_sa   = false  # Disabled - user account doesn't have permission to manage group memberships
enable_egress_gateway      = false
cpu_nodes_preemptible      = false
gpu_nodes_preemptible      = false

# MIG configuration
# mig_strategy =        # If set, possible values include 'single', 'mixed', 'none'
# mig_parted_config =   # If set, value will be checked against allowed for the selected 'gpu_nodes_platform'

# Observability
enable_prometheus = true # Enable or disable Prometheus and Grafana deployment with true or false
enable_loki       = true # Enable or disable Loki deployment with true or false

# Storage
enable_filestore     = true                             # Enable for shared dataset and model storage
filestore_disk_size  = 50 * 1024 * 1024 * 1024          # 50GB - enough for ToolACE dataset and training outputs
filestore_block_size = 4096                             # Set Filestore block size in bytes

# KubeRay
# for GPU isolation to work with kuberay, gpu_nodes_driverfull_image must be set
# to false.  This is because we enable acess to infiniband via securityContext.privileged
enable_kuberay = false # Turn KubeRay to false, otherwise gpu capacity will be consumed by KubeRay cluster

# kuberay CPU worker setup
# if you have no CPU only nodes, set these to zero
# kuberay_cpu_worker_image = ""  # set default CPU worker can leave it commented out in most cases
kuberay_min_cpu_replicas = 1
kuberay_max_cpu_replicas = 2
# kuberay_cpu_resources = {
#   cpus = 2
#   memory = 4  # memory allocation in gigabytes
# }

# kuberay GPU worker pod setup
# kuberay_gpu_worker_image = "" # set default gpu worker image see ../modules/kuberay/README.md for more info
kuberay_min_gpu_replicas = 2
kuberay_max_gpu_replicas = 8
# kuberay_gpu_resources = {
#   cpus = 16
#   gpus = 1
#   memory = 150  # memory allocation in gigabytes
# }

# NPD nebius-gpu-health-checker helm install
gpu_health_checker = true

# Required variables - set these from environment.sh or manually
# tenant_id   = ""    # Your tenant ID
# parent_id   = ""    # Your project ID
# subnet_id   = ""    # Subnet ID where cluster will be deployed
# region      = ""    # Region: eu-west1, eu-north1, eu-north2, us-central1, me-west1
# iam_token   = ""    # IAM token for Helm/Kubernetes provider authentication
