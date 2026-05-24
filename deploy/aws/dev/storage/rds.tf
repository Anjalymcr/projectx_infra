# 1. Look up the Network Foundation from Layer 1
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["${var.environment}-vpc"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "tag:kubernetes.io/role/internal-elb"
    values = ["1"]
  }
}

# 2. Database Subnet Group (Isolation)
resource "aws_db_subnet_group" "db_storage" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = data.aws_subnets.private.ids
  tags       = local.common_tags
}

# 3. Security Group (The "Firewall")
resource "aws_security_group" "rds_sg" {
  name        = "${var.environment}-rds-security-group"
  description = "Access to RDS from the VPC"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# 4. The RDS Instance (Modern & Secure)
resource "aws_db_instance" "projectx_db" {
  identifier           = "${var.environment}-projectx-db"
  allocated_storage    = 20
  storage_type         = "gp3" # Faster and cheaper than gp2
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"

  db_name              = "projectx_metrics"
  username             = "admin"

  # We use the password from Secrets Manager (Step 2 below)
  password             = aws_secretsmanager_secret_version.db_password_val.secret_string

  db_subnet_group_name   = aws_db_subnet_group.db_storage.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot  = true
  deletion_protection  = false # Set to true for Prod!

  tags = local.common_tags
}
