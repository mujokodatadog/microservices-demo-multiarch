# Provision an EKS Cluster

This directory contains Terraform configuration files to provision an EKS cluster on AWS for deploying the Swagstore microservices demo application.

Based on the HashiCorp [Provision an EKS Cluster tutorial](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks).

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) (~> 1.3)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## What Gets Created

| Resource | Description |
|----------|-------------|
| **VPC** | A new VPC with public and private subnets across 3 availability zones |
| **EKS Cluster** | Kubernetes 1.30 control plane |
| **Node Group 1** | 2x t3.small instances (min: 1, max: 3) |
| **Node Group 2** | 1x t3.medium instance (min: 1, max: 2) |
| **Security Groups** | Separate security groups for each node group |
| **NAT Gateway** | For outbound internet access from private subnets |

## Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region to deploy to | `eu-south-1` |

To change the region, create a `terraform.tfvars` file:

```hcl
region = "us-east-1"
```

### Using ARM/Graviton Instances (Optional)

To use ARM-based Graviton instances for cost savings, edit `eks-cluster.tf`:

```hcl
# Change AMI type
ami_type = "AL2_ARM_64"

# Change instance types
instance_types = ["m6g.medium"]  # for node-group-1
instance_types = ["m6g.large"]   # for node-group-2
```

> **Note**: When using ARM instances, deploy with `--platform=linux/arm64` in Skaffold.

## Usage

### Step 1: Configure AWS Credentials

```bash
# Option A: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"

# Option B: AWS CLI configuration
aws configure

# Verify credentials
aws sts get-caller-identity
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Review the Plan

```bash
terraform plan
```

### Step 4: Apply the Configuration

```bash
terraform apply
```

> **Note**: This may take 15-20 minutes to complete.

### Step 5: Configure kubectl

```bash
# Get outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw region)

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# Verify connection
kubectl get nodes
```

## Outputs

After successful deployment, Terraform provides the following outputs:

| Output | Description |
|--------|-------------|
| `cluster_id` | EKS cluster ID |
| `cluster_name` | Kubernetes cluster name |
| `cluster_endpoint` | Endpoint for EKS control plane |
| `cluster_security_group_id` | Security group ID attached to the cluster |
| `region` | AWS region |

View outputs:

```bash
terraform output
```

## Set Up Amazon ECR (Optional)

If you want to build and push your own container images (instead of using pre-built images), create ECR repositories for each microservice:

```bash
# Set variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(terraform output -raw region)

# Create ECR repositories for each service
for service in emailservice productcatalogservice recommendationservice shippingservice checkoutservice paymentservice currencyservice cartservice frontend adservice loadgenerator; do
  aws ecr create-repository --repository-name $service --region $AWS_REGION 2>/dev/null || echo "Repository $service already exists"
done

# Authenticate Docker to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

### Verify ECR Repositories

```bash
aws ecr describe-repositories --region $AWS_REGION --query 'repositories[].repositoryName' --output table
```

## Deploy the Application

After the cluster is ready, return to the project root and deploy with Skaffold:

### Option A: Using Pre-built Images (Quick)

```bash
cd ../..

skaffold run --default-repo=docker.io/smazzone --platform=linux/amd64
```

### Option B: Using Your Own ECR Registry (Build from Source)

```bash
cd ../..

# Ensure ECR variables are set
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=eu-south-1  # or your region

# Build and deploy
skaffold run --default-repo=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com --platform=linux/amd64
```

> **Note**: First build may take ~20 minutes.

## Access the Application

After deployment completes, get the external hostname to access the Swagstore frontend.

### Step 1: Get the External URL

