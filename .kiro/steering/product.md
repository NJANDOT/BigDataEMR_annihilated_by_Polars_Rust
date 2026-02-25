# Product Overview

End-to-end AWS Big Data pipeline demonstrating Medallion Architecture (Bronze → Silver → Gold) for processing large-scale datasets.

## Pipeline Flow

1. **Ingestion (Fargate)**: Downloads ~50GB dataset from Kaggle (The Pile - JSONL format) and uploads to S3 Bronze layer
2. **Processing (EMR Serverless)**: Apache Spark jobs transform data through Bronze → Silver → Gold layers
3. **Infrastructure (Terraform)**: Automated provisioning of VPC, EMR, IAM, KMS, and Step Functions orchestration

## Key Features

- Medallion architecture for data quality progression
- Fargate-based ingestion (chosen over Lambda for large file handling)
- EMR Serverless for distributed Spark processing
- Step Functions orchestration for multi-stage pipeline
- Secure credential management via AWS SSM
- KMS encryption for data at rest and in transit

## Target Dataset

The Pile dataset (part 00 of 29) - large-scale text corpus in JSONL format, processed and partitioned by metadata for efficient querying with Amazon Athena.

## Active Migration

Currently migrating the Fargate ingestion component from Python to Rust for improved performance and resource efficiency.
