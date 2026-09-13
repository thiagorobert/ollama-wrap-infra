# ollama-wrap-infra

Terraform that stands up the same LLM inference service on two clouds.

One `terraform apply` builds an EKS cluster on AWS and a GKE cluster on GCP, then
deploys identical Kubernetes manifests to both, running the container from
[ollama-wrap](https://github.com/thiagorobert/ollama-wrap) — a Go service that
fronts a local Ollama model, with the model weights baked into the image. Each
cluster gets its own load balancer, and the two URLs come back as outputs.

Background: [A New Adventure](https://blog.thiago.pub/2025/08/11/a-new-adventure.html).

## What it builds

| | AWS | GCP |
| --- | --- | --- |
| Network | VPC `10.0.0.0/16`, 2 AZs, 2 public + 2 private subnets, single NAT gateway | the `default` network |
| Cluster | EKS 1.29, managed node group, 2 × `t3.large` | zonal GKE, default pool removed, 1 × `e2-standard-4` |
| Workload | Deployment + `LoadBalancer` Service in namespace `hello` | the same, via a second aliased provider |

Both run `public.ecr.aws/f0b1x2x3/ollama-wrapper:latest`, request 1 CPU / 3Gi
(limit 2 CPU / 4Gi), and publish port 80 to the container's 8080.

Deploying to two clouds from one root module works by declaring the
`kubernetes` provider twice — once authenticated against EKS with
`aws_eks_cluster_auth`, once aliased as `kubernetes.gke` and authenticated with
a `google_client_config` access token. The GCP resources depend on the node
pool rather than the cluster, so the provider does not try to talk to an API
server that has no nodes behind it yet.

## Usage

Requires Terraform >= 1.6 and credentials for both clouds. `gcp_project` has no
default and must be supplied.

```bash
terraform init
terraform apply -var gcp_project=my-project

curl --get --data-urlencode 'input=Why is the sky blue?' \
  "$(terraform output -raw hello_world_url)/query"

terraform destroy -var gcp_project=my-project
```

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `gcp_project` | *(required)* | GCP project to deploy into. |
| `aws_region` | `us-east-1` | AWS region. |
| `gcp_region` / `gcp_zone` | `us-central1` / `us-central1-a` | GKE is zonal. |
| `cluster_name` | `hello-eks` | Names the EKS cluster; the GKE cluster gets a `-gke` suffix. |
| `node_desired_size` | `2` | EKS node count. Min, max and desired are all set from it. |
| `node_instance_types` | `["t3.large"]` | EKS node type. |

## Outputs

`hello_world_url` and `gcp_hello_world_url` are the two service URLs — the GKE
one resolves to an IP or a hostname depending on what the load balancer hands
back. Also `region`, `eks_cluster_name`, `eks_cluster_endpoint` and
`ollama_service_hostname`.

## Notes

Node sizing follows the pod, not the other way round: a 3Gi memory request will
not schedule on a `t3.small`, which is what makes `t3.large` the floor here.

This is not a cheap stack to leave running — a NAT gateway, two EKS nodes, a GKE
node and two cloud load balancers, all billed by the hour. Destroy it when you
are done.

`hello-eks`, the `hello` namespace and the `hello_world_url` output are
vestigial names from the nginx hello-world cluster this started as.
