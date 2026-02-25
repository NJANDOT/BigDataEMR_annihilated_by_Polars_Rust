# Implementation Tasks: Python to Rust Kaggle S3 Uploader

## 1. Project Setup and Configuration

- [x] 1.1 Create Cargo.toml with all required dependencies
  - [x] 1.1.1 Add tokio with features: full, signal
  - [x] 1.1.2 Add AWS SDK dependencies: aws-config, aws-sdk-ssm, aws-sdk-s3
  - [x] 1.1.3 Add HTTP client: reqwest with features: stream, json
  - [x] 1.1.4 Add error handling: anyhow
  - [x] 1.1.5 Add streaming utilities: tokio-util, bytes, futures
  - [x] 1.1.6 Add serialization: serde, serde_json
  - [x] 1.1.7 Add logging: tracing, tracing-subscriber
  - [x] 1.1.8 Add file operations: walkdir, tempfile
  - [x] 1.1.9 Add archive handling: zip
  - [x] 1.1.10 Add retry logic: tokio-retry
  - [x] 1.1.11 Add dev dependencies: proptest, mockall, wiremock
  - [x] 1.1.12 Configure release profile with strip, lto, opt-level="z"

- [x] 1.2 Create module structure in fargate/src/
  - [x] 1.2.1 Create config.rs module
  - [x] 1.2.2 Create credentials.rs module
  - [x] 1.2.3 Create kaggle.rs module
  - [x] 1.2.4 Create file_finder.rs module
  - [x] 1.2.5 Create s3_uploader.rs module
  - [x] 1.2.6 Create progress.rs module

## 2. Core Module Implementation

- [x] 2.1 Implement config module (config.rs)
  - [x] 2.1.1 Define Config struct with all configuration constants
  - [x] 2.1.2 Implement Config::default() with hardcoded values
  - [x] 2.1.3 Set aws_region to "eu-west-3"
  - [x] 2.1.4 Set SSM parameters: "/kaggle/username", "/kaggle/key"
  - [x] 2.1.5 Set Kaggle dataset URL
  - [x] 2.1.6 Set target_filename to "00.jsonl"
  - [x] 2.1.7 Set S3 bucket to "sparkresultsjjjmain"
  - [x] 2.1.8 Set S3 key to "the-pile/bronze/00.jsonl"

- [x] 2.2 Implement credentials module (credentials.rs)
  - [x] 2.2.1 Define KaggleCredentials struct
  - [x] 2.2.2 Implement fetch_kaggle_credentials function
  - [x] 2.2.3 Add SSM parameter retrieval with decryption
  - [x] 2.2.4 Add error context for SSM operations
  - [x] 2.2.5 Implement fetch_kaggle_credentials_with_retry wrapper
  - [x] 2.2.6 Configure exponential backoff (100ms base, 5s max, 3 attempts)
  - [x] 2.2.7 Add debug logging for parameter retrieval
  - [x] 2.2.8 Add info logging for successful retrieval

- [x] 2.3 Implement progress tracker module (progress.rs)
  - [x] 2.3.1 Define ProgressTracker struct with total_size, current_size, last_logged_percent
  - [x] 2.3.2 Implement ProgressTracker::new()
  - [x] 2.3.3 Implement ProgressTracker::update() method
  - [x] 2.3.4 Calculate percentage progress
  - [x] 2.3.5 Log every 10% increment using tracing::info!
  - [x] 2.3.6 Include operation_name in log messages

- [x] 2.4 Implement file finder module (file_finder.rs)
  - [x] 2.4.1 Implement find_file_recursive function
  - [x] 2.4.2 Use WalkDir for recursive directory traversal
  - [x] 2.4.3 Filter for files only (not directories)
  - [x] 2.4.4 Compare filename (not full path)
  - [x] 2.4.5 Return canonicalized absolute path
  - [x] 2.4.6 Return error if file not found
  - [x] 2.4.7 Add debug logging for search operations

## 3. Kaggle Download Implementation

