---
title: Quickstart
---

This guide takes you from a fresh clone to a fully deployed AWS environment in `ap-southeast-2`. Every command runs inside the Docker workbench so your host machine only needs Docker Desktop and Git.

## 1. Clone the Repository

```bash
git clone <your-repo-url> projectx-infra
cd projectx-infra
```

## 2. Build and Enter the Docker Workbench

The workbench is an Ubuntu 22.04 container with Terraform 1.5.2, kubectl 1.27.5, Helm 3.12.3, and AWS CLI v2 pre-installed.

```bash
make docker-build
```

Once the image is built, start an interactive session:

```bash
make docker-dev
```

You will be dropped into a shell inside the container with the project directory mounted at `/workspace`.

## 3. Configure AWS Credentials

Inside the workbench, set your AWS credentials so Terraform can authenticate:

```bash
export AWS_ACCESS_KEY_ID="<your-access-key>"
export AWS_SECRET_ACCESS_KEY="<your-secret-key>"
export AWS_DEFAULT_REGION="ap-southeast-2"
```

Alternatively, use a named profile:

```bash
aws configure --profile projectx
export AWS_PROFILE=projectx
```

Verify access:

```bash
aws sts get-caller-identity
```

You should see your account ID, ARN, and user ID printed to the console.

## 4. Initialise All Terraform Layers

Run a single command to initialise the backend and download providers for every layer:

```bash
make init-all
```

This runs `terraform init` in each layer directory (`infra/`, `storage/`, `iam/`, `eks/`) and configures the S3 remote state backend.

## 5. Deploy Layer 1 -- Network & Infrastructure

Start with the foundational layer (VPC, subnets, NAT gateways, endpoints):

```bash
make infra-plan    # Review the execution plan
make infra-apply   # Apply the changes (creates ~25 resources)
```

The plan output lists every resource that will be created. Review it carefully before applying.

## 6. Deploy the Remaining Layers

With networking in place, deploy the remaining layers in order:

```bash
# Layer 2 -- Storage (RDS, EFS, ECR, S3)
make storage-plan
make storage-apply

# Layer 3 -- IAM (roles, policies, instance profiles)
make iam-plan
make iam-apply

# Layer 4 -- Compute (EKS cluster and node groups)
make eks-plan
make eks-apply
```

> **Important:** Layers must be applied in order because each layer depends on outputs from the previous one (for example, EKS needs the VPC and subnet IDs created by the infra layer).

## 7. Connect to the EKS Cluster

After the EKS layer is applied, update your local kubeconfig:

```bash
aws eks update-kubeconfig \
  --region ap-southeast-2 \
  --name projectx-cluster
```

Verify connectivity:

```bash
kubectl get nodes
```

You should see the managed node group instances in a `Ready` state.

## Next Steps

- Read the [Architecture Overview](/architecture/overview/) to understand the full six-layer model.
- Explore each [Layer](/layers/) in detail for configuration options and variables.
- Check the [Operations](/operations/) guides for day-2 tasks like scaling, upgrades, and teardown.

## Tearing Everything Down

To destroy all resources in reverse order:

```bash
make destroy-all
```

This runs `terraform destroy` on each layer from EKS down to Infra, cleaning up the entire stack. You will be prompted to confirm each layer's destruction.
