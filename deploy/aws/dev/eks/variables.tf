variable "region" { type = string }
variable "environment" { type = string }
variable "project" { type = string }
variable "owner" { type = string }
variable "cost_center" { type = string }
variable "my_ip_cidr" {
    description = "My public IP address with /32 mask"
    type        = string
}