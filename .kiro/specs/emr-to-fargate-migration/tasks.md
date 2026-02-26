# Implementation Plan: EMR to Fargate Migration

## Overview

This plan implements the migration from EMR Serverless (Spark) to ECS Fargate (Polars) for a data processing pipeline handling ~50GB of data. The implementation follows a phased approach: create Dockerfiles and property tests, update CI/CD pipeline, update Terraform configuration to add Fargate resources, remove EMR resources, and validate the complete pipeline.

## Tasks

- [x] 1. Create Dockerfiles for Python processing containers
  - [x] 1.1 Create Dockerfile for Bronze-to-Silver processor
    - Create `code/Dockerfile.bronze-silver` with Python 3.11-slim base image
    - Install polars, s3fs, and pyarrow packages
    - Copy bronze_to_silver.py and consts_proj.py into /app directory
    - Set CMD to execute bronze_to_silver.py
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  
  - [x] 1.2 Create Dockerfile for Silver-to-Gold processor
    - Create `code/Dockerfile.silver-gold` with Python 3.11-slim base image
    - Install polars, s3fs, pyarrow, and numpy packages
    - Copy silver_to_gold.py and consts_proj.py into /app directory
    - Set CMD to execute silver_to_gold.py
    - _Requirements: 4.5, 4.6, 4.7, 4.8_

- [-] 2. Write property-based tests for data processing correctness
  - [x] 2.1 Create property test file structure
    - Create `code/test_properties.py` with pytest and Hypothesis imports
    - Configure Hypothesis to run minimum 100 iterations per test
    - Add test tagging comments referencing design document properties
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 11.8, 11.9, 11.10_
  
  - [ ]* 2.2 Write property test for text length filter
    - **Property 1: Text Length Filter Correctness**
    - **Validates: Requirements 11.5**
    - Generate random text strings of varying lengths (0-500 chars)
    - Apply filter: text.len_chars() > 100
    - Assert all output rows have text length > 100
  
  - [ ]* 2.3 Write property test for copyright filter
    - **Property 2: Copyright Filter Correctness**
    - **Validates: Requirements 11.6**
    - Generate text strings with and without "copyright" keyword
    - Apply filter: !text.contains('copyright')
    - Assert no output rows contain "copyright"
  
  - [ ]* 2.4 Write property test for metadata extraction
    - **Property 3: Metadata Extraction Preservation**
    - **Validates: Requirements 11.7**
    - Generate dataframes with meta.pile_set_name values
    - Apply transformation: extract pile_set_name to set_name column
    - Assert set_name equals original pile_set_name for all rows
  
  - [ ]* 2.5 Write property test for partition index calculation
    - **Property 4: Partition Index Calculation**
    - **Validates: Requirements 11.8**
    - Generate dataframes with varying row counts and partition counts
    - Apply partition calculation: row_number % partition_count
    - Assert _partition_idx equals expected value for each row

- [x] 3. Update GitHub Actions workflow for container builds
  - [x] 3.1 Add test job with property-based tests
    - Update `.github/workflows/main.yaml` to add test job
    - Install Python 3.11, polars, s3fs, pyarrow, numpy, pytest, hypothesis
    - Run unit tests: pytest code/test_*.py -v
    - Run property tests: pytest code/test_properties.py -v --hypothesis-show-statistics
    - _Requirements: 5.1, 5.2, 5.3_
  
  - [x] 3.2 Add build-and-push-bronze-silver job
    - Create job that depends on test job passing
    - Configure AWS credentials and ECR authentication
    - Build Docker image from code/Dockerfile.bronze-silver
    - Tag image with bronze-silver-${{ github.sha }}
    - Push image to ECR repository
    - Tag and push bronze-silver-latest
    - _Requirements: 5.2, 5.4, 5.5, 5.6_
  
  - [x] 3.3 Add build-and-push-silver-gold job
    - Create job that depends on test job passing
    - Configure AWS credentials and ECR authentication
    - Build Docker image from code/Dockerfile.silver-gold
    - Tag image with silver-gold-${{ github.sha }}
    - Push image to ECR repository
    - Tag and push silver-gold-latest
    - _Requirements: 5.3, 5.4, 5.5, 5.6_
  
  - [x] 3.4 Remove upload-script job
    - Remove the upload-script job from workflow
    - Remove S3 script upload steps (no longer needed with containers)
    - _Requirements: 5.7_

