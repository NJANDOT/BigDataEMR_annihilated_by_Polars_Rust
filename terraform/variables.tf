variable "aws_region" {
  type        = string
  default     = "eu-west-3"
  description = "AWS region"
}

variable "s3_bucket_name" {
  type        = string
  description = "S3 bucket name for Spark results"
  default     = "sparkresultsjjjmain"
}

variable "project_name" {
  type        = string
  description = "Project name used for resource naming"
  default     = "emr-project"
}

variable "ecr_repository_name" {
  type        = string
  description = "ECR repository name for Docker images"
  default     = "emr_fine"
}

variable "ecr_image_tag" {
  type        = string
  description = "Docker image tag to use"
  default     = "latest15"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
  default     = ["eu-west-3a"]
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
  default     = ["10.0.0.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets"
  default     = ["10.0.1.0/24"]
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name"
  default     = "emr-prep-cluster"
}

variable "ecs_task_cpu" {
  type        = string
  description = "CPU units for ECS task (1 vCPU = 1024)"
  default     = "16384"
}

variable "ecs_task_memory" {
  type        = string
  description = "Memory for ECS task in MB"
  default     = "122880"
}

variable "ecs_ephemeral_storage_gb" {
  type        = number
  description = "Ephemeral storage for ECS task in GB"
  default     = 200
}

variable "cloudwatch_log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days"
  default     = 14
}

variable "kms_deletion_window_days" {
  type        = number
  description = "KMS key deletion window in days"
  default     = 7
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  default     = "dev"
}

variable "kms_key_id" {
  type        = string
  description = "Existing KMS key ID to import (optional). If not provided, a new key will be created."
  default     = null
}

# ECS Task Resource Variables for Fargate Migration

variable "kaggle_task_cpu" {
  type        = string
  description = "CPU units for Kaggle downloader task (1 vCPU = 1024)"
  default     = "2048"
}

variable "kaggle_task_memory" {
  type        = string
  description = "Memory for Kaggle downloader task in MB"
  default     = "4096"
}

variable "bronze_silver_task_cpu" {
  type        = string
  description = "CPU units for Bronze-to-Silver task (1 vCPU = 1024)"
  default     = "4096"
}

variable "bronze_silver_task_memory" {
  type        = string
  description = "Memory for Bronze-to-Silver task in MB"
  default     = "16384"
}

variable "bronze_silver_ephemeral_storage_gb" {
  type        = number
  description = "Ephemeral storage for Bronze-to-Silver task in GB"
  default     = 100
}

variable "silver_gold_task_cpu" {
  type        = string
  description = "CPU units for Silver-to-Gold task (1 vCPU = 1024)"
  default     = "8192"
}

variable "silver_gold_task_memory" {
  type        = string
  description = "Memory for Silver-to-Gold task in MB"
  default     = "32768"
}

variable "silver_gold_ephemeral_storage_gb" {
  type        = number
  description = "Ephemeral storage for Silver-to-Gold task in GB"
  default     = 200
}
