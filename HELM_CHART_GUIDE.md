# Swagstore Helm Chart Documentation

## Overview

This Helm chart provides a production-ready deployment method for the Swagstore (Online Boutique) microservices application. It offers flexible configuration options for various deployment scenarios, from simple local development to enterprise production deployments with service mesh, security policies, and external databases.

## Chart Information

- **Chart Name**: `onlineboutique`
- **Chart Version**: `0.5.0`
- **App Version**: `v0.5.0`
- **Chart Type**: Application
- **Multiarch Support**: AMD64 and ARM64

## Architecture

The chart deploys 11 microservices:

| Service | Language | Description |
|---------|----------|-------------|
| **adservice** | Java | Provides text ads based on context words |
| **cartservice** | C# | Stores shopping cart items in Redis/Spanner |
| **checkoutservice** | Go | Orchestrates payment, shipping, and email |
| **currencyservice** | Node.js | Converts currency amounts |
| **emailservice** | Python | Sends order confirmation emails |
| **frontend** | Go | Web server serving the website |
| **loadgenerator** | Python | Generates synthetic user traffic |
| **paymentservice** | Node.js | Processes payments |
| **productcatalogservice** | Go | Manages product catalog |
| **recommendationservice** | Python | Recommends products |
| **shippingservice** | Go | Calculates shipping costs |
| **redis-cart** | Redis | In-cluster Redis database (optional) |

## Prerequisites

- Kubernetes cluster (v1.19+)
- Helm 3.x
- kubectl configured to communicate with your cluster
- (Optional) Service mesh (Istio/Anthos Service Mesh) for advanced features
- (Optional) Google Cloud Spanner for production cart database

## Quick Start

### Basic Deployment

Deploy with default settings (uses public Google images):

```bash
helm install swagstore ./helm-chart
```

### Using Custom Images from GCR

Deploy with your own built images:

```bash
helm install swagstore ./helm-chart \
  --set images.repository=gcr.io/datadog-partner-tech-sandbox \
  --set images.tag=b786477
```

### Using Your Own Docker Registry

```bash
helm install swagstore ./helm-chart \
  --set images.repository=docker.io/yourusername/swagstore \
  --set images.tag=latest
```

## Configuration Options

### Image Configuration

```yaml
images:
  repository: gcr.io/google-samples/microservices-demo  # Container registry
  tag: ""  # If empty, uses appVersion from Chart.yaml
```

**Example: Using Your Custom Images**
```bash
helm install swagstore ./helm-chart \
  --set images.repository=gcr.io/my-project \
  --set images.tag=v1.0.0
```

### Service Accounts

```yaml
serviceAccounts:
  create: false  # Set to true to create Kubernetes service accounts
  annotations: {}  # Annotations for all service accounts
  annotationsOnlyForCartservice: false  # Apply annotations only to cartservice
```

**Example: Workload Identity (GKE)**
```bash
helm install swagstore ./helm-chart \
  --set serviceAccounts.create=true \
  --set 'serviceAccounts.annotations.iam\.gke\.io/gcp-service-account=my-sa@my-project.iam.gserviceaccount.com'
```

### Database Configuration

#### Using In-Cluster Redis (Default)

```yaml
cartDatabase:
  type: redis
  connectionString: "redis-cart:6379"
  inClusterRedis:
    create: true
    name: redis-cart
    publicRepository: true
```

#### Using External Redis

```bash
helm install swagstore ./helm-chart \
  --set cartDatabase.inClusterRedis.create=false \
  --set cartDatabase.connectionString="my-redis.example.com:6379"
```

#### Using Google Cloud Spanner

```bash
helm install swagstore ./helm-chart \
  --set cartDatabase.type=spanner \
  --set cartDatabase.inClusterRedis.create=false \
  --set cartDatabase.connectionString="projects/my-project/instances/my-instance/databases/carts"
```

### Frontend Configuration

```yaml
frontend:
  create: true
  name: frontend
  externalService: true  # Creates LoadBalancer service
  cymbalBranding: false  # Alternative branding
  platform: local  # Options: local, gcp, aws, azure, onprem, alibaba
  singleSharedSession: false  # Enable session sharing
```

**Example: Disable External Load Balancer**
```bash
helm install swagstore ./helm-chart \
  --set frontend.externalService=false
```

### Load Generator

```yaml
loadGenerator:
  create: true  # Set to false to disable synthetic traffic
  name: loadgenerator
  checkFrontendInitContainer: true
```

**Example: Disable Load Generator**
```bash
helm install swagstore ./helm-chart \
  --set loadGenerator.create=false
```

