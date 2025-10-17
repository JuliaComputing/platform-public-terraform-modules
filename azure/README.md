# Azure AKS for JuliaHub Platform

This Terraform project deploys a complete Azure infrastructure for hosting the JuliaHub Platform, including:

- **Azure Kubernetes Service (AKS)** with autoscaling and Azure Application Gateway for Containers
- **Azure Database for PostgreSQL Flexible Server** with private networking
- **Azure Files Premium** storage for shared configuration
- **Azure Blob Storage** for data and backups
- **Virtual Network** with subnets, NSGs, and private endpoints

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Resource Group                        │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Virtual Network (VNet)               │   │
│  │                                                    │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌──────────┐│   │
│  │  │ AKS Subnet  │  │ PostgreSQL   │  │ Private  ││   │
│  │  │             │  │ Subnet       │  │ Endpoints││   │
│  │  │  (3-10      │  │              │  │ Subnet   ││   │
│  │  │   nodes)    │  │  (Flexible   │  │          ││   │
│  │  │             │  │   Server)    │  │ (Storage ││   │
│  │  │             │  │              │  │  PE's)   ││   │
│  │  └─────────────┘  └──────────────┘  └──────────┘│   │
│  │                                                    │   │
│  │  NSGs + Private DNS Zones                         │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │    AKS Cluster (Azure CNI Overlay)                │   │
│  │    • Standard_D4s_v6 nodes (4 vCPU, 16GB each)   │   │
│  │    • Autoscaling: 3-10 nodes                      │   │
│  │    • Azure Disk, File, Blob CSI drivers           │   │
│  │    • Application Gateway for Containers           │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │    PostgreSQL Flexible Server                     │   │
│  │    • B_Standard_B2s (2 vCore)                     │   │
│  │    • 32GB storage, 30-day backup retention        │   │
│  │    • Private endpoint access only                 │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │    Azure Files Premium                            │   │
│  │    • 100GB juliahub-config share                  │   │
│  │    • SMB protocol, private endpoint               │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │    Azure Blob Storage                             │   │
│  │    • Standard LRS                                 │   │
│  │    • data, backups containers                     │   │
│  │    • Private endpoint access                      │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

- **Terraform** >= 1.5.0
- **Azure CLI** >= 2.50.0
- **kubectl** (for interacting with AKS)
- Azure subscription with appropriate permissions

## Quick Start

### 1. Authenticate with Azure

```bash
az login
az account set --subscription "<subscription-id>"
```

### 2. Configure Variables

Copy the example tfvars file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

**Important**: Update the following values in `terraform.tfvars`:
- `files_storage_account_name` - Must be globally unique (3-24 lowercase alphanumeric)
- `blob_storage_account_name` - Must be globally unique (3-24 lowercase alphanumeric)
- `location` - Your preferred Azure region
- `tags` - Your organization's tags for cost tracking

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan the Deployment

```bash
terraform plan -out=tfplan
```

### 5. Apply the Configuration

```bash
terraform apply tfplan
```

The deployment typically takes 15-20 minutes.

## Post-Deployment Setup

### Connect to AKS Cluster

```bash
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)

kubectl get nodes
```

### Apply Storage Classes

```bash
# Azure Disk storage classes
terraform output -raw aks_storage_classes_yaml | kubectl apply -f -

# Azure Files storage class
terraform output -raw storage_files_kubernetes_storage_class_yaml | kubectl apply -f -

# Azure Blob storage classes
terraform output -raw storage_blob_kubernetes_storage_class_yaml | kubectl apply -f -
```

### Create Kubernetes Secrets

#### PostgreSQL Connection

```bash
kubectl create secret generic postgresql-connection \
  --from-literal=host=$(terraform output -raw postgresql_server_fqdn) \
  --from-literal=port=5432 \
  --from-literal=database=$(terraform output -raw postgresql_database_name) \
  --from-literal=username=$(terraform output -raw postgresql_administrator_login) \
  --from-literal=password=$(terraform output -raw postgresql_administrator_password)
```

#### Azure Files Credentials

```bash
kubectl create secret generic azure-files-secret \
  --from-literal=azurestorageaccountname=$(terraform output -raw storage_files_account_name) \
  --from-literal=azurestorageaccountkey=$(terraform output -raw storage_files_primary_access_key)
```

#### Azure Blob Credentials

```bash
kubectl create secret generic azure-blob-secret \
  --from-literal=azurestorageaccountname=$(terraform output -raw storage_blob_account_name) \
  --from-literal=azurestorageaccountkey=$(terraform output -raw storage_blob_primary_access_key)
```

### Apply Persistent Volume for juliahub-config

```bash
terraform output -raw storage_files_kubernetes_pv_yaml | kubectl apply -f -
```

## Module Structure

```
azure/
├── main.tf                         # Root module orchestration
├── variables.tf                    # Root module variables
├── outputs.tf                      # Root module outputs
├── terraform.tfvars.example        # Example configuration
├── README.md                       # This file
└── modules/
    ├── networking/                 # VNet, subnets, NSGs, DNS
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    ├── aks/                        # AKS cluster
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    ├── postgresql/                 # PostgreSQL Flexible Server
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    ├── storage-files/              # Azure Files
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    └── storage-blob/               # Azure Blob Storage
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── README.md
```

## Key Features

### AKS Cluster
- **Autoscaling**: Automatically scales between 3-10 nodes based on demand
- **Azure CNI Overlay**: Efficient IP address utilization with overlay networking
- **Standard Load Balancer**: Production-grade load balancing
- **CSI Drivers**: Support for Azure Disks, Files, and Blobs
- **Application Gateway**: Azure Application Gateway for Containers for ingress
- **Total Capacity**: 12-40 vCPU, 48-160 GB RAM (exceeds 8 core/30GB requirement)

### PostgreSQL Flexible Server
- **Private Access**: Only accessible within the VNet
- **Automated Backups**: 30-day retention with point-in-time restore
- **Performance**: B-Series burstable compute for cost-effective test workloads
- **Encryption**: At rest with Azure-managed keys

### Storage
- **Azure Files Premium**: Low-latency shared storage for configuration
- **Azure Blob Storage**: Scalable object storage for data and backups
- **Private Endpoints**: All storage traffic stays within the VNet
- **Soft Delete**: 7-day retention for deleted blobs and containers

### Networking
- **Private Endpoints**: PostgreSQL and storage accounts not exposed to internet
- **Network Security Groups**: Granular traffic control
- **Private DNS**: Automatic DNS resolution for private endpoints
- **Service Endpoints**: Direct routing from subnets to Azure services

## Resource Requirements

Based on the default configuration:

| Resource | Specification | Cost Estimate (monthly, eastus) |
|----------|---------------|----------------------------------|
| AKS Nodes | 3x Standard_D4s_v6 | ~$350 |
| PostgreSQL | B_Standard_B2s | ~$30 |
| Azure Files | 100GB Premium | ~$15 |
| Azure Blob | Standard LRS | ~$2 (storage) + usage |
| Networking | VNet, NSGs, Private Endpoints | ~$15 |
| **Total** | | **~$412/month** |

*Estimates are approximate and vary by region. Check Azure Pricing Calculator for accurate pricing.*

## Cost Optimization

For test/development environments:
- Reduce `aks_max_node_count` to limit maximum scale
- Use `aks_min_node_count = 1` during off-hours
- Consider smaller VM sizes like `Standard_D2s_v6`
- Reduce PostgreSQL to smaller SKU if workload allows
- Use Standard tier for Azure Files if latency is acceptable

## Security Features

- **No Public Access**: PostgreSQL and storage accounts accessible only via VNet
- **Encryption at Rest**: All data encrypted with Azure-managed keys
- **TLS 1.2+**: Enforced for all connections
- **Network Isolation**: Private endpoints keep traffic within Azure backbone
- **Managed Identities**: AKS uses system-assigned identity for Azure resource access
- **Secret Management**: Sensitive outputs marked as sensitive in Terraform
- **NSG Rules**: Explicit security group rules for network segmentation

## Terraform Outputs

Use `terraform output` to retrieve values:

```bash
# Get deployment summary
terraform output deployment_summary

# Get AKS credentials (sensitive)
terraform output -raw aks_kube_config > ~/.kube/config

# Get PostgreSQL connection info
terraform output postgresql_server_fqdn
terraform output -raw postgresql_connection_string

# Get storage account names
terraform output storage_files_account_name
terraform output storage_blob_account_name
```

## Troubleshooting

### Storage Account Name Conflicts

If you get an error about storage account names already being taken:

```bash
# Try a different suffix
files_storage_account_name = "juliahubfiles2024"
blob_storage_account_name  = "juliahubblob2024"
```

Storage account names must be globally unique across all Azure.

### AKS Connection Issues

```bash
# Verify AKS is running
az aks show --resource-group <rg-name> --name <aks-name> --query provisioningState

# Re-fetch credentials
az aks get-credentials --resource-group <rg-name> --name <aks-name> --overwrite-existing
```

### PostgreSQL Connection Issues

Ensure you're connecting from within the AKS cluster or VNet:

```bash
# Test from a pod
kubectl run postgres-test --rm -it --restart=Never --image=postgres:13 -- \
  psql "host=$(terraform output -raw postgresql_server_fqdn) port=5432 dbname=$(terraform output -raw postgresql_database_name) user=$(terraform output -raw postgresql_administrator_login) password=$(terraform output -raw postgresql_administrator_password) sslmode=require"
```

### Private Endpoint DNS Resolution

Private DNS zones are linked to the VNet. DNS resolution only works from within the VNet.

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete all data in storage accounts and databases. Ensure you have backups if needed.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | ~> 4.0 |
| random | ~> 3.0 |


## Inputs

See [variables.tf](variables.tf) for all configurable variables and their descriptions.

Key required variables:
- `resource_group_name`
- `location`
- `vnet_name`
- `aks_cluster_name`
- `aks_dns_prefix`
- `postgresql_server_name`
- `files_storage_account_name` (must be globally unique)
- `blob_storage_account_name` (must be globally unique)

## Outputs

See [outputs.tf](outputs.tf) for all outputs. Key outputs include:
- AKS cluster credentials and FQDN
- PostgreSQL connection information
- Storage account names and access keys
- Kubernetes YAML configurations for storage classes and secrets

## Example: Deploy Nginx with Application Gateway Ingress

This example demonstrates how to deploy an nginx pod that uses the juliahub-config PersistentVolume and exposes it through the Azure Application Gateway for Containers.

### 1. Create the Nginx Deployment and Service

Create a file called `nginx-example.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>JuliaHub Platform</title>
    </head>
    <body>
        <h1>Welcome to JuliaHub on AKS</h1>
        <p>This nginx server is using Azure Files Premium storage.</p>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-demo
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config-volume
          mountPath: /usr/share/nginx/html
          readOnly: true
        - name: juliahub-config
          mountPath: /etc/juliahub
      volumes:
      - name: config-volume
        configMap:
          name: nginx-config
      - name: juliahub-config
        persistentVolumeClaim:
          claimName: juliahub-config-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-demo
  namespace: default
spec:
  selector:
    app: nginx-demo
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

Apply the configuration:

```bash
kubectl apply -f nginx-example.yaml
```

### 2. Create the Ingress Resource

Create a file called `nginx-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-demo
  namespace: default
  annotations:
    # Azure Application Gateway for Containers annotations
    kubernetes.azure.com/use-application-gateway: "true"
spec:
  ingressClassName: webapprouting.kubernetes.azure.com
  rules:
  - host: nginx-demo.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-demo
            port:
              number: 80
```

Apply the ingress:

```bash
kubectl apply -f nginx-ingress.yaml
```

### 3. Verify the Deployment

Check the pods are running:

```bash
kubectl get pods -l app=nginx-demo
```

Check the service:

```bash
kubectl get svc nginx-demo
```

Check the ingress and get the external IP:

```bash
kubectl get ingress nginx-demo
```

### 4. Test the Application

Wait for the ingress to receive an external IP address (this may take a few minutes), then test:

```bash
# Get the external IP
EXTERNAL_IP=$(kubectl get ingress nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test with curl (using Host header since we don't have DNS set up)
curl -H "Host: nginx-demo.example.com" http://$EXTERNAL_IP
```

### 5. Verify Azure Files Mount

You can verify the juliahub-config PersistentVolume is mounted:

```bash
# Exec into one of the nginx pods
kubectl exec -it deployment/nginx-demo -- ls -la /etc/juliahub

# Create a test file in the shared storage
kubectl exec -it deployment/nginx-demo -- sh -c "echo 'test' > /etc/juliahub/test.txt"

# Verify the file appears in all pods (since it's shared storage)
kubectl get pods -l app=nginx-demo -o name | while read pod; do
  echo "Checking $pod:"
  kubectl exec $pod -- cat /etc/juliahub/test.txt
done
```

### Notes

- The Azure Application Gateway for Containers is automatically configured through the AKS `web_app_routing` addon
- The ingress uses the `webapprouting.kubernetes.azure.com` ingress class which is created by the addon
- For production use, configure proper DNS records pointing to the ingress external IP
- The nginx pods mount both a ConfigMap (for the HTML content) and the juliahub-config PersistentVolume (demonstrating shared storage)
- The juliahub-config volume is ReadWriteMany, so all replicas can access the same shared storage

