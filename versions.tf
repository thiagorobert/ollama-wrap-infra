terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }

    google = {
      source  = "hashicorp/google"
      version = "~> 5.34"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.34"
    }
  }
}


