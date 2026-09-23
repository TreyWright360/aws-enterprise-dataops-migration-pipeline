import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F
from pyspark.sql.window import Window

args = getResolvedOptions(sys.argv, ["JOB_NAME", "source_bucket", "table_path"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

SOURCE_BUCKET = args["source_bucket"]
TABLE_PATH = args["table_path"]  # e.g. "public/orders"


def run_scd2_transformation():
    """
    Builds a Slowly Changing Dimension Type 2 history for a DMS-migrated
    table from its raw S3 landing zone:

      - The full-load file(s) at s3://<bucket>/<table_path>/*.parquet
        have no Op column; every row is treated as an initial insert.
      - CDC file(s) at s3://<bucket>/<table_path>/YYYY/MM/DD/*.parquet
        carry an Op column (I/U/D). Delete rows have every non-key
        column set to null, matching how the DMS S3 target actually
        writes them.

    Each Insert/Update becomes one dimension version, ordered per
    primary key by dms_load_timestamp. A version's effective_end_date
    is the next version's effective_start_date, or the row's own
    delete timestamp if a later Delete closes it out, or null if it
    is still current. Delete events do not produce their own
    dimension row; they only close out the prior version.
    """
    print(f"Starting SCD2 transformation for s3://{SOURCE_BUCKET}/{TABLE_PATH}")

    full_load_path = f"s3://{SOURCE_BUCKET}/{TABLE_PATH}/*.parquet"
    cdc_path = f"s3://{SOURCE_BUCKET}/{TABLE_PATH}/*/*/*/*.parquet"

    full_load_df = (
        spark.read.parquet(full_load_path)
        .withColumn("Op", F.lit("I"))
    )

    try:
        cdc_df = spark.read.parquet(cdc_path)
    except Exception:
        cdc_df = None

    if cdc_df is not None and cdc_df.limit(1).count() > 0:
        combined_df = full_load_df.unionByName(cdc_df, allowMissingColumns=True)
    else:
        combined_df = full_load_df

    combined_df = combined_df.withColumn(
        "dms_load_timestamp", F.col("dms_load_timestamp").cast("timestamp")
    )

    versions_df = combined_df.filter(F.col("Op") != "D")
    deletes_df = (
        combined_df.filter(F.col("Op") == "D")
        .select(
            F.col("order_id").alias("del_order_id"),
            F.col("dms_load_timestamp").alias("delete_timestamp"),
        )
        .groupBy("del_order_id")
        .agg(F.min("delete_timestamp").alias("delete_timestamp"))
    )

    order_window = Window.partitionBy("order_id").orderBy("dms_load_timestamp")

    scd2_df = (
        versions_df.withColumn("effective_start_date", F.col("dms_load_timestamp"))
        .withColumn(
            "next_version_start",
            F.lead("dms_load_timestamp").over(order_window),
        )
        .withColumn("is_last_version", F.col("next_version_start").isNull())
        .join(
            deletes_df,
            (F.col("order_id") == F.col("del_order_id"))
            & F.col("is_last_version")
            & (F.col("delete_timestamp") > F.col("effective_start_date")),
            "left",
        )
        .withColumn(
            "effective_end_date",
            F.coalesce(F.col("next_version_start"), F.col("delete_timestamp")),
        )
        .withColumn(
            "is_current",
            F.col("is_last_version") & F.col("delete_timestamp").isNull(),
        )
        .select(
            "order_id",
            "customer_name",
            "product",
            "quantity",
            "order_total",
            "created_at",
            "effective_start_date",
            "effective_end_date",
            "is_current",
        )
        .orderBy("order_id", "effective_start_date")
    )

    row_count = scd2_df.count()
    current_count = scd2_df.filter(F.col("is_current")).count()
    print(f"SCD2 rows produced: {row_count}, currently active: {current_count}")

    output_path = f"s3://{SOURCE_BUCKET}/curated/orders_scd2/"
    scd2_df.write.mode("overwrite").parquet(output_path)
    print(f"Wrote SCD2 output to {output_path}")
    print("SCD2 Transformation Completed successfully.")


run_scd2_transformation()
job.commit()
