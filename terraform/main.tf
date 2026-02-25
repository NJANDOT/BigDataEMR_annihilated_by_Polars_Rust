terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.54.0"  
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
}

locals {
  timestamp = "${timestamp()}"
  timestamp_no_hyphens = "${replace("${local.timestamp}", "-", "")}"
  timestamp_no_spaces = "${replace("${local.timestamp_no_hyphens}", " ", "")}"
  timestamp_no_t = "${replace("${local.timestamp_no_spaces}", "T", "")}"
  timestamp_no_z = "${replace("${local.timestamp_no_t}", "Z", "")}"
  timestamp_no_colons = "${replace("${local.timestamp_no_z}", ":", "")}"
  timestamp_sanitized = "${local.timestamp_no_colons}"
}

variable "aws_region" {
  type        = string
  default     = "eu-west-3"
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}


###############################################################################
# 0. utilisation S3                                                           #
###############################################################################

resource "aws_s3_bucket" "spark_results" {
  bucket        = var.s3_bucket_name

  tags = {
    Name        = var.project_name
    Environment = var.environment
  }
}

import {
  to = aws_s3_bucket.spark_results
  id = var.s3_bucket_name
}


###############################################################################
# 1. VPC module 
###############################################################################



module "vpc_main" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.project_name
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_dns_support   = true
  enable_dns_hostnames = true

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    Name        = var.project_name
    Environment = var.environment
  }
}

# ✅ Security group requis par EMR Serverless & Step Functions (manquait)
resource "aws_security_group" "allow_access" {
  name        = "emr_sg"
  description = "Allow all traffic within VPC"
  vpc_id      = module.vpc_main.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc_main.vpc_cidr_block]
  }

  egress  {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


###############################################################################
#    Gateway VPC Endpoint pour S3                 
###############################################################################
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id = module.vpc_main.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = concat(module.vpc_main.private_route_table_ids, module.vpc_main.public_route_table_ids)  # Ajoute public comme dans ta manuelle, connard
      tags            = { Name = "s3-vpc-endpoint" }
      policy          = jsonencode({  # Colle ta policy de merde ici pour restreindre
        Version = "2012-10-17",
        Statement = [
          {
            Effect = "Allow",
            Principal = "*",
            Action = [
              "*"
            ],
            Resource = [
              "*"
            ]
          },

        ]
      })
    },
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc_main.private_subnets
      security_group_ids  = [aws_security_group.allow_access.id]  # Ajoute ton SG comme dans la manuelle, bordel
      tags                = { Name = "ecr-api-vpc-endpoint" }
      policy              = jsonencode({  # Colle la policy de ta manuelle
        Version = "2012-10-17",
        Statement = [
          {
            Effect    = "Allow",
            Principal = "*",
            Action    = "ecr:*",
            Resource  = "*"
          }
        ]
      })
    },
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc_main.private_subnets
      security_group_ids  = [aws_security_group.allow_access.id]  # Pareil ici, fils de pute
      tags                = { Name = "ecr-dkr-vpc-endpoint" }
      policy              = jsonencode({  # Même policy
        Version = "2012-10-17",
        Statement = [
          {
            Effect    = "Allow",
            Principal = "*",
            Action    = "ecr:*",
            Resource  = "*"
          }
        ]
      })
    },
    sts = {
      service             = "sts"
      private_dns_enabled = true
      subnet_ids          = module.vpc_main.private_subnets
      security_group_ids  = [aws_security_group.allow_access.id]  # Ajoute le SG pour STS aussi, pour être cohérent
      tags                = { Name = "sts-vpc-endpoint" }
      # Si t'as besoin d'une policy pour STS, ajoute-la ici, sinon laisse vide
    }
  }

  tags = {
    Environment = var.environment
  }
}

