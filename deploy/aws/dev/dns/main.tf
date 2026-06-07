data "aws_vpc" "network" {
  filter {
    name   = "tag:Name"
    values = ["${var.environment}-vpc"]
  }
}

resource "aws_route53_zone" "private" {
  name = "projectx.internal"

  vpc {
    vpc_id = data.aws_vpc.network.id
  }

  tags = local.common_tags
}

output "zone_id" {
  value = aws_route53_zone.private.zone_id
}

output "zone_name" {
  value = aws_route53_zone.private.name
}
