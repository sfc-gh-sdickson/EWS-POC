# =============================================================================
# Dynamic Tables (Silver, Gold, Feature Store)
# Using snowflake_unsafe_execute since DT resources may have limited provider support
# =============================================================================

# --- SILVER ZONE ---

resource "snowflake_unsafe_execute" "dt_cleansed_transactions" {
  execute = <<-SQL
    CREATE OR REPLACE DYNAMIC TABLE ${snowflake_database.ews_poc.name}.${snowflake_schema.silver.name}.CLEANSED_TRANSACTIONS
      TARGET_LAG = '5 minutes'
      WAREHOUSE = ${snowflake_warehouse.transform.name}
      REFRESH_MODE = FULL
    AS
      SELECT txn_id, TRIM(UPPER(member_id)) AS member_id, TRIM(UPPER(institution_id)) AS institution_id,
        txn_timestamp, amount, COALESCE(currency_code, 'USD') AS currency_code, UPPER(txn_type) AS txn_type,
        UPPER(channel) AS channel, merchant_category, merchant_name, UPPER(status) AS status,
        COALESCE(risk_score, 0.0) AS risk_score, _loaded_at, _source_file
      FROM ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.RAW_TRANSACTIONS
      WHERE txn_id IS NOT NULL AND member_id IS NOT NULL AND amount IS NOT NULL
  SQL
  revert  = "DROP DYNAMIC TABLE IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.silver.name}.CLEANSED_TRANSACTIONS"

  depends_on = [snowflake_unsafe_execute.raw_transactions]
}

resource "snowflake_unsafe_execute" "dt_enriched_members" {
  execute = <<-SQL
    CREATE OR REPLACE DYNAMIC TABLE ${snowflake_database.ews_poc.name}.${snowflake_schema.silver.name}.ENRICHED_MEMBERS
      TARGET_LAG = '5 minutes'
      WAREHOUSE = ${snowflake_warehouse.transform.name}
      REFRESH_MODE = FULL
    AS
      SELECT member_id, UPPER(institution_id) AS institution_id, INITCAP(first_name) AS first_name,
        INITCAP(last_name) AS last_name, date_of_birth, LOWER(email) AS email, phone,
        INITCAP(city) AS city, UPPER(state_code) AS state_code, zip_code,
        UPPER(COALESCE(country_code, 'US')) AS country_code, member_since,
        UPPER(status) AS status, UPPER(risk_tier) AS risk_tier,
        COALESCE(kyc_verified, FALSE) AS kyc_verified, _loaded_at
      FROM ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.RAW_MEMBERS
      WHERE member_id IS NOT NULL AND institution_id IS NOT NULL
  SQL
  revert  = "DROP DYNAMIC TABLE IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.silver.name}.ENRICHED_MEMBERS"

  depends_on = [snowflake_unsafe_execute.raw_members]
}

resource "snowflake_unsafe_execute" "dt_dedup_events" {
  execute = <<-SQL
    CREATE OR REPLACE DYNAMIC TABLE ${snowflake_database.ews_poc.name}.${snowflake_schema.silver.name}.DEDUP_EVENTS
      TARGET_LAG = '5 minutes'
      WAREHOUSE = ${snowflake_warehouse.transform.name}
      REFRESH_MODE = FULL
    AS
      SELECT event_id, event_time, UPPER(event_type) AS event_type, UPPER(member_id) AS member_id,
        UPPER(institution_id) AS institution_id, payload, amount, UPPER(channel) AS channel,
        device_id, ip_address, geo_lat, geo_lon, COALESCE(risk_score, 0.0) AS risk_score, _ingest_time
      FROM ${snowflake_database.ews_poc.name}.${snowflake_schema.bronze.name}.STREAMING_EVENTS
      WHERE event_id IS NOT NULL AND member_id IS NOT NULL
  SQL
  revert  = "DROP DYNAMIC TABLE IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.silver.name}.DEDUP_EVENTS"

  depends_on = [snowflake_unsafe_execute.streaming_events]
}

# --- GOLD ZONE ---

