# Requirements Document

## Introduction

This document specifies the requirements for migrating a data processing pipeline from EMR Serverless (Apache Spark) to ECS Fargate (Polars). The current architecture uses EMR Serverless for processing ~50GB of data with Spark. The target architecture replaces Spark with Polars-based Python scripts running in Fargate containers, orchestrated by AWS Step Functions. All infrastructure is managed via Terraform.

## Glossary

- **Pipeline**: The complete data processing workflow from ingestion to final output
- **Kaggle_Downloader**: Rust-based Fargate container that downloads datasets from Kaggle and uploads to S3
- **Bronze_To_Silver_Processor**: Python Fargate container that converts raw JSONL data to Parquet format using Polars
- **Silver_To_Gold_Processor**: Python Fargate container that cleans, filters, and partitions data using Polars
- **Step_Functions_State_Machine**: AWS orchestration service that sequences the three Fargate tasks
- **Terraform_Configuration**: Infrastructure as Code files that provision all AWS resources
- **ECR_Repository**: Amazon Elastic Container Registry storing Docker images
- **ECS_Task_Definition**: Configuration specifying container resources, image, and execution parameters
- **Bronze_Layer**: S3 location containing raw JSONL data from Kaggle
- **Silver_Layer**: S3 location containing converted Parquet data
- **Gold_Layer**: S3 location containing cleaned, filtered, and partitioned final data
- **KMS_Key**: AWS Key Management Service encryption key for S3 and EBS volumes

## Requirements

### Requirement 1: Remove EMR Serverless Infrastructure

**User Story:** As a DevOps engineer, I want to remove all EMR Serverless resources from the Terraform configuration, so that the infrastructure no longer provisions or manages EMR components.

#### Acceptance Criteria

1. THE Terraform_Configuration SHALL remove the aws_emrserverless_application resource definition
2. THE Terraform_Configuration SHALL remove the emr_serverless_job_role IAM role and associated policies
3. THE Terraform_Configuration SHALL remove the aws_emr_security_configuration resource
4. THE Terraform_Configuration SHALL remove all EMR-related IAM policy statements from the Step Functions role
5. THE Terraform_Configuration SHALL remove the S3 object resource for certs.zip used by EMR encryption

### Requirement 2: Create ECS Task Definitions for Processing Containers

**User Story:** As a DevOps engineer, I want to define ECS task definitions for the bronze-to-silver and silver-to-gold processors, so that Fargate can execute these containers with appropriate resource allocations.

#### Acceptance Criteria

1. THE Terraform_Configuration SHALL create an ECS task definition for Bronze_To_Silver_Processor with 4 vCPU and 16GB memory
2. THE Terraform_Configuration SHALL create an ECS task definition for Silver_To_Gold_Processor with 8 vCPU and 32GB memory
3. WHERE the task definition is for Bronze_To_Silver_Processor, THE Terraform_Configuration SHALL configure ephemeral storage of at least 100GB
4. WHERE the task definition is for Silver_To_Gold_Processor, THE Terraform_Configuration SHALL configure ephemeral storage of at least 200GB
5. THE Terraform_Configuration SHALL configure both task definitions to use the existing ecs_execution_role and ecs_task_role
6. THE Terraform_Configuration SHALL configure both task definitions with awslogs driver pointing to CloudWatch log groups
7. THE Terraform_Configuration SHALL reference ECR image URIs using the pattern account_id.dkr.ecr.region.amazonaws.com/repository:tag

### Requirement 3: Update Step Functions State Machine

**User Story:** As a DevOps engineer, I want to update the Step Functions state machine to orchestrate three sequential Fargate tasks instead of EMR jobs, so that the pipeline executes the new Polars-based processing.

#### Acceptance Criteria

1. THE Step_Functions_State_Machine SHALL execute Kaggle_Downloader as the first task using ecs:runTask.sync
2. WHEN Kaggle_Downloader completes successfully, THE Step_Functions_State_Machine SHALL execute Bronze_To_Silver_Processor using ecs:runTask.sync
3. WHEN Bronze_To_Silver_Processor completes successfully, THE Step_Functions_State_Machine SHALL execute Silver_To_Gold_Processor using ecs:runTask.sync
4. THE Step_Functions_State_Machine SHALL remove all emr-serverless:startJobRun task definitions
5. THE Step_Functions_State_Machine SHALL configure each ECS task with the existing VPC private subnet and security group
6. THE Step_Functions_State_Machine SHALL configure each ECS task with AssignPublicIp set to DISABLED
7. THE Step_Functions_State_Machine SHALL reference the correct ECS task definition ARN for each processing stage

