#!/bin/bash
set -e


# minimal lambda placeholders
cat > app/lambda/query/handler.py <<'PY'
def handler(event, context):
    return {"statusCode":200,"headers":{"content-type":"application/json"},"body":"{}"}
PY
cp app/lambda/query/handler.py app/lambda/upload/handler.py
cp app/lambda/query/handler.py app/lambda/sync/handler.py

# Terraform: Phase 1 (S3 docs + Bedrock KB)
cat > infra/versions.tf <<'TF'
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.65"
    }
  }
}
TF

cat > infra/backend.tf <<'TF'
terraform {
  backend "s3" {
    bucket = "my-terraform-state-aws-ai-dev-wgl"
    key    = "policypal/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}
TF

cat > infra/providers.tf <<'TF'
provider "aws" {
  region = var.region
  default_tags { tags = { project = "policypal", env = var.env, owner = var.owner } }
}
TF

cat > infra/variables.tf <<'TF'
variable "region" { type = string  default = "us-east-1" }
variable "env"    { type = string  default = "dev" }
variable "owner"  { type = string  default = "aws-dev-wgl" }
variable "suffix" { type = string  default = "wgl" }

locals {
  name_prefix      = "policypal-${var.env}"
  docs_bucket_name = "policypal-docs-${var.env}-${var.suffix}"
}
TF

cat > infra/s3.tf <<'TF'
resource "aws_s3_bucket" "docs" { bucket = local.docs_bucket_name }

resource "aws_s3_bucket_public_access_block" "docs" {
  bucket                  = aws_s3_bucket.docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id
  versioning_configuration { status = "Enabled" }
}
TF

cat > infra/kb.tf <<'TF'
# Role Bedrock uses to read S3 and manage its vector store
data "aws_iam_policy_document" "kb_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["bedrock.amazonaws.com"] }
  }
}

resource "aws_iam_role" "kb" {
  name               = "${local.name_prefix}-kb-role"
  assume_role_policy = data.aws_iam_policy_document.kb_trust.json
}

data "aws_iam_policy_document" "kb_policy_doc" {
  statement {
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.docs.arn, "${aws_s3_bucket.docs.arn}/*"]
  }
}

resource "aws_iam_policy" "kb_policy" {
  name   = "${local.name_prefix}-kb-policy"
  policy = data.aws_iam_policy_document.kb_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "kb_attach" {
  role       = aws_iam_role.kb.name
  policy_arn = aws_iam_policy.kb_policy.arn
}

resource "aws_bedrockagent_knowledge_base" "kb" {
  name        = "${local.name_prefix}-kb"
  description = "PolicyPal Knowledge Base"
  role_arn    = aws_iam_role.kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2"
    }
  }

  storage_configuration { type = "AMAZON_MANAGED" }
}

resource "aws_bedrockagent_data_source" "s3src" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.kb.id
  name              = "${local.name_prefix}-s3src"
  description       = "Docs bucket data source"
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = aws_s3_bucket.docs.arn
      inclusion_prefixes = ["corpus/"]
    }
  }
}
TF

cat > infra/outputs.tf <<'TF'
output "docs_bucket"       { value = aws_s3_bucket.docs.bucket }
output "kb_id"             { value = aws_bedrockagent_knowledge_base.kb.id }
output "kb_data_source_id" { value = aws_bedrockagent_data_source.s3src.data_source_id }
TF

echo "Scaffold complete."
