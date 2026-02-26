# CloudWatch Log Groups for ECS Fargate Tasks

resource "aws_cloudwatch_log_group" "kaggle_downloader" {
  name              = "/ecs/kaggle-downloader"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name        = "${var.project_name}-kaggle-downloader"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "bronze_to_silver" {
  name              = "/ecs/bronze-to-silver"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name        = "${var.project_name}-bronze-to-silver"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "silver_to_gold" {
  name              = "/ecs/silver-to-gold"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name        = "${var.project_name}-silver-to-gold"
    Environment = var.environment
  }
}
