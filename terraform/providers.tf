terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "gke-hybrid-autonomy" # Replace with your actual Project ID
  region  = "europe-west3"         # Frankfurt is a great low-latency choice for Europe
}
