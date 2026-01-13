terraform {
  backend "s3" {
    bucket         = "architect-master-terraform-state"
    key            = "gke/cluster.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
