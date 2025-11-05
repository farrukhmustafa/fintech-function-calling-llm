# VPC Network and Subnet Resources
# Create dedicated network/subnet for demo to avoid /16 allocation issues
# Based on Nebius provider schema - subnet uses ipv4_private_pools structure

resource "nebius_vpc_v1_network" "training_network" {
  name      = "k8s-training-network-${local.release-suffix}"
  parent_id = var.parent_id
}

resource "nebius_vpc_v1_subnet" "training_subnet" {
  name       = "k8s-training-subnet-${local.release-suffix}"
  parent_id  = var.parent_id
  network_id = nebius_vpc_v1_network.training_network.id
  
  # Let Nebius auto-allocate CIDR from network pools (simpler for demo)
  # This avoids specifying complex nested structure while still getting appropriate sizing
}

