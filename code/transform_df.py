from pyspark.sql import DataFrame
from pyspark.sql.functions import col, length, instr, when
from pyspark.sql import functions as F

def transform_df(df: DataFrame) -> DataFrame:
    df = df.filter(length(col("text")) > 100)\
      .where(~F.col('text').contains('copyright'))\
      .withColumn('set_name', col("meta.pile_set_name"))\
      .drop('meta')
    return df

