variable "azure_subscription_id" {
  type        = string
  description = "The ID of your Microsoft Azure Subscription"
}

variable "project_id" {
  type        = string
  description = "The Google Cloud Project ID"
  default     = "gke-hybrid-autonomy"
}