```bash
# Get the frontend service external hostname
kubectl get service frontend-external -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Or view all service details:

```bash
kubectl get svc frontend-external
```

Example output:

```
NAME                TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)        AGE
frontend-external   LoadBalancer   172.20.45.123   a1b2c3d4-123456789.eu-south-1.elb.amazonaws.com                           80:31234/TCP   5m
```

### Step 2: Wait for Load Balancer

AWS ELB provisioning can take 2-5 minutes. If `EXTERNAL-IP` shows `<pending>`, wait and retry:

```bash
# Watch until external hostname appears
kubectl get svc frontend-external -w
```

### Step 3: Access in Browser

```bash
# Get the URL and open it
FRONTEND_URL=$(kubectl get service frontend-external -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "🛒 Swagstore URL: http://$FRONTEND_URL"
```

Open the URL in your browser to access the Swagstore application.

> **Note**: DNS propagation may take a few minutes. If the page doesn't load immediately, wait 2-3 minutes and try again.

### Verify All Services Are Running

```bash
kubectl get pods
```

All pods should show `Running` status with `1/1` ready.

## Datadog Monitoring Setup (Optional)

Deploy Datadog for APM, logs, and infrastructure monitoring on your EKS cluster.

### Step 1: Add Datadog Helm Repository

```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update
```

### Step 2: Configure API Keys

Edit the `values-eks.yaml` file in the project root and replace the placeholder API keys:

```bash
cd ../..  # Return to project root

# Edit values-eks.yaml and replace:
# - <YOUR_DATADOG_API_KEY> with your actual API key
# - <YOUR_DATADOG_APP_KEY> with your actual App key
```

Or use environment variables:

```bash
export DD_API_KEY="your-api-key"
export DD_APP_KEY="your-app-key"
```

### Step 3: Deploy Datadog Agent

```bash
# Using values file (recommended)
helm install datadog-agent -f values-eks.yaml \
  --set datadog.apiKey=$DD_API_KEY \
  --set datadog.appKey=$DD_APP_KEY \
  datadog/datadog

# Or with all values inline
helm install datadog-agent datadog/datadog \
  --set datadog.apiKey=$DD_API_KEY \
  --set datadog.appKey=$DD_APP_KEY \
  --set datadog.clusterName=swagstore-eks \
  --set datadog.site=datadoghq.com \
  --set datadog.apm.portEnabled=true \
  --set datadog.logs.enabled=true \
  --set datadog.logs.containerCollectAll=true \
  --set clusterAgent.enabled=true \
  --set clusterAgent.admissionController.enabled=true
```

### Step 4: Verify Datadog Deployment

```bash
# Check Datadog pods
kubectl get pods -l app=datadog-agent

# Expected output (all pods Running):
# datadog-agent-xxxxx          2/2     Running
# datadog-agent-cluster-agent  1/1     Running
```

### Step 5: Restart Application Pods (Important!)

For Datadog auto-instrumentation to inject APM libraries:

```bash
kubectl rollout restart deployment
```

### Verify in Datadog

After a few minutes, check [Datadog](https://app.datadoghq.com):

- **Infrastructure** → **Kubernetes** → Look for your cluster
- **APM** → **Services** → See microservices traces
- **Logs** → **Live Tail** → View container logs

## NGINX Ingress with Rate Limiting (Optional)

Deploy NGINX Ingress Controller to add rate limiting at the ingress level. This returns HTTP 429 errors when limits are exceeded, visible in Datadog APM.

### Step 1: Install NGINX Ingress Controller

```bash
# Add NGINX Ingress Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

### Step 2: Wait for Load Balancer

```bash
# Wait for the ingress controller to get an external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -w

# Get the external hostname
INGRESS_HOST=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Ingress URL: http://$INGRESS_HOST"
```

### Step 3: Create Ingress with Rate Limiting

Create a file `frontend-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  annotations:
    # Rate limiting configuration (aggressive values for testing)
    nginx.ingress.kubernetes.io/limit-rps: "1"                # 1 request per second per IP
    nginx.ingress.kubernetes.io/limit-connections: "1"         # 1 concurrent connection per IP
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "1"    # No burst allowance (critical!)
    # Note: Rate-limited requests return HTTP 503 by default
    # Optional: Whitelist internal IPs from rate limiting
    # nginx.ingress.kubernetes.io/limit-whitelist: "10.0.0.0/8,172.16.0.0/12"
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
```

> **Note**: The `server-snippet` annotation for custom 429 status codes is disabled by default in NGINX Ingress Controller v1.9+. Rate-limited requests will return HTTP 503.

Apply the ingress:

```bash
kubectl apply -f frontend-ingress.yaml
```

### Step 4: Update Frontend Service (Optional)

If you want to use only the Ingress (disable direct LoadBalancer access):

```bash
# Patch frontend-external to ClusterIP (removes direct LB access)
kubectl patch svc frontend-external -p '{"spec": {"type": "ClusterIP"}}'
```

### Step 5: Test Rate Limiting

**Important**: Sequential curl requests are too slow to trigger rate limiting. Use parallel requests:

```bash
# Get ingress URL
INGRESS_HOST=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Option A: Using hey (recommended - install with: brew install hey)
hey -n 50 -c 10 "http://$INGRESS_HOST/"

# Option B: Using curl with parallel requests
for i in {1..20}; do
  curl -s -o /dev/null -w "%{http_code}\n" "http://$INGRESS_HOST/" &
done
wait
```

You should see `200` responses initially, then `503` when rate limited.

### Step 6: Verify in Datadog

After triggering rate limits:

1. Go to **APM** → **Traces**
2. Filter: `@http.status_code:503`
3. See rate-limited requests from NGINX Ingress

### Rate Limiting Options

| Annotation | Description | Example |
|------------|-------------|---------|
| `limit-rps` | Requests per second per IP | `1` |
| `limit-connections` | Concurrent connections per IP | `1` |
| `limit-burst-multiplier` | Burst multiplier (set to 1 to disable) | `1` |
| `limit-whitelist` | IPs to exclude from limits | `10.0.0.0/8` |

### Remove NGINX Ingress

```bash
kubectl delete ingress frontend-ingress
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace ingress-nginx
```

## Cleanup

To destroy all AWS resources:

```bash
# Delete NGINX Ingress (if installed)
kubectl delete ingress frontend-ingress 2>/dev/null
helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null

# Delete Datadog agent (if installed)
helm uninstall datadog-agent 2>/dev/null

# Delete Kubernetes application resources (from project root)
cd ../..
skaffold delete

# Then destroy infrastructure
cd terraform/aws
terraform destroy
```

## Troubleshooting

### Error: "no EC2 IMDS role found"

This means AWS credentials are not configured. Ensure you've set up credentials via environment variables or AWS CLI.

### Error: "unsupported Kubernetes version"

Update `cluster_version` in `eks-cluster.tf` to a supported version (1.28, 1.29, 1.30, or 1.31).

### Nodes not joining cluster

Check that the VPC has proper NAT gateway configuration and security groups allow outbound traffic.

## Cost Considerations

Running this EKS cluster incurs AWS charges for:
- EKS control plane (~$0.10/hour)
- EC2 instances (t3.small ~$0.02/hour, t3.medium ~$0.04/hour)
- NAT Gateway (~$0.045/hour + data transfer)
- Load Balancer (created by Kubernetes services)

**Estimated cost**: ~$5-10/day depending on usage.

**Remember to run `terraform destroy` when done to avoid ongoing charges.**
