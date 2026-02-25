# Project Structure

## Root Layout

```
.
├── code/              # PySpark transformation scripts
├── fargate/           # Ingestion container (Rust migration)
├── terraform/         # Infrastructure as Code
├── data/              # Local data directory (empty in repo)
├── .kiro/             # Kiro configuration and specs
└── .github/           # CI/CD workflows
```

## Code Directory (`code/`)

PySpark scripts for EMR Serverless execution:

- `bronze_to_silver.py`: Reads raw JSONL from S3 Bronze, converts to Parquet in Silver layer
- `silver_to_gold.py`: Silver → Gold transformation with filtering and partitioning
- `transform_df.py`: Reusable transformation functions (filter by length, remove copyright text)
- `test_clean_df.py`: pytest unit tests for transformations
- `install_python_libs.sh`: Dependency installation script

**Key Pattern**: Scripts are uploaded to S3 and referenced by EMR Step Functions.

## Fargate Directory (`fargate/`)

Container for Kaggle dataset ingestion:

```
fargate/
├── src/
│   └── main.rs        # Rust application entry point (migration in progress)
├── dockerfile         # Multi-stage build (Rust builder + Debian runtime)
└── Cargo.toml         # Rust dependencies (to be created)
```

**Current State**: Transitioning from Python to Rust for performance optimization.

## Terraform Directory (`terraform/`)

Complete AWS infrastructure definition:

- `main.tf`: Primary infrastructure (VPC, EMR, ECS, Step Functions, IAM, KMS)
- `variables.tf`: Configuration variables (region, bucket name)
- `certs/`: TLS certificates for EMR encryption
- `build/`: Generated artifacts (certs.zip)

**Key Resources**:
- VPC with public/private subnets (10.0.0.0/16)
- VPC endpoints for S3, ECR, STS
- ECS Fargate task definition (16 vCPU, 122GB RAM)
- EMR Serverless application (Spark 7.1.0)
- Step Functions state machine (3-stage pipeline)
- KMS key for encryption at rest and in transit

## Kiro Directory (`.kiro/`)

```
.kiro/
├── specs/
│   └── python-to-rust-kaggle-s3-uploader/
│       ├── requirements.md    # Feature requirements
│       ├── design.md          # Technical design
│       └── tasks.md           # Implementation tasks
├── steering/                  # Project guidance documents
└── hooks/                     # Automation hooks
```

## Data Flow Architecture

```
Kaggle Dataset
    ↓
[Fargate Container] → S3 Bronze (s3://sparkresultsjjjmain/the-pile/bronze/00.jsonl)
    ↓
[EMR: bronze_to_silver.py] → S3 Silver (s3://sparkresultsjjjmain/silver/00.parquet)
    ↓
[EMR: silver_to_gold.py] → S3 Gold (s3://sparkresultsjjjmain/gold/thepile/)
    ↓
[Amazon Athena] (Query-ready partitioned Parquet)
```

## Configuration Files

- `.env.example`: Template for local environment variables
- `.gitignore`: Excludes credentials, Terraform state, build artifacts
- `kaggle.json`: Kaggle API credentials (stored in multiple locations, should use SSM)

## Naming Conventions

- **S3 Paths**: `{layer}/{dataset}/{file}` (e.g., `the-pile/bronze/00.jsonl`)
- **IAM Roles**: `{service}_{purpose}_role` (e.g., `ecs_task_role`)
- **Terraform Resources**: `{service}_{descriptor}` (e.g., `aws_ecs_cluster.main`)
- **Python Functions**: `snake_case` (e.g., `transform_df`)
- **Rust Modules**: `snake_case` (e.g., `credentials.rs`, `s3_uploader.rs`)

## Security Notes

- Credentials stored in AWS SSM Parameter Store (`/kaggle/username`, `/kaggle/key`)
- KMS encryption for S3 and EBS volumes
- VPC endpoints for private AWS service access
- Git history sanitized to remove exposed credentials