###############################################################################
# ECS Task IAM Roles                                                          #
###############################################################################

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ecs_execution_role_policy" {
  name = "ecs_execution_role_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ],
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
      },
      {
        Effect   = "Allow",
        Action   = [
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

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "ecs_task_policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:*"
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/*" 
      },
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "ecs_task_s3_policy" {
  name = "ecs_task_s3_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.spark_results.arn,
          "${aws_s3_bucket.spark_results.arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = [
          "ssm:GetParameter",
          "kms:Decrypt"
        ],
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kaggle/*"
        ]
      },
      {

          Effect= "Allow",
          Action= [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetAuthorizationToken"
          ],
          Resource= "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
        }

    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_s3_policy.arn
}


##########
#
#########

resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name
}

resource "aws_cloudwatch_log_group" "ecs_prep" {
  name = "/ecs/${var.ecs_cluster_name}"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_ecs_task_definition" "prep_task" {
  family                   = "${var.project_name}-prep-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  ephemeral_storage {
    size_in_gib = var.ecs_ephemeral_storage_gb
  }

  container_definitions = jsonencode([
    {
      name      = "pyproject"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_name}:${var.ecr_image_tag}"
      essential = true
      cpu       = tonumber(var.ecs_task_cpu)
      memory    = tonumber(var.ecs_task_memory)
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.ecs_cluster_name}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}




###############################################################################
# CUSTOM : putting certifs in S3 from local certs.zip file                    #
###############################################################################


data "archive_file" "certs_zip" {
  type        = "zip"
  source_dir  = "${path.module}/certs"          # ton dossier local contenant .pem
  output_path = "${path.module}/build/certs.zip"
}

resource "aws_s3_object" "certs_zip" {
  bucket = aws_s3_bucket.spark_results.id      # ton bucket
  key    = "certs.zip"                  # chemin dans le bucket
  source = data.archive_file.certs_zip.output_path
  etag   = data.archive_file.certs_zip.output_md5   # force la mise à jour si le zip change :contentReference[oaicite:5]{index=5}
}

###############################################################################
# 4. Security Configuration EMR                                                #
###############################################################################



resource "aws_emr_security_configuration" "sec_cfg" {
  name = "emr-secure"

  depends_on = [
    aws_s3_object.certs_zip
  ]


  configuration = <<EOF
{
  "EncryptionConfiguration": {
    "EnableAtRestEncryption": true,
    "AtRestEncryptionConfiguration": {
      "S3EncryptionConfiguration": {
          "EncryptionMode": "SSE-KMS",
          "AwsKmsKey": "${local.kms_key_arn}"
      },
      "LocalDiskEncryptionConfiguration": {
        "EnableEbsEncryption": true,
        "EncryptionKeyProviderType": "AwsKms",
        "AwsKmsKey": "${local.kms_key_arn}"
      }
    },
    "EnableInTransitEncryption": true,
    "InTransitEncryptionConfiguration": {
      "TLSCertificateConfiguration": {
        "CertificateProviderType": "PEM",
        "S3Object": "s3://${aws_s3_object.certs_zip.bucket}/${aws_s3_object.certs_zip.key}"
      }
    }
  }
}
EOF
}



###############################################################################
# 5. IAM Roles & Instance Profile EMR                                          #
###############################################################################

resource "aws_iam_role" "emr_serverless_job_role" {
  name = "emr_serverless_job_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "emr-serverless.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "emr_serverless_job_policy" {
  name   = "emr_serverless_job_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
        Resource = [
          aws_s3_bucket.spark_results.arn,
          "${aws_s3_bucket.spark_results.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"],
        Resource = local.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "emr_serverless_job_attach" {
  role       = aws_iam_role.emr_serverless_job_role.name
  policy_arn = aws_iam_policy.emr_serverless_job_policy.arn
}

# 6. Application EMR Serverless
resource "aws_emrserverless_application" "spark_app" {
  name          = "${var.project_name}-spark-serverless"
  release_label = var.emr_release_label
  type          = "SPARK"

  network_configuration {
    subnet_ids         = module.vpc_main.private_subnets
    security_group_ids = [aws_security_group.allow_access.id]
  }

  maximum_capacity {
    cpu    = var.emr_max_cpu
    memory = var.emr_max_memory
    disk   = var.emr_max_disk
  }
}

# 7. Step Functions orchestration
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
        Effect   = "Allow",
        Action   = [
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
      {
        Effect = "Allow",
        Action = ["ecs:RunTask", "ecs:DescribeTasks", "ecs:StopTask"],
        Resource = [
          aws_ecs_task_definition.prep_task.arn,
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
      },
      {
        Effect = "Allow",
        Action = ["emr-serverless:StartJobRun", "emr-serverless:GetJobRun", "emr-serverless:CancelJobRun", "emr-serverless:ListApplications"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["iam:PassRole"],
        Resource = [ aws_iam_role.emr_serverless_job_role.arn ],
        Condition = {
          StringLikeIfExists = {
            "iam:PassedToService" = "emr-serverless.amazonaws.com"
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

resource "aws_sfn_state_machine" "emr_pipeline" {
  name     = "${var.project_name}-pipeline-ecs-to-emrserverless-to-gold"
  role_arn = aws_iam_role.sfn_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.sfn_attach,
    aws_iam_role_policy_attachment.emr_serverless_job_attach,
    aws_emrserverless_application.spark_app
  ]

  definition = jsonencode({
    Comment = "Run ECS prep task then EMR Serverless Spark job"
    StartAt = "RunECSPrep"
    States = {
      RunECSPrep = {
        Type = "Task",
        Resource = "arn:aws:states:::ecs:runTask.sync",
        Parameters = {
          Cluster        = aws_ecs_cluster.main.arn
          TaskDefinition = aws_ecs_task_definition.prep_task.arn
          LaunchType     = "FARGATE"
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = [ module.vpc_main.private_subnets[0] ]
              SecurityGroups = [ aws_security_group.allow_access.id ]
              AssignPublicIp = "DISABLED"
            }
          }
        },
        Next = "StartEmrBronzeToSilver"
      },

      StartEmrBronzeToSilver = {
        Type = "Task"
        Resource = "arn:aws:states:::emr-serverless:startJobRun.sync"
        Parameters = {
          ApplicationId    = aws_emrserverless_application.spark_app.id
          ExecutionRoleArn = aws_iam_role.emr_serverless_job_role.arn
          Name             = "bronze-to-silver-job"
          JobDriver = {
            SparkSubmit = {
              EntryPoint = "s3://${var.s3_bucket_name}/${var.s3_scripts_prefix}/bronze_to_silver.py"
              SparkSubmitParameters = "--conf spark.executor.cores=${var.spark_executor_cores} --conf spark.dynamicAllocation.enabled=false --conf spark.executor.memory=${var.spark_executor_memory} --conf spark.executor.memoryOverhead=${var.spark_executor_memory_overhead} --conf spark.driver.memory=${var.spark_driver_memory} --conf spark.local.dir=/mnt"
            }
          }
          ConfigurationOverrides = {
            MonitoringConfiguration = {
              S3MonitoringConfiguration = {
                LogUri = "s3://${var.s3_bucket_name}/${var.s3_logs_prefix}/"
              }
            }
          }
        }
        ResultPath = "$.EmrBronzeResult" 
        Next = "StartEmrSilverToGold"
      }

      StartEmrSilverToGold = {
        Type = "Task"
        Resource = "arn:aws:states:::emr-serverless:startJobRun.sync"
        Parameters = {
          ApplicationId    = aws_emrserverless_application.spark_app.id
          ExecutionRoleArn = aws_iam_role.emr_serverless_job_role.arn
          Name             = "silver-to-gold-analysis"
          JobDriver = {
            SparkSubmit = {
              EntryPoint = "s3://${var.s3_bucket_name}/${var.s3_scripts_prefix}/silver_to_gold.py"
              SparkSubmitParameters = "--conf spark.executor.cores=${var.spark_executor_cores} --conf spark.dynamicAllocation.enabled=false --conf spark.executor.memory=${var.spark_executor_memory} --conf spark.executor.memoryOverhead=${var.spark_executor_memory_overhead} --conf spark.driver.memory=${var.spark_driver_memory} --conf spark.local.dir=/mnt"
            }
          }
          ConfigurationOverrides = {
            MonitoringConfiguration = {
              S3MonitoringConfiguration = {
                LogUri = "s3://${var.s3_bucket_name}/${var.s3_logs_prefix}/"
              }
            }
          }
        }
        ResultPath = "$.EmrGoldResult"
        Next = "Success"
      }

      Success = {
        Type = "Succeed"
      }
  }})
}