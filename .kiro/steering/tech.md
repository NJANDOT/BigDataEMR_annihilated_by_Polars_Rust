# Technology Stack

## Languages & Runtimes

- **Python 3.8+**: PySpark transformation scripts
- **Rust 1.75+**: Fargate ingestion container (migration in progress)
- **HCL**: Terraform infrastructure definitions

## AWS Services

- **Fargate**: Containerized data ingestion (16 vCPU, 122GB RAM, 200GB ephemeral storage)
- **EMR Serverless 7.1.0**: Apache Spark distributed processing
- **S3**: Data lake storage (Bronze/Silver/Gold layers)
- **Step Functions**: Pipeline orchestration
- **Systems Manager (SSM)**: Secure credential storage
- **KMS**: Encryption key management
- **ECR**: Container registry
- **VPC**: Network isolation with private subnets

## Infrastructure

- **Terraform 1.5+**: IaC for complete AWS infrastructure
- **Region**: eu-west-3 (Paris)
- **Bucket**: sparkresultsjjjmain

## Data Processing

- **Apache Spark**: Distributed data transformation
- **PySpark**: Python API for Spark
- **Parquet**: Columnar storage format with Snappy compression
- **JSONL**: Input data format

## Python Dependencies

- `pyspark`: Spark DataFrame operations
- `pytest`: Unit testing framework

## Rust Dependencies (Fargate Migration)

- `tokio`: Async runtime
- `aws-sdk-ssm`, `aws-sdk-s3`: AWS service clients
- `reqwest`: HTTP client for Kaggle API
- `anyhow`: Error handling
- `tracing`: Structured logging
- `walkdir`: Recursive file search
- `zip`: Archive extraction
- `proptest`: Property-based testing

## Common Commands

### Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve

# Import existing KMS key
terraform import aws_kms_key.emr <ARN-of-kms-key>
```

### Docker (Fargate Container)

```bash
# Build and push to ECR
aws ecr create-repository --repository-name emr-project
docker build -t <account>.dkr.ecr.eu-west-3.amazonaws.com/emr_fine:latest .
docker push <account>.dkr.ecr.eu-west-3.amazonaws.com/emr_fine:latest
```

### Rust (Local Development)

```bash
cd fargate
cargo build --release
cargo test
cargo run --release
```

### Python Testing

```bash
cd code
pytest test_clean_df.py -v
```

### AWS CLI

```bash
# Configure credentials
aws configure

# Check Step Functions execution
aws stepfunctions list-executions --state-machine-arn <arn>

# View EMR Serverless logs
aws s3 ls s3://sparkresultsjjjmain/logs/
```

## Build System

- **Cargo**: Rust package manager and build tool
- **Docker**: Multi-stage builds for optimized container images
- **GitHub Actions**: CI/CD for S3 script deployment

## Testing

- **pytest**: Python unit tests with PySpark fixtures
- **proptest**: Rust property-based testing (100+ iterations per property)
- **mockall**: Rust mocking framework for AWS clients
- **wiremock**: HTTP mock server for Kaggle API tests