### Security Features

#### Network Policies

Enable fine-grained network policies for each service:

```bash
helm install swagstore ./helm-chart \
  --set networkPolicies.create=true
```

#### Seccomp Profile

Enable seccomp profiles for container security:

```bash
helm install swagstore ./helm-chart \
  --set seccompProfile.enable=true \
  --set seccompProfile.type=RuntimeDefault
```

### Service Mesh Integration

#### Istio Sidecars

```bash
helm install swagstore ./helm-chart \
  --set sidecars.create=true
```

#### Authorization Policies

```bash
helm install swagstore ./helm-chart \
  --set authorizationPolicies.create=true
```

#### Virtual Service (Istio Gateway)

```bash
helm install swagstore ./helm-chart \
  --set frontend.virtualService.create=true \
  --set frontend.virtualService.gateway.name=my-gateway \
  --set frontend.virtualService.gateway.namespace=istio-system
```

### Observability

#### Google Cloud Operations

```bash
helm install swagstore ./helm-chart \
  --set googleCloudOperations.profiler=true \
  --set googleCloudOperations.tracing=true \
  --set googleCloudOperations.metrics=true
```

#### OpenTelemetry Collector

```bash
helm install swagstore ./helm-chart \
  --set opentelemetryCollector.create=true \
  --set opentelemetryCollector.projectId=my-gcp-project
```

### Native gRPC Health Checks

For Kubernetes 1.24+ with native gRPC health check support:

```bash
helm install swagstore ./helm-chart \
  --set nativeGrpcHealthCheck=true
```

## Advanced Deployment Scenarios

### Production Deployment with All Features

Full-featured production deployment with security, observability, and external database:

```bash
helm install swagstore ./helm-chart \
  --create-namespace \
  --namespace swagstore-prod \
  --set images.repository=gcr.io/my-project/swagstore \
  --set images.tag=v1.0.0 \
  --set frontend.externalService=true \
  --set cartDatabase.type=spanner \
  --set cartDatabase.connectionString="projects/my-project/instances/prod/databases/carts" \
  --set cartDatabase.inClusterRedis.create=false \
  --set serviceAccounts.create=true \
  --set 'serviceAccounts.annotations.iam\.gke\.io/gcp-service-account=swagstore-sa@my-project.iam.gserviceaccount.com' \
  --set serviceAccounts.annotationsOnlyForCartservice=true \
  --set networkPolicies.create=true \
  --set authorizationPolicies.create=true \
  --set sidecars.create=true \
  --set seccompProfile.enable=true \
  --set googleCloudOperations.profiler=true \
  --set googleCloudOperations.tracing=true \
  --set googleCloudOperations.metrics=true \
  --set nativeGrpcHealthCheck=true \
  --set loadGenerator.create=false
```

### Development/Testing Deployment

Minimal deployment for development:

```bash
helm install swagstore-dev ./helm-chart \
  --namespace dev \
  --create-namespace \
  --set images.repository=gcr.io/my-project/swagstore \
  --set images.tag=dev-latest \
  --set frontend.externalService=false \
  --set loadGenerator.create=true
```

### Service Mesh Deployment (Istio)

Deployment with full Istio integration:

```bash
helm install swagstore ./helm-chart \
  --namespace swagstore \
  --create-namespace \
  --set sidecars.create=true \
  --set authorizationPolicies.create=true \
  --set networkPolicies.create=true \
  --set frontend.externalService=false \
  --set frontend.virtualService.create=true \
  --set frontend.virtualService.gateway.name=asm-ingressgateway \
  --set frontend.virtualService.gateway.namespace=asm-ingress
```

## Selective Service Deployment

You can selectively enable/disable individual services:

```bash
helm install swagstore ./helm-chart \
  --set adService.create=false \
  --set recommendationService.create=false \
  --set loadGenerator.create=false
```

## Helm Chart Management

### Install

```bash
helm install swagstore ./helm-chart
```

### Upgrade

```bash
helm upgrade swagstore ./helm-chart \
  --set images.tag=v1.1.0
```

### Rollback

```bash
helm rollback swagstore
```

### Uninstall

```bash
helm uninstall swagstore
```

### Get Values

```bash
# Show all current values
helm get values swagstore

# Show all values including defaults
helm get values swagstore --all
```

### Template Rendering

Preview manifests without deploying:

```bash
helm template swagstore ./helm-chart \
  --set images.repository=gcr.io/my-project
```

## Common Use Cases

### 1. Deploy to GKE with Custom Images

