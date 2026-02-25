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

variable "emr_release_label" {
  type        = string
  description = "EMR release version"
  default     = "emr-7.1.0"
}

variable "emr_max_cpu" {
  type        = string
  description = "Maximum CPU for EMR Serverless"
  default     = "96 vCPU"
}

variable "emr_max_memory" {
  type        = string
  description = "Maximum memory for EMR Serverless"
  default     = "384 GB"
}

variable "emr_max_disk" {
  type        = string
  description = "Maximum disk for EMR Serverless"
  default     = "2000 GB"
}

variable "s3_scripts_prefix" {
  type        = string
  description = "S3 prefix for scripts"
  default     = "src"
}

variable "s3_logs_prefix" {
  type        = string
  description = "S3 prefix for logs"
  default     = "logs"
}

variable "spark_executor_cores" {
  type        = string
  description = "Spark executor cores"
  default     = "4"
}

variable "spark_executor_memory" {
  type        = string
  description = "Spark executor memory"
  default     = "24g"
}

variable "spark_executor_memory_overhead" {
  type        = string
  description = "Spark executor memory overhead"
  default     = "6g"
}

variable "spark_driver_memory" {
  type        = string
  description = "Spark driver memory"
  default     = "4g"
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