- [x] 3.1 Implement kaggle module (kaggle.rs)
  - [x] 3.1.1 Implement download_kaggle_dataset function signature
  - [x] 3.1.2 Parse dataset URL to extract owner and slug
  - [x] 3.1.3 Construct Kaggle API download URL
  - [x] 3.1.4 Create reqwest client with basic auth
  - [x] 3.1.5 Send GET request with credentials
  - [x] 3.1.6 Handle HTTP redirects automatically
  - [x] 3.1.7 Get content length for progress tracking
  - [x] 3.1.8 Stream response to temporary file
  - [x] 3.1.9 Update progress tracker during download
  - [x] 3.1.10 Flush file after download completes

- [x] 3.2 Implement ZIP extraction (kaggle.rs)
  - [x] 3.2.1 Implement extract_zip helper function
  - [x] 3.2.2 Open ZIP archive from file
  - [x] 3.2.3 Iterate through archive entries
  - [x] 3.2.4 Create directories for nested paths
  - [x] 3.2.5 Extract files to target directory
  - [x] 3.2.6 Handle enclosed_name() for security
  - [x] 3.2.7 Add error context for extraction operations

- [x] 3.3 Add cleanup and logging (kaggle.rs)
  - [x] 3.3.1 Remove ZIP archive after extraction
  - [x] 3.3.2 Return extraction directory path
  - [x] 3.3.3 Add debug logging for API URL
  - [x] 3.3.4 Add info logging for download start
  - [x] 3.3.5 Add info logging for download complete
  - [x] 3.3.6 Add info logging for extraction complete

## 4. S3 Upload Implementation

- [x] 4.1 Implement s3_uploader module (s3_uploader.rs)
  - [x] 4.1.1 Implement upload_file_to_s3 function signature
  - [x] 4.1.2 Get file metadata for size
  - [x] 4.1.3 Add size-based upload strategy (simple vs multipart)
  - [x] 4.1.4 Implement simple upload for files < 100MB
  - [x] 4.1.5 Use ByteStream::from_path for simple upload
  - [x] 4.1.6 Call s3_client.put_object()
  - [x] 4.1.7 Add success logging with S3 URI

- [x] 4.2 Implement multipart upload (s3_uploader.rs)
  - [x] 4.2.1 Implement upload_multipart_with_progress function
  - [x] 4.2.2 Initiate multipart upload
  - [x] 4.2.3 Read file in 10MB chunks
  - [x] 4.2.4 Upload each part with part number
  - [x] 4.2.5 Track completed parts with ETags
  - [x] 4.2.6 Update progress tracker for each part
  - [x] 4.2.7 Complete multipart upload with all parts
  - [x] 4.2.8 Add error context for upload operations

## 5. Main Application Orchestration

- [x] 5.1 Implement main function (main.rs)
  - [x] 5.1.1 Add tokio::main attribute
  - [x] 5.1.2 Initialize tracing subscriber with env filter
  - [x] 5.1.3 Set default log level to INFO
  - [x] 5.1.4 Add startup info log
  - [x] 5.1.5 Setup shutdown handler
  - [x] 5.1.6 Use tokio::select! for workflow and shutdown

- [x] 5.2 Implement signal handling (main.rs)
  - [x] 5.2.1 Implement setup_shutdown_handler function
  - [x] 5.2.2 Listen for SIGTERM on Unix systems
  - [x] 5.2.3 Listen for SIGINT on Unix systems
  - [x] 5.2.4 Use Ctrl+C handler for non-Unix systems
  - [x] 5.2.5 Add info logging for received signals

- [x] 5.3 Implement workflow orchestration (main.rs)
  - [x] 5.3.1 Implement run_workflow function
  - [x] 5.3.2 Load configuration from Config::default()
  - [x] 5.3.3 Create AWS config with region
  - [x] 5.3.4 Initialize SSM client
  - [x] 5.3.5 Initialize S3 client
  - [x] 5.3.6 Fetch Kaggle credentials with retry
  - [x] 5.3.7 Create temporary directory
  - [x] 5.3.8 Download Kaggle dataset
  - [x] 5.3.9 Find target file recursively
  - [x] 5.3.10 Upload file to S3
  - [x] 5.3.11 Add error context at each step
  - [x] 5.3.12 Add info logging for each major step

## 6. Testing Implementation

