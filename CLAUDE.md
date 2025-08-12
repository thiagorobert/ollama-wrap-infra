# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-cloud Kubernetes infrastructure project using Terraform to deploy "Hello World" NGINX services across AWS EKS and Google Cloud GKE clusters.

## Architecture

- **AWS EKS Cluster**: 2-node managed node group (t3.small instances) with NGINX deployment (2 replicas)
- **GCP GKE Cluster**: 1-node cluster (e2-standard-2 instances) with NGINX deployment (1 replica)
- **VPC/Networking**: Custom VPC with public/private subnets, NAT gateway, and proper EKS tagging
- **Load Balancers**: Each cluster exposes NGINX via LoadBalancer services with unique URLs
- **Multi-provider setup**: Uses both AWS and Google Cloud providers with separate Kubernetes provider aliases

## Development Commands

### Terraform Operations
```bash
# Initialize and upgrade providers
terraform init -upgrade

# Plan changes
terraform plan

# Apply infrastructure
terraform apply

# Destroy infrastructure
terraform destroy

# Show current state
terraform show

# Get output values
terraform output
terraform output -raw hello_world_url      # AWS LoadBalancer URL
terraform output -raw gcp_hello_world_url  # GCP LoadBalancer URL
```

### Kubectl Operations
```bash
# List available contexts
kubectl config get-contexts

# Switch to AWS EKS context
kubectl config use-context $(kubectl config get-contexts -o name | grep hello-eks | head -1)

# Switch to GCP GKE context  
kubectl config use-context $(kubectl config get-contexts -o name | grep hello-eks-gke | head -1)

# View nodes in current context
kubectl get nodes

# View nodes in specific context
kubectl get nodes --context <context-name>

# Check pods across both clusters
kubectl get pods -n hello -o wide --context <eks-context>
kubectl get pods -n hello -o wide --context <gke-context>
```

### Cloud Authentication
```bash
# AWS authentication
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1
# OR
aws configure
export AWS_PROFILE=my-profile

# GCP authentication
gcloud auth application-default login
export TF_VAR_gcp_project=<project-id>

# Update kubeconfig for both clusters
aws eks update-kubeconfig --name hello-eks --region us-east-1
gcloud container clusters get-credentials hello-eks-gke --zone us-central1-a --project $TF_VAR_gcp_project
```

### Visualization
```bash
# Generate Terraform dependency graph
terraform graph | dot -Tpng > tf-graph.png

# Install and use inframap for cleaner diagrams
curl -sSL https://github.com/cycloidio/inframap/releases/download/v0.6.8/inframap-linux-amd64 -o inframap && chmod +x inframap && sudo mv inframap /usr/local/bin/
terraform show -json terraform.tfstate | inframap generate -f json | dot -Tpng > inframap.png
```

## Key Configuration Details

### Variables
- `cluster_name`: Default "hello-eks", used as prefix for both AWS and GCP resources
- `node_desired_size`: Default 2 (AWS EKS nodes)
- `node_instance_types`: Default ["t3.small"] (AWS)
- `aws_region`: Default "us-east-1"
- `gcp_project`: Required, must be set via TF_VAR_gcp_project
- `gcp_zone`: Default "us-central1-a"

### Networking
- AWS VPC CIDR: 10.0.0.0/16
- Private subnets: 10.0.1.0/24, 10.0.2.0/24 (for nodes)
- Public subnets: 10.0.101.0/24, 10.0.102.0/24 (for load balancers)
- EKS endpoint: Publicly accessible (0.0.0.0/0)
- Proper Kubernetes subnet tagging for LoadBalancer provisioning

### Application Details
- NGINX serves "hello from <node-name>" responses
- Uses Kubernetes downward API to inject node name as NODE_NAME environment variable
- Each cluster has independent LoadBalancer services
- Resource limits: 250m CPU / 256Mi memory, requests: 100m CPU / 128Mi memory

## File Structure
- `main.tf`: Main infrastructure definitions for both AWS and GCP
- `providers.tf`: Provider configurations and variables
- `versions.tf`: Terraform and provider version constraints
- `outputs.tf`: Output definitions for cluster info and service URLs
- `data/chat-record.md`: Development conversation history
- `visualizations/`: Generated infrastructure diagrams