terraform {
  backend "s3" {
    bucket  = "my-terraform-state-aws-ai-dev-wgl"
    key     = "policypal/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
