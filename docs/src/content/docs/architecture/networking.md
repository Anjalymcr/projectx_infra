---
title: Network Architecture
---

The network layer (Layer 1) establishes the foundational VPC and subnet topology for the entire ProjectX-Infra platform. All resources across every subsequent layer are deployed into this network. The design prioritises high availability, security isolation, and compatibility with Amazon EKS networking requirements.

## VPC Design

| Property | Value |
|----------|-------|
| **VPC CIDR** | `10.0.0.0/16` (65,536 addresses) |
| **Region** | `ap-southeast-2` (Sydney) |
| **Availability Zones** | 3 -- `ap-southeast-2a`, `ap-southeast-2b`, `ap-southeast-2c` |
| **DNS Hostnames** | Enabled |
| **DNS Resolution** | Enabled |

The `/16` CIDR block provides ample address space for current workloads and future expansion. DNS hostnames and resolution are enabled to support private hosted zones, service discovery, and EKS internal DNS.

## Subnet Architecture

The VPC is divided into two tiers -- **private** and **public** -- each replicated across all three Availability Zones. This gives the platform six subnets in total.

### Subnet Table

| Subnet Name | CIDR Block | AZ | Tier | Purpose |
|-------------|------------|-----|------|---------|
| `private-ap-southeast-2a` | `10.0.1.0/24` | ap-southeast-2a | Private | EKS worker nodes, RDS, EFS mount targets |
| `private-ap-southeast-2b` | `10.0.2.0/24` | ap-southeast-2b | Private | EKS worker nodes, RDS, EFS mount targets |
| `private-ap-southeast-2c` | `10.0.3.0/24` | ap-southeast-2c | Private | EKS worker nodes, RDS, EFS mount targets |
| `public-ap-southeast-2a` | `10.0.101.0/24` | ap-southeast-2a | Public | NAT gateway, ALB, bastion (if needed) |
| `public-ap-southeast-2b` | `10.0.102.0/24` | ap-southeast-2b | Public | NAT gateway, ALB |
| `public-ap-southeast-2c` | `10.0.103.0/24` | ap-southeast-2c | Public | NAT gateway, ALB |

Each `/24` subnet provides 251 usable IP addresses (256 minus 5 reserved by AWS). Private subnets use the `10.0.1-3.0/24` range while public subnets use `10.0.101-103.0/24`, keeping the two tiers clearly separated in the address space.

## NAT Gateway Topology

The platform deploys **one NAT gateway per Availability Zone**, placed in the corresponding public subnet. Each private subnet's route table points to the NAT gateway in its own AZ.

```
AZ-a:  private-2a  -->  NAT-GW-a (in public-2a)  -->  Internet Gateway
AZ-b:  private-2b  -->  NAT-GW-b (in public-2b)  -->  Internet Gateway
AZ-c:  private-2c  -->  NAT-GW-c (in public-2c)  -->  Internet Gateway
```

This triple-NAT design provides:

- **High availability** -- If one AZ experiences an outage, the other two AZs retain independent internet egress. There is no single point of failure.
- **Reduced cross-AZ data transfer costs** -- Traffic from a private subnet exits through the NAT gateway in the same AZ, avoiding inter-AZ data transfer charges (which AWS bills at ~$0.01/GB).
- **Better throughput** -- Each NAT gateway supports up to 45 Gbps. Distributing traffic across three gateways triples the aggregate egress capacity.

## VPC Endpoints

| Endpoint | Type | Purpose |
|----------|------|---------|
| **S3 Gateway** | Gateway | Routes S3 traffic over the AWS private network instead of the public internet. Eliminates NAT gateway data processing charges for S3 operations, which are typically the highest-volume traffic in the platform (Terraform state, application data, logs). |

Gateway endpoints are free and add route table entries rather than ENIs, so they carry no per-hour or per-GB cost. Additional interface endpoints (ECR, STS, CloudWatch) may be added in future iterations to further reduce NAT gateway costs and improve security posture.

## Kubernetes Subnet Tags

For the AWS Load Balancer Controller to automatically discover subnets when provisioning Application Load Balancers (ALBs) and Network Load Balancers (NLBs), the subnets carry the following tags:

### Private Subnets

| Tag Key | Value | Purpose |
|---------|-------|---------|
| `kubernetes.io/role/internal-elb` | `1` | Marks these subnets as candidates for internal (private) load balancers. |
| `kubernetes.io/cluster/projectx-cluster` | `shared` | Associates the subnet with the EKS cluster for controller discovery. |

### Public Subnets

| Tag Key | Value | Purpose |
|---------|-------|---------|
| `kubernetes.io/role/elb` | `1` | Marks these subnets as candidates for internet-facing load balancers. |
| `kubernetes.io/cluster/projectx-cluster` | `shared` | Associates the subnet with the EKS cluster for controller discovery. |

The `shared` value (rather than `owned`) allows multiple clusters or external resources to coexist in the same subnets if needed.

## Route Tables

The layer creates **four route tables**:

1. **Public route table** (shared by all three public subnets) -- Default route `0.0.0.0/0` points to the Internet Gateway.
2. **Private route table AZ-a** -- Default route `0.0.0.0/0` points to NAT-GW-a.
3. **Private route table AZ-b** -- Default route `0.0.0.0/0` points to NAT-GW-b.
4. **Private route table AZ-c** -- Default route `0.0.0.0/0` points to NAT-GW-c.

The S3 Gateway endpoint automatically injects its prefix list route into all four route tables.

## Security Considerations

- **Private subnets have no direct inbound internet access.** Ingress to workloads is handled exclusively through load balancers deployed in the public subnets.
- **Public subnets auto-assign public IPs** only for NAT gateways and load balancers. EKS worker nodes and databases never receive public IP addresses.
- **Network ACLs** use the default allow-all configuration at the subnet level. Fine-grained access control is enforced through **Security Groups** attached to individual resources (RDS, EFS, EKS nodes, ALBs) in their respective layers.
- **VPC Flow Logs** can be enabled to capture accepted and rejected traffic for audit and troubleshooting purposes.