- [x] 4. Checkpoint - Verify containers build and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Create ECS task definitions in Terraform
  - [x] 5.1 Add CloudWatch log groups
    - Create `terraform/ecs_logs.tf` file
    - Add aws_cloudwatch_log_group for kaggle-downloader
    - Add aws_cloudwatch_log_group for bronze-to-silver
    - Add aws_cloudwatch_log_group for silver-to-gold
    - Use var.cloudwatch_log_retention_days for retention
    - _Requirements: 9.1, 9.2_
  
  - [x] 5.2 Add Terraform variables for task resources
    - Update `terraform/variables.tf` to add ECS task variables
    - Add kaggle_task_cpu (default: "2048")
    - Add kaggle_task_memory (default: "4096")
    - Add bronze_silver_task_cpu (default: "4096")
    - Add bronze_silver_task_memory (default: "16384")
    - Add bronze_silver_ephemeral_storage_gb (default: 100)
    - Add silver_gold_task_cpu (default: "8192")
    - Add silver_gold_task_memory (default: "32768")
    - Add silver_gold_ephemeral_storage_gb (default: 200)
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_
  
  - [x] 5.3 Create ECS task definition for Bronze-to-Silver
    - Create `terraform/ecs_tasks.tf` file
    - Add aws_ecs_task_definition.bronze_to_silver resource
    - Configure 4 vCPU (4096) and 16GB memory (16384)
    - Configure 100GB ephemeral storage
    - Reference existing ecs_execution_role and ecs_task_role
    - Configure awslogs driver with /ecs/bronze-to-silver log group
    - Reference ECR image URI: account_id.dkr.ecr.region.amazonaws.com/emr_fine:bronze-silver-latest
    - _Requirements: 2.1, 2.3, 2.5, 2.6, 2.7_
  
  - [x] 5.4 Create ECS task definition for Silver-to-Gold
    - Add aws_ecs_task_definition.silver_to_gold resource to ecs_tasks.tf
    - Configure 8 vCPU (8192) and 32GB memory (32768)
    - Configure 200GB ephemeral storage
    - Reference existing ecs_execution_role and ecs_task_role
    - Configure awslogs driver with /ecs/silver-to-gold log group
    - Reference ECR image URI: account_id.dkr.ecr.region.amazonaws.com/emr_fine:silver-gold-latest
    - _Requirements: 2.2, 2.4, 2.5, 2.6, 2.7_

- [x] 6. Update IAM permissions for ECS tasks
  - [x] 6.1 Update ECS task role with S3 permissions
    - Update `terraform/iam.tf` to modify ecs_task_role policy
    - Add s3:DeleteObject permission to existing S3 permissions
    - Ensure s3:GetObject, s3:PutObject, s3:ListBucket are present
    - Scope permissions to data bucket ARN
    - _Requirements: 6.1, 6.2_
  
  - [x] 6.2 Update ECS task role with KMS permissions
    - Add KMS permissions to ecs_task_role policy
    - Add kms:Decrypt, kms:GenerateDataKey, kms:DescribeKey actions
    - Scope permissions to KMS key ARN
    - _Requirements: 7.2_
  
  - [x] 6.3 Update ECS execution role permissions
    - Verify ecs_execution_role has ecr:GetAuthorizationToken
    - Verify ecr:BatchCheckLayerAvailability, ecr:GetDownloadUrlForLayer, ecr:BatchGetImage
    - Verify logs:CreateLogStream, logs:PutLogEvents, logs:CreateLogGroup
    - _Requirements: 6.3, 6.4, 6.5_
  
  - [x] 6.4 Update Step Functions role for ECS task execution
    - Update Step Functions role policy in iam.tf
    - Add ecs:RunTask, ecs:DescribeTasks, ecs:StopTask permissions
    - Add iam:PassRole for ecs_execution_role and ecs_task_role
    - Add condition: StringLikeIfExists iam:PassedToService = ecs-tasks.amazonaws.com
    - _Requirements: 6.6, 6.7_

