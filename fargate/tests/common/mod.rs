// Common test utilities and mocks for integration tests

#[cfg(test)]
pub mod mocks {
    use mockall::mock;

    // Mock trait for SSM operations
    // This allows us to test credential retrieval without actual AWS calls
    mock! {
        pub SsmClient {
            pub async fn get_parameter(
                &self,
                name: &str,
                with_decryption: bool,
            ) -> Result<String, String>;
        }
    }

    // Mock trait for S3 operations
    // This allows us to test uploads without actual S3 calls
    mock! {
        pub S3Client {
            pub async fn put_object(
                &self,
                bucket: &str,
                key: &str,
                body: Vec<u8>,
            ) -> Result<(), String>;

            pub async fn upload_part(
                &self,
                bucket: &str,
                key: &str,
                upload_id: &str,
                part_number: i32,
                body: Vec<u8>,
            ) -> Result<String, String>;
        }
    }
}

#[cfg(test)]
pub mod fixtures {
    use std::path::PathBuf;
    use tempfile::TempDir;

    /// Creates a temporary directory with a test file structure
    pub fn create_test_directory_with_file(filename: &str, depth: usize) -> (TempDir, PathBuf) {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let mut current_path = temp_dir.path().to_path_buf();

        // Create nested directories
        for i in 0..depth {
            current_path.push(format!("dir_{}", i));
            std::fs::create_dir(&current_path).expect("Failed to create directory");
        }

        // Create the target file
        let file_path = current_path.join(filename);
        std::fs::write(&file_path, b"test content").expect("Failed to write test file");

        (temp_dir, file_path)
    }

    /// Creates a temporary directory without the target file
    pub fn create_test_directory_without_file() -> TempDir {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");

        // Create some dummy files
        std::fs::write(temp_dir.path().join("other.txt"), b"content")
            .expect("Failed to write dummy file");
        std::fs::write(temp_dir.path().join("another.json"), b"{}")
            .expect("Failed to write dummy file");

        temp_dir
    }
}

#[cfg(test)]
pub mod http_mocks {
    use wiremock::matchers::{header_exists, method, path};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    /// Creates a mock Kaggle API server that returns a ZIP file
    pub async fn setup_kaggle_mock_server() -> MockServer {
        let mock_server = MockServer::start().await;

        // Mock the Kaggle API download endpoint
        // Returns a small ZIP file for testing
        let zip_data = create_test_zip();

        Mock::given(method("GET"))
            .and(path(
                "/api/v1/datasets/download/dschettler8845/the-pile-dataset-part-00-of-29",
            ))
            .and(header_exists("authorization"))
            .respond_with(
                ResponseTemplate::new(200)
                    .set_body_bytes(zip_data)
                    .insert_header("content-type", "application/zip"),
            )
            .mount(&mock_server)
            .await;

        mock_server
    }

    /// Creates a mock Kaggle API server that returns an error
    pub async fn setup_kaggle_error_server() -> MockServer {
        let mock_server = MockServer::start().await;

        Mock::given(method("GET"))
            .and(path(
                "/api/v1/datasets/download/dschettler8845/the-pile-dataset-part-00-of-29",
            ))
            .respond_with(ResponseTemplate::new(401).set_body_string("Unauthorized"))
            .mount(&mock_server)
            .await;

        mock_server
    }

    /// Creates a minimal test ZIP file containing 00.jsonl
    fn create_test_zip() -> Vec<u8> {
        use std::io::Write;
        use zip::write::{FileOptions, ZipWriter};

        let mut buffer = Vec::new();
        {
            let mut zip = ZipWriter::new(std::io::Cursor::new(&mut buffer));
            let options = FileOptions::default().compression_method(zip::CompressionMethod::Stored);

            // Add 00.jsonl to the ZIP
            zip.start_file("00.jsonl", options)
                .expect("Failed to start file in ZIP");
            zip.write_all(b"{\"text\": \"test data\"}\n")
                .expect("Failed to write to ZIP");

            zip.finish().expect("Failed to finish ZIP");
        }

        buffer
    }
}
