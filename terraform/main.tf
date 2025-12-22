# ==================================================================================
# 1. NETWORKS (The "Ground" for each cloud)
# ==================================================================================

# GCP: Private Network (Auto-mode creates 10.128.x.x in Frankfurt)
resource "google_compute_network" "gcp_vpc" {
  name                    = "gcp-main-network"
  auto_create_subnetworks = true
}

# AWS: Private Network (Manual 10.2.x.x)
module "vpc_aws" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "aws-main-network"
  cidr = "10.2.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = ["10.2.1.0/24", "10.2.2.0/24"]
  public_subnets  = ["10.2.101.0/24", "10.2.102.0/24"]

  enable_nat_gateway = true
}

# Azure: Private Network (Manual 10.3.x.x)
resource "azurerm_resource_group" "rg" {
  name     = "hybrid-project-rg"
  location = "Germany West Central"
}

resource "azurerm_virtual_network" "azure_vnet" {
  name                = "azure-main-network"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.3.0.0/16"]
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.azure_vnet.name
  address_prefixes     = ["10.3.1.0/24"]
}

# ==================================================================================
# 2. KUBERNETES CLUSTERS
# ==================================================================================

# GKE (GCP) - The "Brain"
resource "google_container_cluster" "gcp_hybrid_brain" {
  name     = "gke-frankfurt-autopilot"
  location = "europe-west3"
  
  network    = google_compute_network.gcp_vpc.name
  enable_autopilot = true

  fleet {
    project = "gke-hybrid-autonomy"
  }
  
  timeouts {
    create = "30m"
    update = "40m"
  }
}

# EKS (AWS) - Secondary Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "eks-frankfurt-worker"
  cluster_version = "1.31"
  cluster_endpoint_public_access = true
  vpc_id     = module.vpc_aws.vpc_id
  subnet_ids = module.vpc_aws.private_subnets 

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }
}

# AKS (Azure) - Emergency Backup
resource "azurerm_kubernetes_cluster" "azure_hybrid_backup" {
  name                = "aks-frankfurt-backup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "hybrid-aks"

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size    = "Standard_D2s_v6" # Changed from Standard_DS2_v2
    #vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }
}

# ==================================================================================
# 3. THE BRIDGE (GKE Fleet / Hub) - Fixed Version
# ==================================================================================

# Register AWS EKS
resource "google_gke_hub_membership" "aws_fleet_member" {
  membership_id = "aws-worker-membership"
  location      = "global"

  # We provide the Authority so the AWS cluster can authenticate via OIDC
  authority {
    issuer = module.eks.cluster_oidc_issuer_url
  }

  # We leave the endpoint block empty or remove it. 
  # Google will automatically create the membership resource.
  endpoint {
    # This allows the connection without requiring a GKE-specific resource link
  }

  depends_on = [module.eks]
}

# Register Azure AKS
resource "google_gke_hub_membership" "azure_fleet_member" {
  membership_id = "azure-backup-membership"
  location      = "global"

  authority {
    issuer = azurerm_kubernetes_cluster.azure_hybrid_backup.oidc_issuer_url
  }

  endpoint {
  }

  depends_on = [azurerm_kubernetes_cluster.azure_hybrid_backup]
}