// Integration test to verify test infrastructure is working correctly
// This file validates that proptest, mockall, and wiremock are properly configured

mod common;

#[cfg(test)]
mod infrastructure_tests {
    use crate::common::fixtures;
    use crate::common::http_mocks;
    use proptest::prelude::*;

    /// Basic test to verify proptest is working
    /// This should run at least 100 times as configured in proptest.toml
    #[test]
    fn proptest_infrastructure_works() {
        proptest!(|(x in 0..100u32)| {
            // Simple property: x should always be less than 100
            prop_assert!(x < 100);
        });
    }

    /// Test that our test fixtures can create directories with files
    #[test]
    fn test_fixture_creates_file_at_depth() {
        let (temp_dir, file_path) = fixtures::create_test_directory_with_file("test.txt", 3);

        // Verify the file exists
        assert!(file_path.exists(), "File should exist at created path");

        // Verify it's inside the temp directory
        assert!(
            file_path.starts_with(temp_dir.path()),
            "File should be in temp directory"
        );

        // Verify we can read the content
        let content = std::fs::read_to_string(&file_path).expect("Should read file");
        assert_eq!(content, "test content");
    }

    /// Test that our test fixtures can create directories without target files
    #[test]
    fn test_fixture_creates_directory_without_target() {
        let temp_dir = fixtures::create_test_directory_without_file();

        // Verify the directory exists
        assert!(temp_dir.path().exists(), "Temp directory should exist");

        // Verify some files exist but not our target
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path())
            .expect("Should read directory")
            .collect();

        assert!(!entries.is_empty(), "Directory should contain some files");
    }

    /// Test that wiremock can create a mock HTTP server
    #[tokio::test]
    async fn wiremock_infrastructure_works() {
        let mock_server = http_mocks::setup_kaggle_mock_server().await;

        // Verify we can make a request to the mock server
        let client = reqwest::Client::new();
        let response = client
            .get(format!(
                "{}/api/v1/datasets/download/dschettler8845/the-pile-dataset-part-00-of-29",
                mock_server.uri()
            ))
            .header("authorization", "Basic test")
            .send()
            .await
            .expect("Should send request");

        assert_eq!(response.status(), 200, "Mock server should return 200");

        let content_type = response
            .headers()
            .get("content-type")
            .expect("Should have content-type header");

        assert_eq!(
            content_type, "application/zip",
            "Should return ZIP content type"
        );
    }

    /// Test that wiremock can simulate errors
    #[tokio::test]
    async fn wiremock_can_simulate_errors() {
        let mock_server = http_mocks::setup_kaggle_error_server().await;

        let client = reqwest::Client::new();
        let response = client
            .get(format!(
                "{}/api/v1/datasets/download/dschettler8845/the-pile-dataset-part-00-of-29",
                mock_server.uri()
            ))
            .send()
            .await
            .expect("Should send request");

        assert_eq!(response.status(), 401, "Mock server should return 401");
    }

    /// Property test to verify our test directory creation works at various depths
    #[test]
    fn prop_test_directory_creation_at_any_depth() {
        proptest!(|(depth in 0..10usize)| {
            let (temp_dir, file_path) = fixtures::create_test_directory_with_file("test.jsonl", depth);

            // Property: file should always exist
            prop_assert!(file_path.exists());

            // Property: file should be inside temp directory
            prop_assert!(file_path.starts_with(temp_dir.path()));

            // Property: file should have the correct name
            prop_assert_eq!(file_path.file_name().unwrap().to_str().unwrap(), "test.jsonl");
        });
    }
}
