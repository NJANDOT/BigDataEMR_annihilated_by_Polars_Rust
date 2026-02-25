// Amazon S3 file upload module.

use anyhow::{Context, Result};
use aws_sdk_s3::primitives::ByteStream;
use aws_sdk_s3::Client as S3Client;
use std::path::Path;
use tracing::info;
use aws_sdk_s3::types::{CompletedMultipartUpload, CompletedPart};
use tokio::io::AsyncReadExt;



async fn upload_simple(s3_client: &S3Client, file_path: &Path, bucket: &str, key: &str,) -> Result<()> 
{

    let body = ByteStream::from_path(file_path)
        .await
        .context("Failed to create ByteStream from file")?;

    s3_client
        .put_object()
        .bucket(bucket)
        .key(key)
        .body(body)
        .send()
        .await
        .context("Failed to upload file to S3")?;


    Ok(())
}

async fn upload_multipart(s3_client: &S3Client, file_path: &Path, bucket: &str, key: &str, ) -> Result<()> 
{


    let multipart_upload = s3_client
        .create_multipart_upload()
        .bucket(bucket)
        .key(key)
        .send()
        .await
        .context("Failed to initiate multipart upload")?;

    let upload_id = multipart_upload.upload_id().context("Missing upload ID")?;

    let mut file = tokio::fs::File::open(file_path)
        .await
        .context("Failed to open file")?;

    let mut part_number = 1;
    let mut completed_parts = Vec::new();
    let chunk_size = 10 * 1024 * 1024; 

    loop {
        let mut buffer = vec![0u8; chunk_size];
        let bytes_read = file
            .read(&mut buffer)
            .await
            .context("Failed to read file chunk")?;

        if bytes_read == 0 {
            break;
        }

        buffer.truncate(bytes_read);

        let upload_part_result = s3_client
            .upload_part()
            .bucket(bucket)
            .key(key)
            .upload_id(upload_id)
            .part_number(part_number)
            .body(ByteStream::from(buffer))
            .send()
            .await
            .context("Failed to upload part")?;

        completed_parts.push(
            CompletedPart::builder()
                .part_number(part_number)
                .e_tag(upload_part_result.e_tag().unwrap_or_default())
                .build(),
        );

        part_number += 1;
    }

    let completed_upload = CompletedMultipartUpload::builder()
        .set_parts(Some(completed_parts))
        .build();

    s3_client
        .complete_multipart_upload()
        .bucket(bucket)
        .key(key)
        .upload_id(upload_id)
        .multipart_upload(completed_upload)
        .send()
        .await
        .context("Failed to complete multipart upload")?;

    Ok(())
}

pub async fn upload_file_to_s3(s3_client: &S3Client, file_path: &Path, bucket: &str, key: &str,) -> Result<()> 
{
    let metadata = tokio::fs::metadata(file_path)
        .await
        .context("Failed to get file metadata")?;
    let file_size = metadata.len();

    info!(
        "Uploading file of {} bytes to s3://{}/{}",
        file_size, bucket, key
    );

    if file_size < 100 * 1024 * 1024 {
        upload_simple(s3_client, file_path, bucket, key).await?;
    } else {
        upload_multipart(s3_client, file_path, bucket, key).await?;
    }

    info!("Successfully uploaded to s3://{}/{}", bucket, key);

    Ok(())
}