- [x] 7. Update Step Functions state machine for Fargate tasks
  - [x] 7.1 Update state machine definition
    - Update `terraform/step_functions.tf` state machine definition
    - Replace EMR StartJobRun states with ECS RunTask states
    - Add KaggleDownloader state using ecs:runTask.sync
    - Add BronzeToSilver state using ecs:runTask.sync
    - Add SilverToGold state using ecs:runTask.sync
    - _Requirements: 3.1, 3.2, 3.3, 3.4_
  
  - [x] 7.2 Configure ECS task network settings
    - Configure each ECS task with VPC private subnet reference
    - Configure each ECS task with security group reference
    - Set AssignPublicIp to DISABLED for all tasks
    - Reference correct ECS task definition ARN for each stage
    - _Requirements: 3.5, 3.6, 3.7_
  
  - [x] 7.3 Add retry and error handling configuration
    - Add Retry block with exponential backoff (30s, 60s, 120s)
    - Set MaxAttempts to 3 for each task
    - Set BackoffRate to 2.0
    - Add Catch block to capture errors in $.error path
    - Add FailureState for terminal failures
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

- [x] 8. Checkpoint - Verify Terraform plan for new resources
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Remove EMR Serverless resources from Terraform
  - [x] 9.1 Remove EMR Serverless application resource
    - Remove aws_emrserverless_application.spark_app from Terraform
    - Remove aws_emr_security_configuration.sec_cfg resource
    - _Requirements: 1.1, 1.3_
  
  - [x] 9.2 Remove EMR IAM roles and policies
    - Remove emr_serverless_job_role IAM role
    - Remove emr_serverless_job_policy IAM policy
    - Remove associated IAM role policy attachments
    - _Requirements: 1.2_
  
  - [x] 9.3 Remove EMR-related S3 objects
    - Remove aws_s3_object.certs_zip resource
    - Remove data.archive_file.certs_zip data source
    - _Requirements: 1.5_
  
  - [x] 9.4 Remove EMR permissions from Step Functions role
    - Remove emr-serverless:StartJobRun from Step Functions policy
    - Remove emr-serverless:GetJobRun from Step Functions policy
    - Remove emr-serverless:CancelJobRun from Step Functions policy
    - Remove emr-serverless:ListApplications from Step Functions policy
    - Remove iam:PassRole for emr_serverless_job_role
    - _Requirements: 1.4_
  
  - [x] 9.5 Update KMS key policy to remove EMR statements
    - Remove AllowEMRServicePrincipal statement from KMS key policy
    - Remove AllowEMRServiceRoleUsage statement from KMS key policy
    - Remove AllowEmrServerlessJobRole statement from KMS key policy
    - Keep AllowEcsTaskRoleToUseKey statement
    - _Requirements: 7.1, 7.5_
  
  - [x] 9.6 Remove EMR-related Terraform variables
    - Remove emr_release_label variable
    - Remove emr_max_cpu, emr_max_memory, emr_max_disk variables
    - Remove spark_executor_cores, spark_executor_memory variables
    - Remove spark_executor_memory_overhead, spark_driver_memory variables
    - _Requirements: 13.1, 13.2_

- [x] 10. Verify VPC and network configuration maintained
  - [x] 10.1 Verify VPC configuration unchanged
    - Confirm VPC module configuration is maintained
    - Confirm security group allowing VPC traffic is maintained
    - Confirm VPC endpoints (S3, ECR API, ECR DKR, STS) are maintained
    - _Requirements: 8.1, 8.2, 8.3_
  
  - [x] 10.2 Verify ECS tasks reference correct network resources
    - Confirm ECS task definitions reference private subnets
    - Confirm ECS task definitions reference security group
    - _Requirements: 8.4, 8.5_

- [x] 11. Final checkpoint - Run Terraform plan and validate
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional property-based tests and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation before proceeding
- Property tests validate universal correctness properties for data processing
- Infrastructure tasks focus on Terraform configuration changes
- The Kaggle downloader container already exists (Rust-based) and doesn't need modification
- All container images use git SHA tagging for version control
- Terraform changes should be applied incrementally: add new resources first, then remove EMR resources
- VPC and network configuration should remain unchanged throughout migration
