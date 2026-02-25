//! AWS Systems Manager (SSM) credentials retrieval module.
//!
//! This module handles secure retrieval of Kaggle API credentials from AWS SSM Parameter Store.
//! It implements retry logic with exponential backoff to handle transient failures.
//!
//! # Configuration Constants
//!
//! - **Retry Base Delay**: 100 milliseconds
//! - **Retry Max Delay**: 5 seconds
//! - **Retry Max Attempts**: 3
//! - **Retry Strategy**: Exponential backoff
//!
//! # Security
//!
//! - Credentials are retrieved with decryption enabled from SSM
//! - No credentials are hardcoded or stored in environment variables
//! - All SSM operations are logged for audit purposes
//!
//! # Error Conditions
//!
//! Credential retrieval can fail due to:
//! - SSM parameters not existing in the specified region
//! - Insufficient IAM permissions (missing `ssm:GetParameter` or `kms:Decrypt`)
//! - Network connectivity issues to AWS SSM endpoints
//! - Empty or null parameter values
//! - KMS key unavailability for decryption
//! - AWS service throttling or rate limiting

use anyhow::{Context, Result};
use aws_sdk_ssm::Client as SsmClient;
use tokio_retry::{strategy::ExponentialBackoff, Retry};
use tracing::{debug, info};

/// Kaggle API credentials retrieved from AWS Systems Manager.
///
/// These credentials are used for HTTP basic authentication when downloading
/// datasets from the Kaggle API.
pub struct KaggleCredentials {
    /// Kaggle username
    pub username: String,
    /// Kaggle API key
    pub key: String,
}

/// Fetches Kaggle credentials from AWS SSM with retry logic.
///
/// This function wraps `fetch_kaggle_credentials` with exponential backoff retry
/// to handle transient failures such as network issues or temporary SSM unavailability.
///
/// # Retry Strategy
///
/// - Base delay: 100ms
/// - Max delay: 5 seconds
/// - Max attempts: 3
/// - Backoff: Exponential
///
/// # Arguments
///
/// * `ssm_client` - AWS SSM client for parameter retrieval
/// * `username_param` - SSM parameter name for Kaggle username (e.g., "/kaggle/username")
/// * `key_param` - SSM parameter name for Kaggle API key (e.g., "/kaggle/key")
///
/// # Returns
///
/// Returns `Ok(KaggleCredentials)` on success, or an error if retrieval fails after all retries.
///
/// # Errors
///
/// This function will return an error if:
/// - SSM parameters do not exist
/// - IAM permissions are insufficient
/// - Network connectivity issues persist after retries
/// - Parameter values are empty
pub async fn fetch_kaggle_credentials_with_retry(
    ssm_client: &SsmClient,
    username_param: &str,
    key_param: &str,
) -> Result<KaggleCredentials> {
    let retry_strategy = ExponentialBackoff::from_millis(100)
        .max_delay(std::time::Duration::from_secs(5))
        .take(3); // 3 attempts

    Retry::spawn(retry_strategy, || async {
        fetch_kaggle_credentials(ssm_client, username_param, key_param).await
    })
    .await
}

/// Fetches Kaggle credentials from AWS SSM parameters.
///
/// Retrieves both username and API key from SSM with decryption enabled.
/// This is the internal implementation called by `fetch_kaggle_credentials_with_retry`.
///
/// # Arguments
///
/// * `ssm_client` - AWS SSM client for parameter retrieval
/// * `username_param` - SSM parameter name for Kaggle username
/// * `key_param` - SSM parameter name for Kaggle API key
///
/// # Returns
///
/// Returns `Ok(KaggleCredentials)` on success.
///
/// # Errors
///
/// This function will return an error if:
/// - Any SSM parameter is missing or inaccessible
/// - Parameter values are empty
/// - Decryption fails
async fn fetch_kaggle_credentials(
    ssm_client: &SsmClient,
    username_param: &str,
    key_param: &str,
) -> Result<KaggleCredentials> {
    debug!("Fetching SSM parameter: {}", username_param);
    let username = ssm_client
        .get_parameter()
        .name(username_param)
        .with_decryption(true)
        .send()
        .await
        .context(format!(
            "Failed to retrieve SSM parameter: {}",
            username_param
        ))?
        .parameter
        .and_then(|p| p.value)
        .context("SSM parameter value is empty")?;

    debug!("Fetching SSM parameter: {}", key_param);
    let key = ssm_client
        .get_parameter()
        .name(key_param)
        .with_decryption(true)
        .send()
        .await
        .context(format!("Failed to retrieve SSM parameter: {}", key_param))?
        .parameter
        .and_then(|p| p.value)
        .context("SSM parameter value is empty")?;

    info!("Successfully retrieved Kaggle credentials");

    Ok(KaggleCredentials { username, key })
}
