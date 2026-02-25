//! Recursive file search module.

use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
use tracing::debug;
use walkdir::WalkDir;

pub fn find_file_recursive(root_dir: &Path, target_filename: &str) -> Result<PathBuf> {
    debug!("Searching for file '{}' in {:?}", target_filename, root_dir);

    for entry in WalkDir::new(root_dir)
        .follow_links(false)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        if entry.file_type().is_file() {
            if let Some(filename) = entry.file_name().to_str() {
                if filename == target_filename {
                    let absolute_path = entry
                        .path()
                        .canonicalize()
                        .context("Failed to canonicalize path")?;
                    debug!("Found file at: {:?}", absolute_path);
                    return Ok(absolute_path);
                }
            }
        }
    }

    anyhow::bail!("File '{}' not found in {:?}", target_filename, root_dir)
}