### Requirement 4: Create Dockerfiles for Python Processing Containers

**User Story:** As a developer, I want Dockerfiles for the bronze-to-silver and silver-to-gold processors, so that I can build container images with Polars and all required dependencies.

#### Acceptance Criteria

1. THE Bronze_To_Silver_Processor SHALL have a Dockerfile that uses a Python 3.9+ base image
2. THE Bronze_To_Silver_Processor Dockerfile SHALL install polars, s3fs, and pyarrow packages
3. THE Bronze_To_Silver_Processor Dockerfile SHALL copy bronze_to_silver.py and consts_proj.py into the container
4. THE Bronze_To_Silver_Processor Dockerfile SHALL set the entrypoint to execute bronze_to_silver.py
5. THE Silver_To_Gold_Processor SHALL have a Dockerfile that uses a Python 3.9+ base image
6. THE Silver_To_Gold_Processor Dockerfile SHALL install polars, s3fs, pyarrow, and numpy packages
7. THE Silver_To_Gold_Processor Dockerfile SHALL copy silver_to_gold.py and consts_proj.py into the container
8. THE Silver_To_Gold_Processor Dockerfile SHALL set the entrypoint to execute silver_to_gold.py

### Requirement 5: Update GitHub Actions Workflow

**User Story:** As a developer, I want the GitHub Actions workflow to build and push Docker images for all three containers to ECR, so that the latest code changes are automatically deployed.

#### Acceptance Criteria

1. THE GitHub_Actions_Workflow SHALL build the Kaggle_Downloader Docker image from the fargate directory
2. THE GitHub_Actions_Workflow SHALL build the Bronze_To_Silver_Processor Docker image
3. THE GitHub_Actions_Workflow SHALL build the Silver_To_Gold_Processor Docker image
4. THE GitHub_Actions_Workflow SHALL authenticate to ECR before pushing images
5. THE GitHub_Actions_Workflow SHALL tag each image with a version identifier derived from the git commit SHA or branch name
6. THE GitHub_Actions_Workflow SHALL push all three images to the configured ECR repository
7. THE GitHub_Actions_Workflow SHALL remove the upload-script job that copies Python files to S3

### Requirement 6: Configure IAM Permissions for ECS Tasks

**User Story:** As a security engineer, I want ECS tasks to have appropriate IAM permissions, so that containers can access S3 buckets and ECR repositories without excessive privileges.

#### Acceptance Criteria

1. THE ecs_task_role SHALL include permissions for s3:GetObject, s3:PutObject, and s3:ListBucket on the data bucket
2. THE ecs_task_role SHALL include permissions for s3:DeleteObject on the data bucket for cleanup operations
3. THE ecs_execution_role SHALL include permissions for ecr:GetAuthorizationToken
4. THE ecs_execution_role SHALL include permissions for ecr:BatchCheckLayerAvailability, ecr:GetDownloadUrlForLayer, and ecr:BatchGetImage on the ECR repository
5. THE ecs_execution_role SHALL include permissions for logs:CreateLogStream, logs:PutLogEvents, and logs:CreateLogGroup
6. THE Step_Functions_Role SHALL include permissions for ecs:RunTask, ecs:DescribeTasks, and ecs:StopTask
7. THE Step_Functions_Role SHALL include permissions for iam:PassRole for both ecs_execution_role and ecs_task_role

### Requirement 7: Configure S3 Encryption with KMS

**User Story:** As a security engineer, I want S3 data encrypted with KMS and EBS volumes encrypted, so that data at rest is protected according to security requirements.

#### Acceptance Criteria

1. THE Terraform_Configuration SHALL maintain the existing KMS key resource for encryption
2. THE ecs_task_role SHALL include permissions for kms:Decrypt, kms:GenerateDataKey, and kms:DescribeKey on the KMS key
3. THE S3_Bucket SHALL maintain SSE-KMS encryption configuration using the existing KMS key
4. WHERE ECS tasks use ephemeral storage, THE Terraform_Configuration SHALL configure EBS volume encryption using the KMS key
5. THE Terraform_Configuration SHALL maintain the prevent_destroy lifecycle rule on the KMS key

### Requirement 8: Maintain VPC and Network Configuration

**User Story:** As a network engineer, I want the existing VPC, subnets, and security groups to be reused for Fargate tasks, so that network isolation and connectivity remain consistent.

#### Acceptance Criteria

