# ==================================================================================
# 1. NETWORKS (Connectivity Layer)
# Designed for low cost: No NAT Gateways, using Public IPs for outbound traffic.
# ==================================================================================

# GCP: Standard VPC in auto-mode
resource "google_compute_network" "gcp_vpc" {
  name                    = "gcp-main-network"
  auto_create_subnetworks = true
}

# AWS: Cost-optimized VPC (No NAT Gateway saved ~$32/month)
module "vpc_aws" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "aws-main-network"
  cidr    = "10.2.0.0/16"
  azs     = ["eu-central-1a", "eu-central-1b"]

  # Nodes in public subnets can reach Google APIs directly via Public IPs
  public_subnets = ["10.2.101.0/24", "10.2.102.0/24"]

  enable_nat_gateway      = false 
  map_public_ip_on_launch = true
}

# Azure: Basic networking setup
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
# 2. KUBERNETES CLUSTERS (Compute Layer)
# Using Spot instances and B-series VMs to satisfy budget and quota limits.
# ==================================================================================

# GKE (GCP): Autopilot Brain
resource "google_container_cluster" "gcp_hybrid_brain" {
  name                = "gke-frankfurt-autopilot"
  location            = "europe-west3"
  deletion_protection = false
  network             = google_compute_network.gcp_vpc.name
  enable_autopilot    = true

  logging_config { enable_components = ["SYSTEM_COMPONENTS"] }
  monitoring_config { enable_components = ["SYSTEM_COMPONENTS"] }

  fleet { project = "gke-hybrid-autonomy" }
}

# EKS (AWS): Worker cluster using Spot instances
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  cluster_name    = "eks-frankfurt-worker"
  cluster_version = "1.31"
  cluster_endpoint_public_access = true
  vpc_id     = module.vpc_aws.vpc_id
  subnet_ids = module.vpc_aws.public_subnets 
  cluster_enabled_log_types = []
  bootstrap_self_managed_addons = false 

  eks_managed_node_groups = {
    spot_nodes = {
      instance_types = ["t3.small"] # Free-tier eligible
      capacity_type  = "SPOT"
      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }
}

# AKS (Azure): Backup cluster
resource "azurerm_kubernetes_cluster" "azure_hybrid_backup" {
  name                = "aks-frankfurt-backup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "hybrid-aks"
  sku_tier            = "Free" 

  default_node_pool {
    name                = "systempool"
    node_count          = 1
    vm_size             = "Standard_D2s_v6" # 4GB RAM to satisfy quota and memory requirements
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    type                = "VirtualMachineScaleSets"
  }
  identity { type = "SystemAssigned" }
}

# Azure Spot Pool for the GKE Connect Agent
resource "azurerm_kubernetes_cluster_node_pool" "spot_workload" {
  name                  = "spotp"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.azure_hybrid_backup.id
  vm_size               = "Standard_D2s_v6"
  node_count            = 1
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = -1
  node_labels           = { "capacity" = "spot" }
}

# ==================================================================================
# 3. GKE HUB (Fleet Registration)
# Linking external clusters to the Google Cloud Dashboard.
# ==================================================================================

resource "google_gke_hub_membership" "aws_fleet_member" {
  membership_id = "aws-worker-membership"
  location      = "global"
  authority { issuer = module.eks.cluster_oidc_issuer_url }
  endpoint {}
  depends_on = [module.eks]
}

resource "google_gke_hub_membership" "azure_fleet_member" {
  membership_id = "azure-backup-membership"
  location      = "global"
  authority { issuer = azurerm_kubernetes_cluster.azure_hybrid_backup.oidc_issuer_url }
  endpoint {}
  depends_on = [azurerm_kubernetes_cluster.azure_hybrid_backup]
}

# ==================================================================================
# 4. KUBERNETES & HELM AUTHENTICATION
# Aliased providers to connect to multiple clusters simultaneously.
# ==================================================================================

provider "kubernetes" {
  alias                  = "eks"
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  alias = "eks"
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubernetes" {
  alias                  = "aks"
  host                   = azurerm_kubernetes_cluster.azure_hybrid_backup.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.azure_hybrid_backup.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.azure_hybrid_backup.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.azure_hybrid_backup.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  alias = "aks"
  kubernetes {
    host                   = azurerm_kubernetes_cluster.azure_hybrid_backup.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.azure_hybrid_backup.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.azure_hybrid_backup.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.azure_hybrid_backup.kube_config.0.cluster_ca_certificate)
  }
}

# ==================================================================================
# 5. AGENT DEPLOYMENT (Using OCI Helm Charts)
# ==================================================================================
/*
resource "helm_release" "gke_connect_aws" {
  provider         = helm.eks
  name             = "gke-connect"
  repository       = "https://charts.companyinfo.dev"
  chart            = "gke-connect-agent"
  version          = "0.1.0"
  namespace        = "gke-connect"
  create_namespace = true

  set {
    name  = "projectID"
    value = "gke-hybrid-autonomy"
  }
  set {
    name  = "membershipID"
    value = google_gke_hub_membership.aws_fleet_member.membership_id
  }
  set {
    name  = "logLevel"
    value = "error"
  }
}

resource "helm_release" "gke_connect_azure" {
  provider         = helm.aks
  name             = "gke-connect"
  repository       = "https://charts.companyinfo.dev"
  chart            = "gke-connect-agent"
  version          = "0.1.0"
  namespace        = "gke-connect"
  create_namespace = true

  set {
    name  = "projectID"
    value = "gke-hybrid-autonomy"
  }
  set {
    name  = "membershipID"
    value = google_gke_hub_membership.azure_fleet_member.membership_id
  }
  set {
    name  = "logLevel"
    value = "error"
  }
}*/