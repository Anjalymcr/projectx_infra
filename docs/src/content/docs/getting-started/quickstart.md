---
title: Quickstart
---

This guide takes you from a fresh clone to a fully deployed AWS environment in `ap-southeast-2`. Every command runs inside the Dev Container so your host machine only needs Docker Desktop and Git.

## 1. Clone the Repository

```bash
git clone <your-repo-url> projectx-infra
cd projectx-infra
```

## 2. Open in Dev Container

Open the project in VS Code, then press `Cmd+Shift+P` and select **"Dev Containers: Reopen in Container"**. The container comes with Terraform, kubectl, Helm, and AWS CLI pre-installed.

## 3. Configure AWS Credentials

Inside the container, set your AWS credentials:

```bash
export AWS_ACCESS_KEY_ID="<your-access-key>"
export AWS_SECRET_ACCESS_KEY="<your-secret-key>"
export AWS_DEFAULT_REGION="ap-southeast-2"
```

Alternatively, use a named profile:

```bash
aws configure --profile svc-deployer
export AWS_PROFILE=svc-deployer
```

Verify access:

```bash
aws sts get-caller-identity
```

## 4. Initialise All Terraform Layers

```bash
make init-all
```

This runs `terraform init` in each layer directory (`infra/`, `storage/`, `iam/`, `dns/`, `eks/`).

## 5. Deploy All Layers

Deploy everything in one command:

```bash
make deploy-all
```

This deploys in order: Infra -> Storage -> IAM -> DNS -> EKS (including ALB Controller, Cluster Autoscaler, Fluent Bit, and ExternalDNS).

Or deploy layer by layer:

```bash
make infra-apply      # Layer 1 -- VPC, subnets, NAT gateway
make storage-apply    # Layer 2 -- RDS, EFS, ECR, S3
make iam-apply        # Layer 3 -- IAM roles and policies
make dns-apply        # Layer 4 -- Route53 private hosted zone
make eks-apply        # Layer 5 -- EKS cluster and all addons
```

## 6. Connect to the EKS Cluster

```bash
make eks-auth
kubectl get nodes
```

You should see the system and runner node groups in a `Ready` state.

## 7. Deploy Applications

```bash
make jenkins-deploy       # Jenkins CI/CD
make platform-deploy      # Prometheus + Grafana monitoring
```

## 8. Access the Applications

Get the ALB URLs:

```bash
kubectl get ingress -n jenkins
kubectl get ingress -n monitoring
```

Get credentials:

```bash
# Jenkins
kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-user}' | base64 -d && echo
kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d && echo

# Grafana
kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d && echo
# Username: admin
```

## Tearing Everything Down

```bash
make destroy-all
```

This automatically uninstalls all Helm releases (Jenkins, Grafana, Prometheus), waits for ALB cleanup, then destroys all Terraform layers in reverse order: EKS -> DNS -> IAM -> Storage -> Infra.
