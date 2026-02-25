use anyhow::Result;
use tracing::{error, info};
mod config;
mod credentials;
mod file_finder;
mod kaggle;
mod s3_uploader;

async fn run_workflow() -> Result<()> {
    use anyhow::Context;

    let config = config::Config::default();

    let aws_config = aws_config::defaults(aws_config::BehaviorVersion::latest())
        .region(aws_config::Region::new(config.aws_region))
        .load()
        .await;

    let ssm_client = aws_sdk_ssm::Client::new(&aws_config);
    let s3_client = aws_sdk_s3::Client::new(&aws_config);

    info!("Fetching Kaggle credentials from SSM");
    let credentials = credentials::fetch_kaggle_credentials_with_retry(
        &ssm_client,
        config.ssm_username_param,
        config.ssm_key_param,
    )
    .await
    .context("Failed to fetch Kaggle credentials")?;

    info!("Creating temporary directory");
    let temp_dir = tempfile::tempdir().context("Failed to create temporary directory")?;

    info!(
        "Downloading Kaggle dataset from {}",
        config.kaggle_dataset_url
    );
    let extract_dir =
        kaggle::download_kaggle_dataset(&credentials, config.kaggle_dataset_url, temp_dir.path())
            .await
            .context("Failed to download Kaggle dataset")?;

    info!("Searching for file: {}", config.target_filename);
    let file_path = file_finder::find_file_recursive(&extract_dir, config.target_filename)
        .context("Failed to locate target file")?;

    info!("Found file at: {:?}", file_path);

    info!(
        "Uploading to S3: s3://{}/{}",
        config.s3_bucket, config.s3_key
    );
    s3_uploader::upload_file_to_s3(&s3_client, &file_path, config.s3_bucket, config.s3_key)
        .await
        .context("Failed to upload file to S3")?;

    info!(
        "Successfully uploaded to s3://{}/{}",
        config.s3_bucket, config.s3_key
    );

    Ok(())
}

//async fn setup_shutdown_handler() -> Result<()> {
//    #[cfg(unix)]
//    {
//        let mut sigterm = signal::unix::signal(signal::unix::SignalKind::terminate())?;
//        let mut sigint = signal::unix::signal(signal::unix::SignalKind::interrupt())?;
//
//        tokio::select! {
//            _ = sigterm.recv() => info!("Received SIGTERM"),
//            _ = sigint.recv() => info!("Received SIGINT"),
//        }
//    }
//
//    #[cfg(not(unix))]
//    {
//        signal::ctrl_c().await?;
//        info!("Received Ctrl+C");
//    }
//
//    Ok(())
//}


#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive(tracing::Level::INFO.into()),
        )
        .init();

    info!("Starting Kaggle to S3 uploader");

    //let shutdown = setup_shutdown_handler();

    tokio::select! {
        result = run_workflow() => {
            match result {
                Ok(_) => {
                    info!("Workflow completed successfully");
                    Ok(())
                }
                Err(e) => {
                    error!("Workflow failed: {:?}", e);
                    Err(e)
                }
            }
        }
        //_ = shutdown => {
        //    warn!("Received shutdown signal, cleaning up...");
        //    Ok(())
        //}
    }
}
