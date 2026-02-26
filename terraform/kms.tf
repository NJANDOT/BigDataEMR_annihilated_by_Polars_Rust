###############################################################################
# KMS Key Management                                                          #
###############################################################################

# Data source pour récupérer une clé KMS existante (si kms_key_id est fourni)
data "aws_kms_key" "existing" {
  count  = var.kms_key_id != null ? 1 : 0
  key_id = var.kms_key_id
}

# Créer une nouvelle clé KMS seulement si kms_key_id n'est pas fourni
resource "aws_kms_key" "emrb" {
  count                   = var.kms_key_id == null ? 1 : 0
  description             = "EMR CMK for S3 and EBS encryption"
  deletion_window_in_days = var.kms_deletion_window_days

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowKeyAdmins",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "AllowEcsTaskRoleToUseKey",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_role.ecs_task_role.arn}"
      },
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowSSMParameterStore",
      "Effect": "Allow",
      "Principal": {
        "Service": "ssm.amazonaws.com"
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*"
      ],
      "Resource": "*"
    }
  ]
}
POLICY

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-kms-key"
    Environment = var.environment
  }
}

# Alias pour la clé KMS (facilite l'identification)
resource "aws_kms_alias" "emrb" {
  name          = "alias/${var.project_name}-emr-key"
  target_key_id = local.kms_key_id
}

# Local pour référencer la clé KMS (existante ou nouvelle)
locals {
  kms_key_id  = var.kms_key_id != null ? data.aws_kms_key.existing[0].id : aws_kms_key.emrb[0].id
  kms_key_arn = var.kms_key_id != null ? data.aws_kms_key.existing[0].arn : aws_kms_key.emrb[0].arn
}

# Output pour faciliter la référence
output "kms_key_id" {
  description = "ID of the KMS key used for encryption"
  value       = local.kms_key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = local.kms_key_arn
}