1. THE Terraform_Configuration SHALL maintain the existing VPC module configuration
2. THE Terraform_Configuration SHALL maintain the existing security group allowing all traffic within the VPC
3. THE Terraform_Configuration SHALL maintain the existing VPC endpoints for S3, ECR API, ECR DKR, and STS
4. THE ECS_Task_Definition SHALL reference the existing private subnets for task execution
5. THE ECS_Task_Definition SHALL reference the existing security group for network access

### Requirement 9: Configure CloudWatch Logging

**User Story:** As a DevOps engineer, I want all Fargate tasks to log to CloudWatch, so that I can monitor execution and troubleshoot failures.

#### Acceptance Criteria

1. THE Terraform_Configuration SHALL create CloudWatch log groups for bronze-to-silver-processor and silver-to-gold-processor
2. THE CloudWatch_Log_Groups SHALL have a retention period matching the existing configuration
3. THE ECS_Task_Definition SHALL configure the awslogs driver with the appropriate log group, region, and stream prefix
4. THE ecs_execution_role SHALL have permissions to create log streams and put log events to the configured log groups

### Requirement 10: Validate Resource Allocation

**User Story:** As a data engineer, I want appropriate CPU and memory allocated to each processing stage, so that the pipeline processes 50GB of data efficiently without resource exhaustion.

#### Acceptance Criteria

1. THE Kaggle_Downloader SHALL be allocated 2 vCPU and 4GB memory for I/O-bound operations
2. THE Bronze_To_Silver_Processor SHALL be allocated 4 vCPU and 16GB memory for lazy scan and sink operations
3. THE Silver_To_Gold_Processor SHALL be allocated 8 vCPU and 32GB memory for in-memory processing of 50GB data
4. WHERE a task processes data exceeding memory capacity, THE ECS_Task_Definition SHALL provide sufficient ephemeral storage for spill-to-disk
5. THE Terraform_Configuration SHALL validate that CPU and memory combinations are valid Fargate configurations

### Requirement 11: Ensure Data Processing Correctness

**User Story:** As a data engineer, I want the Polars-based processing to produce equivalent output to the Spark implementation, so that downstream consumers receive consistent data.

#### Acceptance Criteria

1. THE Bronze_To_Silver_Processor SHALL read JSONL files from the Bronze_Layer using polars.scan_ndjson
2. THE Bronze_To_Silver_Processor SHALL parse the schema with text as String and meta as Struct containing pile_set_name
3. THE Bronze_To_Silver_Processor SHALL write Parquet output to the Silver_Layer using sink_parquet
4. THE Silver_To_Gold_Processor SHALL read Parquet files from the Silver_Layer using polars.read_parquet
5. THE Silver_To_Gold_Processor SHALL filter rows where text length is greater than 100 characters
6. THE Silver_To_Gold_Processor SHALL filter out rows where text contains the word "copyright"
7. THE Silver_To_Gold_Processor SHALL extract pile_set_name from the meta struct into a set_name column
8. THE Silver_To_Gold_Processor SHALL partition output by _partition_idx calculated as row_number modulo partition_count
9. THE Silver_To_Gold_Processor SHALL write partitioned Parquet output to the Gold_Layer with snappy compression
10. WHERE the Gold_Layer already exists, THE Silver_To_Gold_Processor SHALL delete it before writing new data

### Requirement 12: Handle Container Failures

**User Story:** As a DevOps engineer, I want the Step Functions state machine to handle container failures gracefully, so that I can identify and retry failed processing stages.

#### Acceptance Criteria

1. WHEN an ECS task fails, THE Step_Functions_State_Machine SHALL capture the failure state
2. WHEN an ECS task fails, THE Step_Functions_State_Machine SHALL include error information in the execution output
3. THE Step_Functions_State_Machine SHALL configure retry logic with exponential backoff for transient failures
4. THE Step_Functions_State_Machine SHALL configure a maximum retry count of 3 attempts per task
5. WHEN all retries are exhausted, THE Step_Functions_State_Machine SHALL transition to a failure state

### Requirement 13: Maintain Terraform State Consistency

**User Story:** As a DevOps engineer, I want Terraform to cleanly transition from EMR to Fargate resources, so that infrastructure changes can be applied without manual intervention.

#### Acceptance Criteria

1. THE Terraform_Configuration SHALL allow destruction of EMR resources without affecting other infrastructure
2. THE Terraform_Configuration SHALL create new ECS task definitions without conflicts with existing resources
3. THE Terraform_Configuration SHALL update the Step Functions state machine in place
4. WHERE resource names conflict, THE Terraform_Configuration SHALL use unique identifiers to prevent collisions
5. THE Terraform_Configuration SHALL maintain the existing S3 bucket and data without modification
