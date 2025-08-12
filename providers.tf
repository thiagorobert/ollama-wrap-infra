variable "aws_region" {
  type        = string
  description = "AWS region to deploy to"
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region
}

variable "gcp_project" {
  type        = string
  description = "GCP project ID to deploy to"
}

variable "gcp_region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "gcp_zone" {
  type        = string
  description = "GCP zone (for zonal GKE)"
  default     = "us-central1-a"
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# Kubernetes providers are configured in main.tf once clusters exist (AWS and GCP aliases)


