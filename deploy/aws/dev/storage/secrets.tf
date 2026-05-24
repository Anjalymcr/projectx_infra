# 1. Generate a random strong password
resource "random_password" "db_master_pass" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 2. Create the "Vault" in AWS
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.environment}/rds/master-password"
  description             = "ProjectX RDS Master Password"
  recovery_window_in_days = 0
  tags                    = local.common_tags
}

# 3. Store the random password inside the vault
resource "aws_secretsmanager_secret_version" "db_password_val" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_master_pass.result
}
