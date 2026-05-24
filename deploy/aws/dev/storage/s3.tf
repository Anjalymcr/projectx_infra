# 1. Terraform State Bucket (The Memory)
resource "aws_s3_bucket" "projectx_tf_state" {
  bucket = "projectx-tf-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
  tags   = local.common_tags
}

# 2. Jenkins Build Artifacts (The Results)
resource "aws_s3_bucket" "projectx_jenkins_artifacts" {
  bucket = "projectx-jenkins-artifacts-${var.environment}-${data.aws_caller_identity.current.account_id}"
  tags   = local.common_tags
}

# 3. Logs & Analytics (The Data Lake)
resource "aws_s3_bucket" "projectx_analytics" {
  bucket = "projectx-analytics-${var.environment}-${data.aws_caller_identity.current.account_id}"
  tags   = local.common_tags
}

# 4. Product Artifacts (The Shippable Software)
resource "aws_s3_bucket" "projectx_release" {
  bucket = "projectx-release-${var.environment}-${data.aws_caller_identity.current.account_id}"
  tags   = local.common_tags
}

# --- PRODUCTION PRACTICE: Enable Versioning for ALL buckets ---
# This acts as a 'Time Machine' for your files.
resource "aws_s3_bucket_versioning" "versions" {
  for_each = toset([
    aws_s3_bucket.projectx_tf_state.bucket,
    aws_s3_bucket.projectx_jenkins_artifacts.bucket,
    aws_s3_bucket.projectx_analytics.bucket,
    aws_s3_bucket.projectx_release.bucket
  ])

  bucket = each.value
  versioning_configuration {
    status = "Enabled"
  }
}

# --- SECURITY: Block all public access ---
resource "aws_s3_bucket_public_access_block" "security_lock" {
  for_each = toset([
    aws_s3_bucket.projectx_tf_state.bucket,
    aws_s3_bucket.projectx_jenkins_artifacts.bucket,
    aws_s3_bucket.projectx_analytics.bucket,
    aws_s3_bucket.projectx_release.bucket
  ])

  bucket = each.value

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

# --- LIFECYCLE MANAGEMENT (The Cleaning Robot) ---
resource "aws_s3_bucket_lifecycle_configuration" "cleanup_robot" {
  for_each = toset([
    aws_s3_bucket.projectx_jenkins_artifacts.bucket,
    aws_s3_bucket.projectx_analytics.bucket
  ])

  bucket = each.value

  rule {
    id     = "auto-delete-old-data"
    status = "Enabled"
    filter {}

    # Rule: If a file is 30 days old, delete it to save cost
    expiration {
      days = 30
    }

    # Rule: If we have an old "Version" of a file, delete it after 7 days
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}