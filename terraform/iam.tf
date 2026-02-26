###############################################################################
# IAM Roles and Policies for ECS Fargate Migration
###############################################################################

###############################################################################
# ECS Execution Role
# Used by ECS to pull images from ECR and write logs to CloudWatch
###############################################################################

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ecs_execution_role_policy" {
  name = "ecs_execution_role_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # CloudWatch Logs permissions (Requirement 6.5)
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ],
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
      # ECR authentication (Requirement 6.3)
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      # ECR image pull permissions (Requirement 6.4)
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
      },
      # SSM and KMS for Kaggle credentials
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "kms:Decrypt"
        ],
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kaggle/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_role_policy.arn
}

###############################################################################
# ECS Task Role
# Used by containers running in ECS tasks to access AWS services
###############################################################################

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_s3_policy" {
  name = "ecs_task_s3_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # S3 permissions for data processing (Requirements 6.1, 6.2)
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject" # Added for cleanup operations (Requirement 6.2)
        ],
        Resource = [
          aws_s3_bucket.spark_results.arn,
          "${aws_s3_bucket.spark_results.arn}/*"
        ]
      },
      # KMS permissions for S3 encryption (Requirement 7.2)
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ],
        Resource = local.kms_key_arn
      },
      # SSM and KMS for Kaggle credentials
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "kms:Decrypt"
        ],
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kaggle/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_s3_policy.arn
}

###############################################################################
# Step Functions Role
# Used by Step Functions to orchestrate ECS tasks
###############################################################################

resource "aws_iam_role" "sfn_role" {
  name = "emr-pipeline-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "states.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "sfn_events_policy" {
  name = "emr-pipeline-sfn-events-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "events:PutRule",
          "events:PutTargets",
          "events:DescribeRule",
          "events:DeleteRule",
          "events:RemoveTargets"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sfn_attach_events_policy" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = aws_iam_policy.sfn_events_policy.arn
}

resource "aws_iam_policy" "sfn_policy" {
  name = "emr-pipeline-sfn-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ECS task execution permissions (Requirement 6.6)
      {
        Effect = "Allow",
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:StopTask"
        ],
        Resource = [
          aws_ecs_task_definition.prep_task.arn,
          aws_ecs_task_definition.bronze_to_silver.arn,
          aws_ecs_task_definition.silver_to_gold.arn,
          aws_ecs_cluster.main.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "ecs:RunTask",
          "ecs:DescribeClusters"
        ],
        Resource = "*"
      },
      # IAM PassRole for ECS roles (Requirement 6.7)
      {
        Effect = "Allow",
        Action = ["iam:PassRole"],
        Resource = [
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ],
        Condition = {
          StringLikeIfExists = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sfn_attach" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = aws_iam_policy.sfn_policy.arn
}
