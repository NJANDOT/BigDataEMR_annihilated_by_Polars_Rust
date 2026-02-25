import polars as pl
import consts_proj
import consts_proj

lazy_df = pl.scan_ndjson(
    consts_proj.BUCKET_BRONZE_TGT,
    schema={
        "text" : pl.String(), 
        "meta" : pl.Struct({"pile_set_name": pl.String()}) 
    }
)

lazy_df.sink_parquet(consts_proj.BUCKET_SILVER_TGT)