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
  timestamp            = timestamp()
  timestamp_no_hyphens = replace("${local.timestamp}", "-", "")
  timestamp_no_spaces  = replace("${local.timestamp_no_hyphens}", " ", "")
  timestamp_no_t       = replace("${local.timestamp_no_spaces}", "T", "")
  timestamp_no_z       = replace("${local.timestamp_no_t}", "Z", "")
  timestamp_no_colons  = replace("${local.timestamp_no_z}", ":", "")
  timestamp_sanitized  = local.timestamp_no_colons
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}


###############################################################################
# 0. utilisation S3                                                           #
###############################################################################

resource "aws_s3_bucket" "spark_results" {
  bucket = var.s3_bucket_name

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

  egress {
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
      route_table_ids = concat(module.vpc_main.private_route_table_ids, module.vpc_main.public_route_table_ids) # Ajoute public comme dans ta manuelle, connard
      tags            = { Name = "s3-vpc-endpoint" }
      policy = jsonencode({ # Colle ta policy de merde ici pour restreindre
        Version = "2012-10-17",
        Statement = [
          {
            Effect    = "Allow",
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
      security_group_ids  = [aws_security_group.allow_access.id] # Ajoute ton SG comme dans la manuelle, bordel
      tags                = { Name = "ecr-api-vpc-endpoint" }
      policy = jsonencode({ # Colle la policy de ta manuelle
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
      security_group_ids  = [aws_security_group.allow_access.id] # Pareil ici, fils de pute
      tags                = { Name = "ecr-dkr-vpc-endpoint" }
      policy = jsonencode({ # Même policy
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
      security_group_ids  = [aws_security_group.allow_access.id] # Ajoute le SG pour STS aussi, pour être cohérent
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

# IAM roles moved to iam.tf


##########
#
#########

resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name
}

resource "aws_cloudwatch_log_group" "ecs_prep" {
  name              = "/ecs/${var.ecs_cluster_name}"
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






# Step Functions IAM role moved to iam.tf

resource "aws_sfn_state_machine" "emr_pipeline" {
  name     = "${var.project_name}-pipeline-fargate-data-processing"
  role_arn = aws_iam_role.sfn_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.sfn_attach,
    aws_ecs_task_definition.prep_task,
    aws_ecs_task_definition.bronze_to_silver,
    aws_ecs_task_definition.silver_to_gold
  ]

  definition = jsonencode({
    Comment = "Fargate-based data pipeline: Kaggle → Bronze → Silver → Gold"
    StartAt = "KaggleDownloader"
    States = {
      KaggleDownloader = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          Cluster        = aws_ecs_cluster.main.arn
          TaskDefinition = aws_ecs_task_definition.prep_task.arn
          LaunchType     = "FARGATE"
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = [module.vpc_main.private_subnets[0]]
              SecurityGroups = [aws_security_group.allow_access.id]
              AssignPublicIp = "DISABLED"
            }
          }
        }
        Retry = [
          {
            ErrorEquals     = ["States.TaskFailed"]
            IntervalSeconds = 30
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "FailureState"
          }
        ]
        Next = "BronzeToSilver"
      }

      BronzeToSilver = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          Cluster        = aws_ecs_cluster.main.arn
          TaskDefinition = aws_ecs_task_definition.bronze_to_silver.arn
          LaunchType     = "FARGATE"
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = [module.vpc_main.private_subnets[0]]
              SecurityGroups = [aws_security_group.allow_access.id]
              AssignPublicIp = "DISABLED"
            }
          }
        }
        Retry = [
          {
            ErrorEquals     = ["States.TaskFailed"]
            IntervalSeconds = 30
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "FailureState"
          }
        ]
        Next = "SilverToGold"
      }

      SilverToGold = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          Cluster        = aws_ecs_cluster.main.arn
          TaskDefinition = aws_ecs_task_definition.silver_to_gold.arn
          LaunchType     = "FARGATE"
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = [module.vpc_main.private_subnets[0]]
              SecurityGroups = [aws_security_group.allow_access.id]
              AssignPublicIp = "DISABLED"
            }
          }
        }
        Retry = [
          {
            ErrorEquals     = ["States.TaskFailed"]
            IntervalSeconds = 30
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "FailureState"
          }
        ]
        Next = "Success"
      }

      Success = {
        Type = "Succeed"
      }

      FailureState = {
        Type  = "Fail"
        Error = "PipelineExecutionFailed"
        Cause = "One or more tasks in the pipeline failed after retries"
      }
    }
  })
}