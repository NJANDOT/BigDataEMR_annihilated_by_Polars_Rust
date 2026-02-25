from pyspark.sql import SparkSession, DataFrame
import os

from pyspark.sql.functions import col, length
from pyspark.sql.types import StructType, StructField, StringType, LongType



def transform_df(df: DataFrame) -> DataFrame:
    df = df.filter(length(col("text")) > 100)\
       .where(~col('text').contains('copyright'))\
       .withColumn('set_name', col("meta.pile_set_name"))\
       .drop('meta')
    return df

if __name__ == "__main__":
    spark = SparkSession.builder \
        .appName("EMR_spark") \
        .getOrCreate()

    spark.sparkContext.setLogLevel("WARN")

    df = spark.read.parquet("s3://sparkresultsjjjmain/silver/00.parquet")

    df = transform_df(df)

    df.write \
    .partitionBy("set_name") \
    .mode("overwrite") \
    .option("compression", "snappy") \
    .parquet("s3://sparkresultsjjjmain/gold/")

    spark.stop()




