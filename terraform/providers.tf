# ==================================================================================
# TERRAFORM CONFIGURATION
# Defines required providers and their versions for the multi-cloud setup.
# ==================================================================================

terraform {
  # Minimum Terraform version required for this configuration
  required_version = ">= 1.5.0"

  required_providers {
    # Google Cloud Provider: Used for GKE, VPC, and GKE Hub (Fleet)
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    # AWS Provider: Used for EKS and AWS VPC
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Azure Provider: Used for AKS and Azure Virtual Network
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    # Kubernetes Provider: Used for direct interaction with the clusters
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    # Helm Provider: Used for automated installation of GKE Connect agents
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# ==================================================================================
# PROVIDER BLOCK CONFIGURATIONS
# Setting up default regions and project credentials.
# ==================================================================================

# Google Cloud configuration
provider "google" {
  project = "gke-hybrid-autonomy"
  region  = "europe-west3" # Frankfurt
}

# AWS configuration
provider "aws" {
  region = "eu-central-1" # Frankfurt
}

# Azure configuration
provider "azurerm" {
  features {} # Required block for the AzureRM provider to function
}