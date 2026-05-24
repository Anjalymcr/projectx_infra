module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "1.3.0"

  name           = "${var.environment}-jenkins-efs"
  creation_token = "${var.environment}-jenkins"
  encrypted      = true

  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy = {
    transition_to_ia = "AFTER_30_DAYS"
  }

  # File system policy
  attach_policy                      = false
  bypass_policy_lockout_safety_check = false

  # Attach to our private subnets from Layer 1
  # We use the search results from rds.tf
  mount_targets = {
    for k, v in data.aws_subnets.private.ids : "az-${k}" => { subnet_id = v }
  }

  security_group_description = "NFS access for Jenkins"
  security_group_vpc_id      = data.aws_vpc.selected.id
  security_group_rules = {
    vpc = {
      description = "NFS ingress from VPC"
      cidr_blocks = [data.aws_vpc.selected.cidr_block]
    }
  }

  # Access Point for Jenkins (Matches original repo logic)
  access_points = {
    jenkins = {
      root_directory = {
        path = "/var/jenkins_home"
        creation_info = {
          owner_gid   = 1000
          owner_uid   = 1000
          permissions = "755"
        }
      }
    }
  }

  tags = local.common_tags
}
