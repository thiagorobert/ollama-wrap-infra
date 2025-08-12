output "region" {
  value = var.aws_region
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "hello_world_url" {
  description = "URL to test the Ollama Wrapper service"
  value       = "http://${kubernetes_service.ollama_wrapper.status[0].load_balancer[0].ingress[0].hostname}"
}

output "gcp_hello_world_url" {
  description = "URL to test the Ollama Wrapper service on GKE"
  value       = "http://${kubernetes_service.ollama_wrapper_gke.status[0].load_balancer[0].ingress[0].ip != null ? kubernetes_service.ollama_wrapper_gke.status[0].load_balancer[0].ingress[0].ip : kubernetes_service.ollama_wrapper_gke.status[0].load_balancer[0].ingress[0].hostname}"
}


