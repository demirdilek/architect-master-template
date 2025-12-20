resource "google_container_cluster" "primary" {
  name     = "gke-hybrid-cluster"
  location = "europe-west3"

  # Enabling Autopilot mode
  enable_autopilot = true

  # SRE Best Practice: Release channels
  # This ensures the cluster stays updated automatically
  release_channel {
    channel = "REGULAR"
  }

  # Network configuration
  networking_mode = "VPC_NATIVE"
}
