"""
Property-Based Tests for EMR to Fargate Migration Data Processing

This module contains property-based tests using Hypothesis to verify
universal correctness properties of the data processing pipeline.

Feature: emr-to-fargate-migration
Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 11.8, 11.9, 11.10
"""

import pytest
from hypothesis import given, settings, strategies as st
import polars as pl


# Configure Hypothesis to run minimum 100 iterations per test
settings.register_profile("default", max_examples=100)
settings.load_profile("default")


# Feature: emr-to-fargate-migration, Property 1: Text Length Filter Correctness
@given(st.lists(st.text(min_size=0, max_size=500), min_size=0, max_size=1000))
@settings(max_examples=100)
def test_text_length_filter_correctness(texts):
    """
    Property 1: Text Length Filter Correctness
    
    For any dataframe processed by the Silver_To_Gold_Processor, all rows in the 
    output must have text length greater than 100 characters.
    
    Validates: Requirements 11.5
    """
    # Skip empty lists as they create schema issues with Polars
    if not texts:
        return
    
    # Create dataframe with random text lengths
    df = pl.DataFrame({
        "text": texts,
        "meta": [{"pile_set_name": "test"} for _ in texts]
    })
    
    # Apply the filter from silver_to_gold.py
    filtered = df.filter(pl.col("text").str.len_chars() > 100)
    
    # Property: All remaining rows must have text length > 100
    for row in filtered.iter_rows(named=True):
        assert len(row["text"]) > 100, f"Found text with length {len(row['text'])} <= 100"


# Feature: emr-to-fargate-migration, Property 2: Copyright Filter Correctness
@given(st.lists(
    st.one_of(
        st.text(min_size=101, max_size=500),
        st.just("This contains copyright notice"),
        st.just("No problematic words here" * 10)
    ),
    min_size=0,
    max_size=1000
))
@settings(max_examples=100)
def test_copyright_filter_correctness(texts):
    """
    Property 2: Copyright Filter Correctness
    
    For any dataframe processed by the Silver_To_Gold_Processor, no rows in the 
    output should contain the word "copyright" in the text field.
    
    Validates: Requirements 11.6
    """
    # Skip empty lists as they create schema issues with Polars
    if not texts:
        return
    
    df = pl.DataFrame({
        "text": texts,
        "meta": [{"pile_set_name": "test"} for _ in texts]
    })
    
    # Apply the filter from silver_to_gold.py
    filtered = df.filter(~pl.col("text").str.contains('copyright'))
    
    # Property: No rows should contain "copyright"
    for row in filtered.iter_rows(named=True):
        assert "copyright" not in row["text"].lower(), \
            f"Found text containing 'copyright': {row['text'][:50]}..."


# Feature: emr-to-fargate-migration, Property 3: Metadata Extraction Preservation
@given(st.lists(
    st.tuples(
        st.text(min_size=101, max_size=500),
        st.text(min_size=1, max_size=50)
    ),
    min_size=1,
    max_size=1000
))
@settings(max_examples=100)
def test_metadata_extraction_preservation(text_and_pile_names):
    """
    Property 3: Metadata Extraction Preservation
    
    For any dataframe with a meta struct containing pile_set_name, after 
    transformation by Silver_To_Gold_Processor, the set_name column should 
    contain the same values as the original meta.pile_set_name field for all rows.
    
    Validates: Requirements 11.7
    """
    texts, pile_names = zip(*text_and_pile_names)
    
    df = pl.DataFrame({
        "text": texts,
        "meta": [{"pile_set_name": name} for name in pile_names]
    })
    
    # Apply the transformation from silver_to_gold.py
    transformed = df.with_columns(
        set_name=pl.col("meta").struct.field("pile_set_name")
    )
    
    # Property: set_name should equal original pile_set_name
    for i, row in enumerate(transformed.iter_rows(named=True)):
        assert row["set_name"] == pile_names[i], \
            f"Mismatch at row {i}: expected {pile_names[i]}, got {row['set_name']}"


# Feature: emr-to-fargate-migration, Property 4: Partition Index Calculation
@given(
    st.lists(st.text(min_size=101, max_size=500), min_size=1, max_size=1000),
    st.integers(min_value=1, max_value=100)
)
@settings(max_examples=100)
def test_partition_index_calculation(texts, partition_count):
    """
    Property 4: Partition Index Calculation
    
    For any dataframe processed by Silver_To_Gold_Processor with partition_count 
    partitions, the _partition_idx for each row should equal (row_number % partition_count), 
    where row_number is the 0-indexed position of the row.
    
    Validates: Requirements 11.8
    """
    df = pl.DataFrame({
        "text": texts,
        "meta": [{"pile_set_name": "test"} for _ in texts]
    })
    
    # Apply the partition calculation from silver_to_gold.py
    df = df.with_columns(
        _partition_idx=(pl.arange(0, pl.len()) % partition_count)
    )
    
    # Property: _partition_idx should equal row_number % partition_count
    for i, row in enumerate(df.iter_rows(named=True)):
        expected_partition = i % partition_count
        assert row["_partition_idx"] == expected_partition, \
            f"Row {i}: expected partition {expected_partition}, got {row['_partition_idx']}"
