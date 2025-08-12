locals {
  cluster_name = var.cluster_name
  tags = {
    Project = "kubernets_aws"
    Managed = "terraform"
  }
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "hello-eks"
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Desired node count in the managed node group"
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.large"]
  description = "EC2 instance types for the node group"
}

data "aws_availability_zones" "available" {}

# VPC with 2 public + 2 private subnets
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${local.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  enable_dns_hostnames   = true
  enable_dns_support     = true
  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = local.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  # Ensure the control-plane endpoint is reachable from outside the VPC
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = false
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      desired_size   = var.node_desired_size
      max_size       = var.node_desired_size
      min_size       = var.node_desired_size
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = local.tags
}

# Configure Kubernetes provider using EKS module outputs
data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# Deploy Ollama Wrapper Deployment and Service
resource "kubernetes_namespace" "hello" {
  metadata {
    name = "hello"
  }

  depends_on = [module.eks]
}

resource "kubernetes_deployment" "ollama_wrapper" {
  metadata {
    name      = "hello-ollama-wrapper"
    namespace = kubernetes_namespace.hello.metadata[0].name
    labels = {
      app = "hello-ollama-wrapper"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "hello-ollama-wrapper"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-ollama-wrapper"
        }
      }

      spec {
        container {
          name  = "ollama-wrapper"
          image = "public.ecr.aws/f0b1x2x3/ollama-wrapper:latest"

          env {
            name = "NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name  = "OLLAMA_HOST"
            value = "0.0.0.0:11434"
          }

          port {
            container_port = 8080
            name           = "http"
          }

          resources {
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
            requests = {
              cpu    = "1000m"
              memory = "3Gi"
            }
          }
        }
      }
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_service" "ollama_wrapper" {
  metadata {
    name      = "hello-ollama-wrapper"
    namespace = kubernetes_namespace.hello.metadata[0].name
    labels = {
      app = "hello-ollama-wrapper"
    }
  }

  spec {
    selector = {
      app = "hello-ollama-wrapper"
    }
    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }

  depends_on = [module.eks]
}

output "ollama_service_hostname" {
  description = "Public hostname of the Ollama Wrapper service"
  value       = kubernetes_service.ollama_wrapper.status[0].load_balancer[0].ingress[0].hostname
}



# -----------------------------
# GCP: GKE single-node cluster
# -----------------------------

data "google_client_config" "default" {}

# Ensure GKE API is enabled
resource "google_project_service" "container_api" {
  project = var.gcp_project
  service = "container.googleapis.com"
}

resource "google_container_cluster" "gke" {
  name     = "${local.cluster_name}-gke"
  location = var.gcp_zone

  network                   = "default"
  remove_default_node_pool  = true
  initial_node_count        = 1
  deletion_protection       = false

  depends_on = [google_project_service.container_api]
}

resource "google_container_node_pool" "primary" {
  name     = "primary"
  location = var.gcp_zone
  cluster  = google_container_cluster.gke.name

  node_count = 1

  node_config {
    machine_type = "e2-standard-4"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    labels = {
      cluster = local.cluster_name
    }
    tags = ["gke", local.cluster_name]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

provider "kubernetes" {
  alias                  = "gke"
  host                   = "https://${google_container_cluster.gke.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

resource "kubernetes_namespace" "hello_gke" {
  provider = kubernetes.gke
  metadata {
    name = "hello"
  }
  depends_on = [google_container_node_pool.primary]
}

resource "kubernetes_deployment" "ollama_wrapper_gke" {
  provider = kubernetes.gke
  metadata {
    name      = "hello-ollama-wrapper"
    namespace = kubernetes_namespace.hello_gke.metadata[0].name
    labels = {
      app = "hello-ollama-wrapper"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "hello-ollama-wrapper"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-ollama-wrapper"
        }
      }

      spec {
        container {
          name  = "ollama-wrapper"
          image = "public.ecr.aws/f0b1x2x3/ollama-wrapper:latest"

          env {
            name = "NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name  = "OLLAMA_HOST"
            value = "0.0.0.0:11434"
          }

          port {
            container_port = 8080
            name           = "http"
          }

          resources {
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
            requests = {
              cpu    = "1000m"
              memory = "3Gi"
            }
          }
        }
      }
    }
  }

  depends_on = [google_container_node_pool.primary]
}

resource "kubernetes_service" "ollama_wrapper_gke" {
  provider = kubernetes.gke
  metadata {
    name      = "hello-ollama-wrapper"
    namespace = kubernetes_namespace.hello_gke.metadata[0].name
    labels = {
      app = "hello-ollama-wrapper"
    }
  }

  spec {
    selector = {
      app = "hello-ollama-wrapper"
    }
    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }
    type = "LoadBalancer"
  }

  depends_on = [google_container_node_pool.primary]
}

