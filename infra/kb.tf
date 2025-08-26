module "bedrock_kb" {
  source  = "aws-ia/bedrock/aws"
  version = "~> 1.8" # or latest shown on the registry

  # Create default OpenSearch Serverless KB + index
  create_default_kb = true

  # S3 data source
  create_s3_data_source = true
  s3_data_source = {
    bucket_name        = aws_s3_bucket.docs.bucket
    inclusion_prefixes = ["corpus/"]
  }

  # Embedding model for vectorization
  embedding_model_id = "amazon.titan-embed-text-v2"

  # Tags / naming context
  name_prefix = local.name_prefix
}

# expose outputs similar to what you had before
output "kb_id" {
  value = module.bedrock_kb.knowledge_base_id
}
output "kb_data_source_id" {
  value = module.bedrock_kb.data_source_id
}
