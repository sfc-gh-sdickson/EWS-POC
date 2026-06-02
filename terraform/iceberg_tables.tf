# =============================================================================
# Bronze Iceberg Tables
# NOTE: Snowflake Terraform provider may not yet support Iceberg DDL natively.
# Using snowflake_unsafe_execute to run CREATE ICEBERG TABLE statements.
# =============================================================================

resource "snowflake_unsafe_execute" "raw_transactions" {
  execute = <<-SQL
    CREATE OR REPLACE ICEBERG TABLE ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.RAW_TRANSACTIONS (
      txn_id STRING NOT NULL,
      member_id STRING NOT NULL,
      institution_id STRING NOT NULL,
      txn_timestamp TIMESTAMP_LTZ NOT NULL,
      amount NUMBER(15,2) NOT NULL,
      currency_code STRING,
      txn_type STRING,
      channel STRING,
      merchant_category STRING,
      merchant_name STRING,
      status STRING,
      risk_score NUMBER(5,2),
      _loaded_at TIMESTAMP_LTZ,
      _source_file STRING
    )
      CATALOG = 'SNOWFLAKE'
      EXTERNAL_VOLUME = 'ews_iceberg_vol'
      BASE_LOCATION = 'bronze/raw_transactions/'
  SQL
  revert  = "DROP TABLE IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.RAW_TRANSACTIONS"

  depends_on = [snowflake_unsafe_execute.external_volume]
}

resource "snowflake_unsafe_execute" "raw_members" {
  execute = <<-SQL
    CREATE OR REPLACE ICEBERG TABLE ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.RAW_MEMBERS (
      member_id STRING NOT NULL,
      institution_id STRING NOT NULL,
      first_name STRING,
      last_name STRING,
      date_of_birth DATE,
      email STRING,
      phone STRING,
      city STRING,
      state_code STRING,
      zip_code STRING,
      country_code STRING,
      member_since DATE,
      status STRING,
      risk_tier STRING,
      kyc_verified BOOLEAN,
      _loaded_at TIMESTAMP_LTZ,
      _source_file STRING
    )
      CATALOG = 'SNOWFLAKE'
      EXTERNAL_VOLUME = 'ews_iceberg_vol'
      BASE_LOCATION = 'bronze/raw_members/'
  SQL
  revert  = "DROP TABLE IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.RAW_MEMBERS"

  depends_on = [snowflake_unsafe_execute.external_volume]
}

resource "snowflake_unsafe_execute" "raw_alerts" {
  execute = <<-SQL
    CREATE OR REPLACE ICEBERG TABLE ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.RAW_ALERTS (
      alert_id STRING NOT NULL,
      member_id STRING NOT NULL,
      institution_id STRING NOT NULL,
      alert_timestamp TIMESTAMP_LTZ NOT NULL,
      alert_type STRING,
      severity STRING,
      alert_source STRING,
      description STRING,
      related_txn_id STRING,
      confidence_score NUMBER(5,4),
      status STRING,
      assigned_to STRING,
      resolved_at TIMESTAMP_LTZ,
      _loaded_at TIMESTAMP_LTZ,
      _source_file STRING
    )
      CATALOG = 'SNOWFLAKE'
      EXTERNAL_VOLUME = 'ews_iceberg_vol'
      BASE_LOCATION = 'bronze/raw_alerts/'
  SQL
  revert  = "DROP TABLE IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.RAW_ALERTS"

  depends_on = [snowflake_unsafe_execute.external_volume]
}

resource "snowflake_unsafe_execute" "raw_institutions" {
  execute = <<-SQL
    CREATE OR REPLACE ICEBERG TABLE ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.RAW_INSTITUTIONS (
      institution_id STRING NOT NULL,
      institution_name STRING NOT NULL,
      institution_type STRING,
      routing_number STRING,
      region STRING,
      asset_size_tier STRING,
      ews_member_since DATE,
      status STRING,
      _loaded_at TIMESTAMP_LTZ
    )
      CATALOG = 'SNOWFLAKE'
      EXTERNAL_VOLUME = 'ews_iceberg_vol'
      BASE_LOCATION = 'bronze/raw_institutions/'
  SQL
  revert  = "DROP TABLE IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.RAW_INSTITUTIONS"

  depends_on = [snowflake_unsafe_execute.external_volume]
}

resource "snowflake_unsafe_execute" "streaming_events" {
  execute = <<-SQL
    CREATE OR REPLACE ICEBERG TABLE ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.STREAMING_EVENTS (
      event_id STRING NOT NULL,
      event_time TIMESTAMP_LTZ NOT NULL,
      event_type STRING NOT NULL,
      member_id STRING NOT NULL,
      institution_id STRING,
      payload STRING,
      amount NUMBER(15,2),
      channel STRING,
      device_id STRING,
      ip_address STRING,
      geo_lat NUMBER(10,7),
      geo_lon NUMBER(10,7),
      risk_score NUMBER(5,2),
      _ingest_time TIMESTAMP_LTZ,
      _channel_name STRING
    )
      CATALOG = 'SNOWFLAKE'
      EXTERNAL_VOLUME = 'ews_iceberg_vol'
      BASE_LOCATION = 'bronze/streaming_events/'
  SQL
  revert  = "DROP TABLE IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.STREAMING_EVENTS"

  depends_on = [snowflake_unsafe_execute.external_volume]
}
