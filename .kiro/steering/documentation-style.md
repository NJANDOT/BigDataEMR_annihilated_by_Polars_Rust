---
inclusion: auto
---

# Documentation Style Guidelines

## Code Comments Policy

**Keep documentation minimal and pragmatic.**

### Rules

1. **Module-level comments**: One line at the top of each file explaining what the module does
2. **Function comments**: Optional - only if the function's purpose isn't obvious from its name and signature
3. **Inline comments**: Only for complex logic that needs explanation
4. **No verbose documentation**: Avoid multi-paragraph explanations, argument lists, or error catalogs

### Examples

#### ✅ Good (Minimal)

```rust
// Handles Kaggle dataset download and extraction

use anyhow::Result;

pub async fn download_kaggle_dataset(...) -> Result<PathBuf> {
    // Implementation
}
```

#### ❌ Bad (Too Verbose)

```rust
/// Module for downloading and extracting Kaggle datasets.
///
/// This module provides functionality to authenticate with the Kaggle API,
/// download datasets, extract ZIP archives, and handle errors gracefully.
///
/// # Examples
/// ...

/// Downloads a Kaggle dataset and extracts it to the output directory.
///
/// # Arguments
///
/// * `credentials` - Kaggle API credentials
/// * `dataset_url` - URL of the dataset
/// * `output_dir` - Directory for extraction
///
/// # Returns
///
/// Returns the path to the extraction directory on success
///
/// # Errors
///
/// This function will return an error if:
/// - Network connection fails
/// - Authentication fails
/// - ZIP extraction fails
pub async fn download_kaggle_dataset(...) -> Result<PathBuf> {
    // Implementation
}
```

### Rationale

- Rust's type system and naming conventions make code self-documenting
- Over-documentation clutters the codebase and becomes outdated
- Focus on writing clear, readable code rather than extensive comments
- Use README files for high-level architecture and usage documentation

### When to Add More Documentation

- Public APIs intended for external use
- Complex algorithms that aren't immediately obvious
- Non-standard patterns or workarounds
- Security-critical code sections

## Apply This Standard

This guideline applies to all code written in this workspace unless explicitly overridden in project requirements.
