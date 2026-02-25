# Requirements Document

## Introduction

Ce document spécifie les exigences pour un exécutable Rust qui remplace le script Python `fargate/import_file.py`. L'exécutable doit récupérer des credentials Kaggle depuis AWS Systems Manager, télécharger un dataset Kaggle spécifique, et uploader le fichier résultant vers Amazon S3.

## Glossary

- **Rust_Executable**: L'application Rust compilée qui remplace le script Python
- **SSM_Client**: Le client AWS Systems Manager utilisé pour récupérer les paramètres sécurisés
- **Kaggle_API**: L'interface de téléchargement de datasets Kaggle
- **S3_Client**: Le client Amazon S3 utilisé pour uploader les fichiers
- **Dataset_File**: Le fichier 00.jsonl extrait du dataset Kaggle
- **Credentials**: Les informations d'authentification (username et key) pour Kaggle

## Requirements

### Requirement 1: Retrieve Kaggle Credentials from AWS SSM

**User Story:** As a system operator, I want to retrieve Kaggle credentials securely from AWS SSM, so that the application can authenticate with Kaggle API without hardcoded secrets.

#### Acceptance Criteria

1. THE Rust_Executable SHALL connect to AWS SSM in the eu-west-3 region
2. WHEN retrieving parameters, THE SSM_Client SHALL fetch the parameter "/kaggle/username" with decryption enabled
3. WHEN retrieving parameters, THE SSM_Client SHALL fetch the parameter "/kaggle/key" with decryption enabled
4. IF parameter retrieval fails, THEN THE Rust_Executable SHALL log the error and exit with a non-zero status code
5. THE Rust_Executable SHALL store the retrieved Credentials in memory for subsequent use

### Requirement 2: Download Kaggle Dataset

**User Story:** As a data engineer, I want to download the specific Kaggle dataset, so that I can process and upload it to S3.

#### Acceptance Criteria

1. WHEN Credentials are available, THE Rust_Executable SHALL authenticate with the Kaggle_API
2. THE Rust_Executable SHALL download the dataset from "https://www.kaggle.com/datasets/dschettler8845/the-pile-dataset-part-00-of-29"
3. THE Rust_Executable SHALL save the downloaded dataset to a local temporary directory
4. IF the download fails, THEN THE Rust_Executable SHALL log the error and exit with a non-zero status code
5. WHEN the download completes, THE Rust_Executable SHALL verify that the download directory exists

### Requirement 3: Locate Dataset File

**User Story:** As a data engineer, I want to locate the specific JSONL file within the downloaded dataset, so that I can upload it to S3.

#### Acceptance Criteria

1. WHEN the dataset download completes, THE Rust_Executable SHALL search recursively for a file named "00.jsonl"
2. THE Rust_Executable SHALL search within the download directory and all subdirectories
3. IF the file "00.jsonl" is found, THEN THE Rust_Executable SHALL store its absolute path
4. IF the file "00.jsonl" is not found, THEN THE Rust_Executable SHALL log an error message and exit with a non-zero status code

### Requirement 4: Upload File to S3

**User Story:** As a data engineer, I want to upload the dataset file to S3, so that it is available for downstream processing.

#### Acceptance Criteria

1. WHEN the Dataset_File is located, THE S3_Client SHALL connect to AWS S3 in the eu-west-3 region
2. THE S3_Client SHALL upload the Dataset_File to bucket "sparkresultsjjjmain" with key "the-pile/bronze/00.jsonl"
3. WHEN the upload completes successfully, THE Rust_Executable SHALL log a success message with the S3 URI
4. WHEN the upload completes successfully, THE Rust_Executable SHALL exit with status code 0
5. IF the upload fails, THEN THE Rust_Executable SHALL log the error details and exit with a non-zero status code

### Requirement 5: Error Handling and Logging

**User Story:** As a system operator, I want comprehensive error handling and logging, so that I can diagnose issues when they occur.

#### Acceptance Criteria

1. WHEN any AWS API call fails, THE Rust_Executable SHALL log the error with sufficient context
2. WHEN any file operation fails, THE Rust_Executable SHALL log the error with the file path
3. WHEN any network operation fails, THE Rust_Executable SHALL log the error with the URL or endpoint
4. THE Rust_Executable SHALL log informational messages for major steps (credential retrieval, download start, download complete, upload start, upload complete)
5. THE Rust_Executable SHALL use structured logging with appropriate log levels (error, info, debug)

### Requirement 6: Configuration Constants

**User Story:** As a developer, I want configuration values to be clearly defined, so that they can be easily modified if needed.

#### Acceptance Criteria

1. THE Rust_Executable SHALL define the target filename as "00.jsonl"
2. THE Rust_Executable SHALL define the S3 bucket name as "sparkresultsjjjmain"
3. THE Rust_Executable SHALL define the S3 key as "the-pile/bronze/00.jsonl"
4. THE Rust_Executable SHALL define the Kaggle dataset URL as "https://www.kaggle.com/datasets/dschettler8845/the-pile-dataset-part-00-of-29"
5. THE Rust_Executable SHALL define the AWS region as "eu-west-3"

### Requirement 7: Performance and Resource Management

**User Story:** As a system operator, I want the executable to be performant and resource-efficient, so that it runs efficiently in containerized environments.

#### Acceptance Criteria

1. THE Rust_Executable SHALL stream file uploads to S3 rather than loading entire files into memory
2. WHEN the upload completes or fails, THE Rust_Executable SHALL clean up temporary files
3. THE Rust_Executable SHALL complete the entire workflow within reasonable time bounds for the dataset size
4. THE Rust_Executable SHALL handle large files without excessive memory consumption