- [x] 6.1 Setup test infrastructure
  - [x] 6.1.1 Create tests/ directory
  - [x] 6.1.2 Configure proptest with 100 iterations minimum
  - [x] 6.1.3 Setup mockall for AWS client mocking
  - [x] 6.1.4 Setup wiremock for HTTP mocking

- [~] 6.2 Implement unit tests
  - [~] 6.2.1 Test Config::default() returns correct values
  - [~] 6.2.2 Test credentials parsing from SSM response
  - [~] 6.2.3 Test progress tracker percentage calculation
  - [~] 6.2.4 Test progress tracker 10% logging
  - [~] 6.2.5 Test file finder with file in root directory
  - [~] 6.2.6 Test file finder with nested file
  - [~] 6.2.7 Test file finder returns absolute path
  - [~] 6.2.8 Test file finder error when file not found

- [~] 6.3 Implement property-based tests
  - [~] 6.3.1 Property 1: Error propagation test
  - [~] 6.3.2 Property 2: Download creates file test
  - [~] 6.3.3 Property 3: Extraction creates directory test
  - [~] 6.3.4 Property 4: Recursive file search test
  - [~] 6.3.5 Property 5: Absolute path return test
  - [~] 6.3.6 Property 6: File not found error test
  - [~] 6.3.7 Property 7: Successful workflow exit code test
  - [~] 6.3.8 Property 8: Temporary file cleanup test

- [~] 6.4 Implement integration tests
  - [~] 6.4.1 Test complete workflow with mocked AWS services
  - [~] 6.4.2 Test retry logic with transient failures
  - [~] 6.4.3 Test graceful shutdown with SIGTERM
  - [~] 6.4.4 Test error handling and cleanup on failure

## 7. Docker Configuration

- [x] 7.1 Update Dockerfile
  - [x] 7.1.1 Set builder stage with rust:1.75
  - [x] 7.1.2 Copy Cargo.toml and Cargo.lock
  - [x] 7.1.3 Copy src directory
  - [x] 7.1.4 Build release binary
  - [x] 7.1.5 Set runtime stage with debian:bookworm-slim
  - [x] 7.1.6 Install ca-certificates for HTTPS
  - [x] 7.1.7 Copy binary from builder stage
  - [x] 7.1.8 Set correct binary name: kaggle-s3-uploader
  - [x] 7.1.9 Set executable permissions
  - [x] 7.1.10 Set CMD to run the binary

## 8. Documentation and Finalization

- [x] 8.1 Add inline documentation
  - [x] 8.1.1 Add module-level documentation comments
  - [x] 8.1.2 Add function-level documentation comments
  - [x] 8.1.3 Document error conditions
  - [x] 8.1.4 Document configuration constants

- [x] 8.2 Create README for fargate directory
  - [x] 8.2.1 Document build instructions
  - [x] 8.2.2 Document local testing instructions
  - [x] 8.2.3 Document Docker build and push
  - [x] 8.2.4 Document environment variables

- [x] 8.3 Verify and test
  - [x] 8.3.1 Run cargo clippy for linting
  - [x] 8.3.2 Run cargo fmt for formatting
  - [x] 8.3.3 Run all unit tests
  - [x] 8.3.4 Run all property-based tests
  - [x] 8.3.5 Build Docker image locally
  - [x] 8.3.6 Test Docker image with mock credentials
  - [x] 8.3.7 Verify binary size optimization
  - [x] 8.3.8 Verify logging output format

## 9. Terraform Integration

- [~] 9.1 Update ECS task definition
  - [~] 9.1.1 Update container image reference to new binary name
  - [ ] 9.1.2 Verify environment variables are not needed (using SSM)
  - [~] 9.1.3 Verify IAM permissions for SSM and S3
  - [~] 9.1.4 Test task execution in Fargate

- [~] 9.2 Validate Step Functions integration
  - [~] 9.2.1 Verify ECS task is triggered correctly
  - [~] 9.2.2 Verify logs appear in CloudWatch
  - [~] 9.2.3 Verify S3 upload completes before EMR job starts
  - [~] 9.2.4 Test complete pipeline end-to-end