resource "snowflake_unsafe_execute" "dt_daily_member_summary" {
  execute = <<-SQL
    CREATE OR REPLACE DYNAMIC TABLE ${snowflake_database.ews_poc.name}.${snowflake_schema.gold.name}.DAILY_MEMBER_SUMMARY
      TARGET_LAG = '10 minutes'
      WAREHOUSE = ${snowflake_warehouse.transform.name}
      REFRESH_MODE = FULL
    AS
      SELECT member_id, institution_id, txn_timestamp::DATE AS txn_date,
        COUNT(*) AS txn_count, SUM(amount) AS total_amount, AVG(amount) AS avg_amount,
        MAX(amount) AS max_amount, COUNT(DISTINCT channel) AS unique_channels,
        MAX(risk_score) AS max_risk_score, AVG(risk_score) AS avg_risk_score
      FROM ${snowflake_database.ews_poc.name}.${snowflake_schema.silver.name}.CLEANSED_TRANSACTIONS
      GROUP BY member_id, institution_id, txn_timestamp::DATE
  SQL
  revert  = "DROP DYNAMIC TABLE IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.gold.name}.DAILY_MEMBER_SUMMARY"

  depends_on = [snowflake_unsafe_execute.dt_cleansed_transactions]
}

resource "snowflake_unsafe_execute" "dt_fraud_signals" {
  execute = <<-SQL
    CREATE OR REPLACE DYNAMIC TABLE ${snowflake_database.ews_poc.name}.${snowflake_schema.gold.name}.FRAUD_SIGNALS
      TARGET_LAG = '5 minutes'
      WAREHOUSE = ${snowflake_warehouse.transform.name}
      REFRESH_MODE = FULL
    AS
      SELECT alert_id AS signal_id, member_id, institution_id, alert_timestamp AS signal_time,
        'ALERT' AS signal_source, alert_type, severity, confidence_score AS alert_confidence,
        NULL AS event_risk_score, NULL AS event_amount, status AS alert_status
      FROM ${snowflake_database.ews_poc.name}.${snowflake_schema.silver.name}.ENRICHED_ALERTS
      WHERE severity IN ('HIGH', 'CRITICAL')
      UNION ALL
      SELECT event_id, member_id, institution_id, event_time, 'HIGH_RISK_EVENT',
        event_type, CASE WHEN risk_score > 0.9 THEN 'CRITICAL' ELSE 'HIGH' END,
        NULL, risk_score, amount, NULL
      FROM ${snowflake_database.ews_poc.name}.${snowflake_schema.silver.name}.DEDUP_EVENTS
      WHERE risk_score > 0.75
  SQL
  revert  = "DROP DYNAMIC TABLE IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.gold.name}.FRAUD_SIGNALS"

  depends_on = [snowflake_unsafe_execute.dt_dedup_events]
}

# --- FEATURE STORE ---

resource "snowflake_unsafe_execute" "dt_online_features" {
  execute = <<-SQL
    CREATE OR REPLACE DYNAMIC TABLE ${snowflake_database.ews_poc.name}.${snowflake_schema.feature_store.name}.ONLINE_MEMBER_FEATURES
      TARGET_LAG = '5 minutes'
      WAREHOUSE = ${snowflake_warehouse.transform.name}
      REFRESH_MODE = FULL
    AS
      SELECT member_id, COUNT(*) AS event_count_24h,
        COUNT(DISTINCT channel) AS unique_channels_24h,
        COUNT(DISTINCT ip_address) AS unique_ips_24h,
        SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS total_spend_24h,
        AVG(amount) AS avg_amount_24h, MAX(risk_score) AS max_risk_score_24h,
        MAX(event_time) AS last_activity_time, CURRENT_TIMESTAMP() AS feature_computed_at
      FROM ${snowflake_database.ews_poc.name}.${snowflake_schema.silver.name}.DEDUP_EVENTS
      WHERE event_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
      GROUP BY member_id
  SQL
  revert  = "DROP DYNAMIC TABLE IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.feature_store.name}.ONLINE_MEMBER_FEATURES"

  depends_on = [snowflake_unsafe_execute.dt_dedup_events]
}
