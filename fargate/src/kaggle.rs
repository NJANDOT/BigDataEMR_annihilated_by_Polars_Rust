//! Kaggle dataset download and extraction module.

use anyhow::{bail, Context, Result};
use futures::StreamExt;
use reqwest::Client;
use std::path::{Path, PathBuf};
use tokio::fs::File;
use tokio::io::AsyncWriteExt;
use tracing::{debug, info};
use crate::credentials::KaggleCredentials;

pub async fn download_kaggle_dataset(
    credentials: &KaggleCredentials,
    dataset_url: &str,
    output_dir: &Path,
) -> Result<PathBuf> {
    let parts: Vec<&str> = dataset_url.split('/').collect();
    if parts.len() < 2 {
        bail!("Invalid Kaggle dataset URL format");
    }
    let owner = parts[parts.len() - 2];
    let dataset_slug = parts[parts.len() - 1];

    let api_url = format!(
        "https://www.kaggle.com/api/v1/datasets/download/{}/{}",
        owner, dataset_slug
    );

    debug!("Kaggle API URL: {}", api_url);

    let client = Client::builder()
        .build()
        .context("Failed to create HTTP client")?;

    let response = client
        .get(&api_url)
        .basic_auth(&credentials.username, Some(&credentials.key))
        .send()
        .await
        .context("Failed to send download request")?
        .error_for_status()
        .context("Kaggle API returned error status")?;

    let total_size = response.content_length().unwrap_or(0);
    info!("Starting download of {} bytes", total_size);

    let archive_path = output_dir.join("dataset.zip");
    let mut file = File::create(&archive_path)
        .await
        .context("Failed to create archive file")?;

    let mut stream = response.bytes_stream();

    while let Some(chunk_result) = stream.next().await {
        let chunk = chunk_result.context("Failed to read chunk")?;
        file.write_all(&chunk)
            .await
            .context("Failed to write chunk")?;
    }

    file.flush().await.context("Failed to flush archive file")?;

    info!("Download complete");

    let extract_dir = output_dir.join("extracted");
    std::fs::create_dir_all(&extract_dir).context("Failed to create extraction directory")?;

    debug!("Extracting archive to {:?}", extract_dir);
    extract_zip(&archive_path, &extract_dir).context("Failed to extract archive")?;

    info!("Extraction complete");

    std::fs::remove_file(&archive_path).context("Failed to remove archive file")?;

    Ok(extract_dir)
}

fn extract_zip(archive_path: &Path, target_dir: &Path) -> Result<()> {
    let file = std::fs::File::open(archive_path).context("Failed to open archive file")?;

    let mut archive = zip::ZipArchive::new(file).context("Failed to read ZIP archive")?;

    for i in 0..archive.len() {
        let mut file = archive
            .by_index(i)
            .context("Failed to read archive entry")?;

        let outpath = match file.enclosed_name() {
            Some(path) => target_dir.join(path),
            None => continue,
        };

        if file.is_dir() {
            std::fs::create_dir_all(&outpath).context("Failed to create directory")?;
        } else {
            if let Some(parent) = outpath.parent() {
                std::fs::create_dir_all(parent).context("Failed to create parent directory")?;
            }
            let mut outfile =
                std::fs::File::create(&outpath).context("Failed to create output file")?;
            std::io::copy(&mut file, &mut outfile).context("Failed to extract file")?;
        }
    }

    Ok(())
}