```bash
# Build and push images
skaffold run --default-repo=gcr.io/my-project --platform=linux/amd64

# Deploy with Helm
helm install swagstore ./helm-chart \
  --set images.repository=gcr.io/my-project \
  --set images.tag=$(git rev-parse --short HEAD)
```

### 2. Local Development with Minikube/Kind

```bash
# Build images locally
eval $(minikube docker-env)  # or use Kind's registry
skaffold build --default-repo=local

# Deploy with Helm
helm install swagstore ./helm-chart \
  --set images.repository=local/swagstore \
  --set frontend.externalService=false
```

### 3. Production with External Database

```bash
helm install swagstore ./helm-chart \
  --set cartDatabase.type=redis \
  --set cartDatabase.connectionString="redis.prod.internal:6379" \
  --set cartDatabase.inClusterRedis.create=false \
  --set loadGenerator.create=false
```

### 4. Multi-Environment Deployment

Create separate values files:

**values-dev.yaml**
```yaml
images:
  repository: gcr.io/my-project/swagstore
  tag: dev
frontend:
  externalService: false
loadGenerator:
  create: true
```

**values-prod.yaml**
```yaml
images:
  repository: gcr.io/my-project/swagstore
  tag: v1.0.0
frontend:
  externalService: true
  platform: gcp
loadGenerator:
  create: false
cartDatabase:
  type: spanner
  connectionString: "projects/my-project/instances/prod/databases/carts"
  inClusterRedis:
    create: false
networkPolicies:
  create: true
serviceAccounts:
  create: true
```

Deploy:
```bash
# Dev
helm install swagstore-dev ./helm-chart -f values-dev.yaml

# Prod
helm install swagstore-prod ./helm-chart -f values-prod.yaml
```

## Accessing the Application

### With LoadBalancer (default)

```bash
# Get external IP
kubectl get service frontend-external

# Access the application
# Visit http://<EXTERNAL-IP>
```

### With Port Forwarding

```bash
kubectl port-forward deployment/frontend 8080:8080

# Access at http://localhost:8080
```

### With Istio Gateway

```bash
# Get Istio ingress gateway IP
kubectl get service -n istio-system istio-ingressgateway

# Access the application
# Visit http://<GATEWAY-IP>
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods
kubectl describe pod <pod-name>
```

### View Logs

```bash
kubectl logs -f deployment/frontend
kubectl logs -f deployment/cartservice
```

### Check Services

```bash
kubectl get services
kubectl get endpoints
```

### Helm Debug

```bash
# Dry run to see what would be deployed
helm install swagstore ./helm-chart --dry-run --debug

# Check Helm release status
helm status swagstore

# List all releases
helm list
```

### Common Issues

**ImagePullBackOff with Private Registry**
- Ensure imagePullSecrets are configured
- Verify GCR/registry permissions

```bash
# Create imagePullSecret
kubectl create secret docker-registry gcr-secret \
  --docker-server=gcr.io \
  --docker-username=_json_key \
  --docker-password="$(cat key.json)"

# Patch serviceaccount
kubectl patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "gcr-secret"}]}'
```

**Cart Service Can't Connect to Redis**
- Check cartDatabase.connectionString
- Verify redis-cart pod is running
- Check network policies

## Template Structure

The `templates/` directory contains:

- **adservice.yaml**: Ad service deployment and service
- **cartservice.yaml**: Cart service with database configuration
- **checkoutservice.yaml**: Checkout orchestration service
- **currencyservice.yaml**: Currency conversion service
- **emailservice.yaml**: Email notification service
- **frontend.yaml**: Frontend web server and LoadBalancer
- **loadgenerator.yaml**: Synthetic traffic generator
- **paymentservice.yaml**: Payment processing service
- **productcatalogservice.yaml**: Product catalog service
- **recommendationservice.yaml**: Recommendation engine
- **shippingservice.yaml**: Shipping calculation service
- **redis.yaml**: In-cluster Redis database
- **opentelemetry-collector.yaml**: OpenTelemetry collector (optional)
- **common.yaml**: Shared ConfigMap
- **NOTES.txt**: Post-installation notes

## Values File Reference

See [helm-chart/values.yaml](helm-chart/values.yaml) for the complete list of configuration options.

## Additional Resources

- [Main README](README.md) - Project overview and Skaffold deployment
- [Original Google Cloud Documentation](https://github.com/GoogleCloudPlatform/microservices-demo)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Contributing

For issues or feature requests related to the Helm chart, please create a GitHub issue.

## License

Apache License 2.0 - See [LICENSE](LICENSE) for details.



