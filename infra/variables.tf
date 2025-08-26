variable "region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "owner" {
  type    = string
  default = "aws-dev-wgl"
}

variable "suffix" {
  type    = string
  default = "wgl"
}

locals {
  name_prefix      = "policypal-${var.env}"
  docs_bucket_name = "policypal-docs-${var.env}-${var.suffix}"
}
