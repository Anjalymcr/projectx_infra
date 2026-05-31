locals {
  # PRODUCTION BEST PRACTICE: Aggressive Lifecycle Management
  # This saves thousands of dollars by deleting images we don't need
  default_registry_lifecycle = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Delete untagged (ghost) images after 5 days",
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
            "description": "Keep only the 50 most recent versioned images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 50
            },
            "action": { "type": "expire" }
        }
    ]
}
EOF
}

# 1. Primary App Registry (Where your VeloCloud clone code will live)
resource "aws_ecr_repository" "projectx_app" {
  name                 = "${var.environment}-projectx-app"
  image_tag_mutability = "IMMUTABLE"

  # SECURITY: Scanning for vulnerabilities on every push
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# 2. Infra Tooling Registry (Where your Workbench image will live)
resource "aws_ecr_repository" "infra_tools" {
  name                 = "${var.environment}-infra-tools"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# 3. Attach Lifecycle Policies
resource "aws_ecr_lifecycle_policy" "projectx_app_cleanup" {
  repository = aws_ecr_repository.projectx_app.name
  policy     = local.default_registry_lifecycle
}

resource "aws_ecr_lifecycle_policy" "infra_tools_cleanup" {
  repository = aws_ecr_repository.infra_tools.name
  policy     = local.default_registry_lifecycle
}

# OUTPUTS
output "app_repo_url" {
  value = aws_ecr_repository.projectx_app.repository_url
}
