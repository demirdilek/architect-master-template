terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# 1. Google Cloud Provider
provider "google" {
  project = "gke-hybrid-autonomy" # Replace with your actual Project ID
  region  = "europe-west3"         # Frankfurt is a great low-latency choice for Europe
}
# 2. AWS Provider
provider "aws" {
  region = "eu-central-1" # Frankfurt
}

# 3. Azure Provider
provider "azurerm" {
  features {} # Required for Azure
  subscription_id = var.azure_subscription_id
}
