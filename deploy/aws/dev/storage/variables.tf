variable "region" {
  description = "The AWS region to deploy to"
  type        = string
}

variable "environment" {
  description = "The environment name (e.g. dev, prod)"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}

variable "owner" {
  description = "Team owning this infrastructure"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}
