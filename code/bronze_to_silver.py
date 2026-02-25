import polars as pl

lazy_df = pl.scan_ndjson("s3://sparkresultsjjjmain/the-pile/bronze/00.jsonl")

transformed_df = lazy_df.select(
    pl.col("text"),
    pl.col("meta").struct.field("pile_set_name").alias("pile_set_name")
)

transformed_df.sink_parquet("s3://sparkresultsjjjmain/silver/00.parquet")