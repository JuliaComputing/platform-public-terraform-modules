# VPC Module

Creates a VPC suitable for hosting an EKS cluster that runs the JuliaHub Platform.

## Features

- **Public and private subnets** distributed round-robin across the configured availability zones
- **Subnet tagging** for EKS load balancer discovery (`kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`) and Karpenter node placement (`karpenter.sh/discovery`)
- **NAT gateways**, one per public subnet, or bring your own via `nat_gateway_ids` when egress must route through a firewall you manage
- **VPC endpoints** for ECR and S3 by default, with RDS, Bedrock, and arbitrary PrivateLink services available

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  cluster_name = "juliahub"
  region       = "us-east-1"

  vpc_cidr             = "192.168.0.0/16"
  public_subnet_cidrs  = ["192.168.0.0/18", "192.168.64.0/18"]
  private_subnet_cidrs = ["192.168.128.0/18", "192.168.192.0/18"]
  availability_zones   = ["us-east-1a", "us-east-1c"]

  tags = {
    Environment = "production"
  }
}
```

## Subnet placement

Subnets are assigned to availability zones round-robin over `availability_zones`. With the two-subnet default and two zones, each public/private pair lands in a distinct zone, which is what EKS requires.

Supplying more subnet CIDRs than zones wraps around, placing multiple subnets in the same zone. That is valid, but interface VPC endpoints get at most one subnet per zone.

## NAT gateways

By default one NAT gateway is created per public subnet, and each private subnet routes through the gateway in its own zone. This is zone-resilient but costs one NAT gateway per zone.

For a cheaper single-gateway setup, use one public subnet CIDR. For egress through a firewall you manage, pass existing gateway IDs in `nat_gateway_ids`; the module then creates none.

## VPC endpoints

`enable_ecr_vpc_endpoint` creates both `ecr.dkr` and `ecr.api` — image pulls need both. The S3 gateway endpoint is associated with every route table this module creates.

Interface endpoints share one security group allowing HTTPS from `vpc_endpoint_ingress_cidrs`, which defaults to the VPC CIDR.

For PrivateLink services specific to your environment, use `additional_interface_vpc_endpoints`:

```hcl
additional_interface_vpc_endpoints = {
  "vendor-api" = {
    service_name        = "com.amazonaws.vpce.us-east-1.vpce-svc-0123456789abcdef0"
    private_dns_enabled = true
  }
}
```

## Inputs

See [`variables.tf`](variables.tf) for the full list with descriptions and defaults.

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_id` | ID of the VPC |
| `vpc_cidr_block` | Primary CIDR block |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs, where nodes run |
| `subnet_ids` | All subnet IDs, for the EKS control plane |
| `route_table_ids` | All route table IDs |
| `internet_gateway_id` | Internet gateway ID |
| `nat_gateway_ids` | NAT gateway IDs in use, created or supplied |
| `vpc_endpoint_security_group_id` | Security group on the interface endpoints, or `null` if none are enabled |
