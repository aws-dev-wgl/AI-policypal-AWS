# file: bedrock_kb.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    opensearch = {
      source  = "opensearch-project/opensearch"
      version = "~> 2.3"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.0.0"
    }
  }
}

# Provider for OpenSearch used by the submodule to create the vector index
# NOTE: url comes from the collection this module creates; healthcheck is disabled
# to avoid plan-time HEAD checks before the collection exists.
provider "opensearch" {
  url         = module.bedrock_kb.default_collection.collection_endpoint
  healthcheck = false
}

# file: bedrock_kb.tf

# Region is needed to build the Titan v2 model ARN
data "aws_region" "current" {}

module "bedrock_kb" {
  source  = "aws-ia/bedrock/aws"
  version = "~> 0.0.29"

  # Avoid creating an Agent unless you need it
  create_agent    = false

  # Create default OpenSearch Serverless Knowledge Base + index
  create_default_kb = true

  # Create an S3 data source and attach to the KB
  create_s3_data_source      = true
  s3_data_source_bucket_name = aws_s3_bucket.docs.bucket
  s3_inclusion_prefixes      = ["corpus/"]

  # Embedding model for vectorization (Titan v2)
  kb_embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"

  # Tags / naming context
  name_prefix = local.name_prefix
}

# Keep these outputs only in one place in your root module to avoid duplicates
output "kb_id" {
  value       = module.bedrock_kb.default_kb_identifier
  description = "Knowledge Base identifier"
}

output "kb_data_source_id" {
  value       = module.bedrock_kb.datasource_identifier
  description = "Knowledge Base data source identifier"
}

# Optional convenience outputs
output "kb_s3_data_source_arn" {
  value       = module.bedrock_kb.s3_data_source_arn
  description = "S3 data source ARN"
}

output "kb_s3_data_source_name" {
  value       = module.bedrock_kb.s3_data_source_name
  description = "S3 data source name"
}
