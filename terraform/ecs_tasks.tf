# ECS Task Definitions for Fargate Data Processing Pipeline

###############################################################################
# Bronze-to-Silver Processor Task Definition
###############################################################################

resource "aws_ecs_task_definition" "bronze_to_silver" {
  family                   = "${var.project_name}-bronze-to-silver"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.bronze_silver_task_cpu
  memory                   = var.bronze_silver_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  ephemeral_storage {
    size_in_gib = var.bronze_silver_ephemeral_storage_gb
  }

  container_definitions = jsonencode([
    {
      name      = "bronze-to-silver"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_name}:bronze-silver-latest"
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.bronze_to_silver.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-bronze-to-silver"
    Environment = var.environment
  }
}

###############################################################################
# Silver-to-Gold Processor Task Definition
###############################################################################

resource "aws_ecs_task_definition" "silver_to_gold" {
  family                   = "${var.project_name}-silver-to-gold"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.silver_gold_task_cpu
  memory                   = var.silver_gold_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  ephemeral_storage {
    size_in_gib = var.silver_gold_ephemeral_storage_gb
  }

  container_definitions = jsonencode([
    {
      name      = "silver-to-gold"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_name}:silver-gold-latest"
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.silver_to_gold.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-silver-to-gold"
    Environment = var.environment
  }
}
