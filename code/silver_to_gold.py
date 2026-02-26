import polars as pl
import numpy as np
import s3fs
import consts_proj

def transform_df(df: pl.DataFrame) -> pl.DataFrame:
    df = df.filter((pl.col("text").str.len_chars() > 100) & (~pl.col("text").str.contains('copyright')))\
        .with_columns(set_name = pl.col("meta").struct.field("pile_set_name"))
    df = df.drop('meta')
    return df


if __name__ == "__main__":
    fs = s3fs.S3FileSystem()

    if fs.exists(consts_proj.BUCKET_GOLD_TGT):
        fs.rm(consts_proj.BUCKET_GOLD_TGT, recursive=True)

    df = pl.read_parquet(consts_proj.BUCKET_SILVER_TGT)
    df = transform_df(df)

    taille_totale_mb = df.estimated_size("mb")

    # 500 Mo en RAM = ~128Mo en disque
    nb_partitions = max(1, int(taille_totale_mb / 500))

    df = df.with_columns(
        _partition_idx = (pl.arange(0, pl.count()) % nb_partitions)
    )

    df.write_parquet(
        consts_proj.BUCKET_GOLD_TGT,
        use_pyarrow=True,
        pyarrow_options={
            "partition_cols": ["_partition_idx"],
            "compression": "snappy",
        }
    )