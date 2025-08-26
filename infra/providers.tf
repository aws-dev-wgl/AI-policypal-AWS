provider "aws" {
  region = var.region
  default_tags { tags = { project = "policypal", env = var.env, owner = var.owner } }
}
