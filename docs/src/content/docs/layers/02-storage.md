---
title: "Layer 2: Storage (RDS, EFS, ECR, S3)"
---

## Purpose

Layer 2 provisions all data persistence, container registry, and object storage resources. This includes the relational database for application metrics, a shared filesystem for Jenkins, container image repositories, and S3 buckets for artifacts and state management.

## Directory Structure

```
deploy/aws/dev/storage/
├── rds.tf           # RDS MySQL instance and supporting resources
├── efs.tf           # EFS filesystem and access points
├── ecr.tf           # ECR repositories and lifecycle policies
├── s3.tf            # S3 buckets with versioning and lifecycle rules
├── secrets.tf       # Secrets Manager for database credentials
├── locals.tf        # Local values and computed expressions
├── variables.tf     # Input variable declarations
└── versions.tf      # Terraform and provider version constraints
```

## Dependencies

**Depends on: Layer 1 (Infrastructure)**

The VPC must exist before storage resources can be provisioned. This layer uses data sources to look up the VPC by tag rather than relying on remote state:

```hcl
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${local.project}-vpc"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
```

## RDS (MySQL)

A MySQL database instance for application metrics storage.

```hcl
resource "aws_db_instance" "projectx" {
  identifier     = "${local.project}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  storage_type   = "gp3"

  db_name  = "projectx_metrics"
  username = "admin"
  password = aws_secretsmanager_secret_version.db_password.secret_string

  db_subnet_group_name   = aws_db_subnet_group.private.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true

  tags = local.common_tags
}
```

| Parameter | Value |
|-----------|-------|
| Engine | MySQL 8.0 |
| Instance Class | `db.t3.micro` |
| Storage Type | `gp3` |
| Database Name | `projectx_metrics` |
| Password Source | AWS Secrets Manager |
| Subnet Group | Private subnets only |
| Security Group | Allows inbound on port 3306 |

### RDS Security Group

```hcl
resource "aws_security_group" "rds" {
  name_prefix = "${local.project}-rds-"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  tags = local.common_tags
}
```

## EFS (Elastic File System)

A shared filesystem used as persistent storage for Jenkins home directory.

```hcl
module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "1.3.0"

  name            = "${local.project}-efs"
  encrypted       = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy = {
    transition_to_ia = "AFTER_30_DAYS"
  }

  access_points = {
    jenkins = {
      posix_user = {
        uid = 1000
        gid = 1000
      }
      root_directory = {
        path = "/var/jenkins_home"
        creation_info = {
          owner_uid   = 1000
          owner_gid   = 1000
          permissions = "755"
        }
      }
    }
  }

  tags = local.common_tags
}
```

| Parameter | Value |
|-----------|-------|
| Encryption | Enabled |
| Performance Mode | `generalPurpose` |
| Throughput Mode | `bursting` |
| IA Transition | After 30 days |
| Access Point | `/var/jenkins_home` (UID/GID 1000, permissions 755) |

## ECR (Elastic Container Registry)

Two container image repositories for the project.

```hcl
resource "aws_ecr_repository" "projectx_app" {
  name                 = "projectx-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "infra_tools" {
  name                 = "infra-tools"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}
```

| Repository | Scan on Push | Lifecycle Policies |
|------------|-------------|-------------------|
| `projectx-app` | Yes | Delete untagged images after 5 days; keep 50 most recent tagged images |
| `infra-tools` | Yes | Delete untagged images after 5 days; keep 50 most recent tagged images |

### ECR Lifecycle Policy

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Remove untagged images after 5 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 5
      },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "Keep only 50 most recent images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 50
      },
      "action": { "type": "expire" }
    }
  ]
}
```

## S3 Buckets

Four S3 buckets, all with versioning enabled and all public access blocked.

| Bucket | Purpose | Lifecycle Rules |
|--------|---------|-----------------|
| `tf-state` | Terraform remote state storage | None (retain all versions) |
| `jenkins-artifacts` | CI/CD build artifacts | 30-day expiration, 7-day noncurrent version deletion |
| `analytics` | Analytics data and reports | 30-day expiration, 7-day noncurrent version deletion |
| `release` | Release packages and binaries | None (retain all versions) |

```hcl
resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.project}-jenkins-artifacts"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
```

## Secrets Manager

Database credentials are generated and stored in AWS Secrets Manager.

```hcl
resource "random_password" "db" {
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.project}/db-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}
```

| Parameter | Value |
|-----------|-------|
| Password Length | 16 characters |
| Special Characters | Enabled |
| Recovery Window | 0 days (immediate deletion on destroy) |

:::note
Setting `recovery_window_in_days = 0` means the secret is immediately deleted when the Terraform resource is destroyed. This is appropriate for dev environments but should be set to 7 or 30 days in production.
:::

## Commands

```bash
# Initialize Terraform working directory and download providers/modules
make storage-init

# Preview changes without applying
make storage-plan

# Apply the storage resources
make storage-apply
```
