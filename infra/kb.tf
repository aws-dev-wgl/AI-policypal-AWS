# Role Bedrock uses to read S3 and manage its vector store
data "aws_iam_policy_document" "kb_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "kb" {
  name               = "${local.name_prefix}-kb-role"
  assume_role_policy = data.aws_iam_policy_document.kb_trust.json
}

data "aws_iam_policy_document" "kb_policy_doc" {
  statement {
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.docs.arn,
      "${aws_s3_bucket.docs.arn}/*"
    ]
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

  storage_configuration {
    type = "AMAZON_MANAGED"
  }
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
