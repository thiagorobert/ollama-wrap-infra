## AWS EKS (2-node) with NGINX Hello World via Terraform

This project provisions a minimal Amazon EKS cluster (2 nodes) and deploys an NGINX service that responds with "hello world" at `/`.

### Prerequisites
- Terraform >= 1.6
- AWS credentials configured (env vars or shared credentials)
- kubectl (optional)

### Usage

```bash
cd /workspace/kubernets_aws
terraform init
terraform apply -auto-approve
```

After apply, note the `hello_world_url` output and test:

```bash
curl http://<hostname>/
# hello world
```

Destroy when done:

```bash
terraform destroy -auto-approve
```

### Variables
- `aws_region`: default `us-east-1`
- `cluster_name`: default `hello-eks`
- `node_desired_size`: default `2`
- `node_instance_types`: default `["t3.small"]`

### Notes
- VPC spans 2 AZs with private node subnets and public subnets for LoadBalancer.
- Subnets are tagged for EKS LoadBalancer provisioning.
- Kubernetes provider is authenticated via EKS token.



