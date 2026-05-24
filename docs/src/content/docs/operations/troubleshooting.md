---
title: Troubleshooting
---

Common errors encountered when working with ProjectX-Infra and their solutions.

## 1. DNS Timeout in Docker Container

**Error:**

```
Error: Failed to query available provider packages
dial tcp: lookup registry.terraform.io on 192.168.65.7:53: i/o timeout
```

**Cause:** The Docker container cannot resolve DNS names, typically due to Docker Desktop's DNS configuration conflicting with the host network.

**Fix:** Override the container's DNS resolver to use Google's public DNS:

```bash
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

If the issue persists, restart Docker Desktop entirely to reset the DNS subsystem, then rebuild the workbench container.

## 2. Secrets Manager Conflict

**Error:**

```
Error: error creating Secrets Manager Secret: InvalidRequestException:
You can't create this secret because a secret with this name is already scheduled for deletion.
```

**Cause:** A previous `terraform destroy` scheduled the secret for deletion with the default 30-day recovery window. The secret name is reserved during this period.

**Fix:** Force-delete the secret immediately, then re-run your apply:

```bash
aws secretsmanager delete-secret \
  --secret-id "dev/projectx/db-credentials" \
  --force-delete-without-recovery
```

To prevent this in the future, set `recovery_window_in_days = 0` in the secret resource definition.

## 3. VPC Dependency Violation on Destroy

**Error:**

```
Error: error deleting EC2 Subnet (subnet-xxxxxxxxx): DependencyViolation:
The subnet 'subnet-xxxxxxxxx' has dependencies and cannot be deleted.
```

**Cause:** You are attempting to destroy the Infra layer while resources in other layers (Storage, EKS) still have ENIs attached to VPC subnets.

**Fix:** Destroy layers in the correct reverse order:

```bash
make destroy-eks
make destroy-iam
make destroy-storage
make destroy-infra
```

Or use `make destroy-all` which handles the ordering automatically.

## 4. Invalid for_each Argument

**Error:**

```
Error: Invalid for_each argument
The "for_each" set includes values derived from resource attributes
that cannot be determined until apply.
```

**Cause:** Using a resource attribute like `.id` (which is only known after creation) as a `for_each` key.

**Fix:** Use a deterministic attribute such as `.bucket` instead of `.id` in your `for_each` expression:

```hcl
# Wrong — .id is not known until apply
for_each = { for b in aws_s3_bucket.buckets : b.id => b }

# Correct — .bucket is the name, known at plan time
for_each = { for b in aws_s3_bucket.buckets : b.bucket => b }
```

## 5. Unsupported Kubernetes Version

**Error:**

```
Error: error creating EKS Cluster: InvalidParameterException:
Unsupported Kubernetes minor version
```

**Cause:** The `cluster_version` specified in the EKS configuration is no longer supported by AWS. AWS regularly deprecates older Kubernetes versions.

**Fix:** Update `cluster_version` in the EKS module to a currently supported version (currently `1.31`):

```hcl
cluster_version = "1.31"
```

Check the [AWS EKS documentation](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) for the list of supported versions.

## 6. kubectl Connection Refused

**Error:**

```
E0101 00:00:00.000000 dial tcp 127.0.0.1:8080: connect: connection refused
The connection to the server localhost:8080 was refused — did you specify the right host or port?
```

**Cause:** Your kubeconfig is not configured to point at the EKS cluster. kubectl defaults to `localhost:8080` when no cluster context is set.

**Fix:** Run the auth target to configure kubectl:

```bash
make eks-auth
```

This executes `aws eks update-kubeconfig` and sets the correct cluster endpoint and authentication token.

## 7. Invalid IAM ARN

**Error:**

```
Error: error creating IAM Policy: MalformedPolicyDocument:
ARN "aws:policy/AmazonEKSClusterPolicy" is not valid — not enough sections.
```

**Cause:** The IAM policy ARN is missing the `arn:aws:iam::` prefix or account ID section.

**Fix:** Use the full ARN format:

```hcl
# Wrong — incomplete ARN
"aws:policy/AmazonEKSClusterPolicy"

# Correct — full ARN format
"arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
```

AWS-managed policies use the format `arn:aws:iam::aws:policy/PolicyName`.

## 8. EKS aws-auth ConfigMap Error

**Error:**

```
Error: Kubernetes cluster unreachable: the server has asked for the client to provide credentials
```

**Cause:** The Kubernetes provider in Terraform is not properly configured to authenticate with the EKS cluster. This commonly occurs when the `kubernetes` or `helm` provider block is missing the `exec`-based authentication configuration.

**Fix:** Configure the Kubernetes provider to use the EKS cluster's endpoint and exec-based authentication:

```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
```

Ensure the same configuration is applied to the `helm` provider if you are deploying Helm charts via Terraform.

## 9. Lifecycle Rule Filter Warning

**Error:**

```
Warning: Argument is deprecated
Use the "filter" configuration block instead. No attribute specified for "filter".
```

**Cause:** S3 bucket lifecycle rules require an explicit `filter` block in newer versions of the AWS provider. An empty or missing filter triggers this warning.

**Fix:** Add an empty `filter {}` block to the lifecycle rule to apply it to all objects:

```hcl
lifecycle_rule {
  id      = "expire-old-versions"
  enabled = true

  filter {}

  noncurrent_version_expiration {
    days = 30
  }
}
```

An empty `filter {}` is equivalent to "match all objects in the bucket."
