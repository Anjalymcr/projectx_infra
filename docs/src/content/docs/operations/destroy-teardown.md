---
title: Destroy & Teardown
---

Tearing down ProjectX-Infra requires strict reverse-order destruction. This page explains why order matters, how to use the automated and manual destroy targets, and how to handle stuck resources.

## Destruction Order

:::caution[Critical]
Resources must be destroyed in reverse dependency order. Destroying out of order will leave orphaned resources and cause Terraform errors.
:::

The correct destruction sequence is:

```
EKS (Layer 4) → IAM (Layer 3) → Storage (Layer 2) → Infra (Layer 1)
```

This is the exact reverse of the deployment order.

### Why Order Matters

The Infra layer creates the VPC, subnets, and security groups that all other layers depend on. If you attempt to destroy Infra first:

- **VPC subnets cannot be deleted** while RDS instances (Storage layer) still have Elastic Network Interfaces (ENIs) attached to them.
- **Security groups cannot be deleted** while EKS node groups or RDS instances reference them.
- **Terraform will fail** with `DependencyViolation` errors and leave the state in a partially destroyed, difficult-to-recover configuration.

## Automated Full Teardown

```bash
make destroy-all
```

This target handles reverse-order destruction automatically, running:

1. `destroy-eks`
2. `destroy-iam`
3. `destroy-storage`
4. `destroy-infra`

Each step uses `|| true` to continue even if an individual destroy fails. This is intentional — some resources may already be absent or may require a second pass. If `destroy-all` reports errors, re-run it to catch resources that were blocked by dependencies on the first pass.

## Individual Destroy Targets

Use these when you need to tear down a specific layer.

### Destroy EKS (Layer 4)

```bash
make destroy-eks
```

Destroys the EKS cluster, managed node groups, and cluster add-ons. Always destroy this first.

### Destroy IAM (Layer 3)

```bash
make destroy-iam
```

Destroys IAM roles, policies, and instance profiles. Only run after EKS has been destroyed — EKS node groups reference these roles.

### Destroy Storage (Layer 2)

```bash
make destroy-storage
```

Destroys S3 buckets, RDS instances, and Secrets Manager entries. Only run after EKS has been destroyed — the database may have active connections from cluster workloads.

### Destroy Infra (Layer 1)

```bash
make destroy-infra
```

Destroys the VPC, subnets, NAT gateways, internet gateways, and security groups. Only run after all other layers have been destroyed.

## Secrets Manager Deletion Behavior

AWS Secrets Manager does not delete secrets immediately by default. When Terraform destroys a secret, it is **scheduled for deletion with a 30-day recovery window**. During this window:

- The secret name is reserved and cannot be reused.
- Re-deploying the stack will fail with a `secret already exists` or `secret scheduled for deletion` error.

To force immediate deletion (bypassing the recovery window), set the `recovery_window_in_days` variable to `0` in your Terraform configuration:

```hcl
resource "aws_secretsmanager_secret" "example" {
  name                    = "my-secret"
  recovery_window_in_days = 0
}
```

Or delete manually via the AWS CLI:

```bash
aws secretsmanager delete-secret \
  --secret-id "my-secret" \
  --force-delete-without-recovery
```

## Handling Stuck Resources

### Stuck Elastic Network Interfaces (ENIs)

ENIs created by RDS or EKS may linger after a destroy, blocking subnet deletion. To find and remove them:

```bash
# List ENIs in the VPC
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=vpc-xxxxxxxxx" \
  --query "NetworkInterfaces[].{ID:NetworkInterfaceId,Status:Status,Description:Description}"

# Detach if still attached
aws ec2 detach-network-interface --attachment-id eni-attach-xxxxxxxxx --force

# Delete the ENI
aws ec2 delete-network-interface --network-interface-id eni-xxxxxxxxx
```

### Stuck Security Groups

Security groups with cross-references can block deletion. Remove the ingress/egress rules first, then delete:

```bash
# Revoke all ingress rules
aws ec2 revoke-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --security-group-rule-ids sgr-xxxxxxxxx

# Delete the security group
aws ec2 delete-security-group --group-id sg-xxxxxxxxx
```

After manually clearing stuck resources, re-run `terraform destroy` for the affected layer or use `terraform state rm` to remove the resource from state if it has already been deleted manually.
