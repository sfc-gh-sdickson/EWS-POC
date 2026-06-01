/*=============================================================================
  EWS POC - UC03 Step 1: Silver Zone Dynamic Tables
  
  PURPOSE: Declarative transformation from Bronze to Silver using Dynamic Tables.
  No orchestrator. No cron. No DAG definition. Snowflake infers and schedules.
  
  SNOWFLAKE ADVANTAGE: Dynamic Tables replace dbt + Airflow entirely.
  - Declarative: Define WHAT (SQL), not HOW (scheduling)
  - Auto-incremental: Only processes changed rows
  - Dependency-aware: Snowflake infers the DAG from SQL references
  - Snapshot-consistent: Downstream always sees coherent upstream state
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE WAREHOUSE ews_transform_wh;

-- =============================================================================
-- Silver: Cleansed Transactions (deduplicated, type-cast, validated)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE SILVER.CLEANSED_TRANSACTIONS
  TARGET_LAG = DOWNSTREAM
  WAREHOUSE = ews_transform_wh
  REFRESH_MODE = INCREMENTAL
AS
  SELECT
      txn_id,
      TRIM(UPPER(member_id)) AS member_id,
      TRIM(UPPER(institution_id)) AS institution_id,
      txn_timestamp,
      amount,
      UPPER(currency_code) AS currency_code,
      UPPER(txn_type) AS txn_type,
      UPPER(channel) AS channel,
      TRIM(merchant_category) AS merchant_category,
      TRIM(merchant_name) AS merchant_name,
      UPPER(merchant_country) AS merchant_country,
      UPPER(status) AS status,
      auth_code,
      card_last_four,
      ip_address,
      device_fingerprint,
      COALESCE(risk_score, 0.0) AS risk_score,
      _loaded_at,
      _source_file
  FROM BRONZE.RAW_TRANSACTIONS
  WHERE txn_id IS NOT NULL
    AND member_id IS NOT NULL
    AND amount IS NOT NULL
    AND txn_timestamp IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY txn_id ORDER BY _loaded_at DESC) = 1;

-- =============================================================================
-- Silver: Enriched Members (cleansed, deduplicated, standardized)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE SILVER.ENRICHED_MEMBERS
  TARGET_LAG = DOWNSTREAM
  WAREHOUSE = ews_transform_wh
  REFRESH_MODE = INCREMENTAL
AS
  SELECT
      member_id,
      TRIM(UPPER(institution_id)) AS institution_id,
      INITCAP(TRIM(first_name)) AS first_name,
      INITCAP(TRIM(last_name)) AS last_name,
      date_of_birth,
      ssn_hash,
      LOWER(TRIM(email)) AS email,
      REGEXP_REPLACE(phone, '[^0-9]', '') AS phone_normalized,
      TRIM(address_line1) AS address_line1,
      TRIM(address_line2) AS address_line2,
      INITCAP(TRIM(city)) AS city,
      UPPER(state_code) AS state_code,
      TRIM(zip_code) AS zip_code,
      UPPER(COALESCE(country_code, 'US')) AS country_code,
      member_since,
      UPPER(status) AS status,
      UPPER(risk_tier) AS risk_tier,
      COALESCE(kyc_verified, FALSE) AS kyc_verified,
      last_activity_date,
      _loaded_at
  FROM BRONZE.RAW_MEMBERS
  WHERE member_id IS NOT NULL
    AND institution_id IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY _loaded_at DESC) = 1;

-- =============================================================================
-- Silver: Deduplicated Streaming Events (dedup on event_id)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE SILVER.DEDUP_EVENTS
  TARGET_LAG = DOWNSTREAM
  WAREHOUSE = ews_transform_wh
  REFRESH_MODE = INCREMENTAL
AS
  SELECT
      event_id,
      event_time,
      UPPER(event_type) AS event_type,
      TRIM(UPPER(member_id)) AS member_id,
      TRIM(UPPER(institution_id)) AS institution_id,
      payload,
      amount,
      UPPER(channel) AS channel,
      device_id,
      ip_address,
      geo_lat,
      geo_lon,
      COALESCE(risk_score, 0.0) AS risk_score,
      _ingest_time
  FROM BRONZE.STREAMING_EVENTS
  WHERE event_id IS NOT NULL
    AND member_id IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY _ingest_time DESC) = 1;

-- =============================================================================
-- Silver: Enriched Alerts (joined with member data for context)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE SILVER.ENRICHED_ALERTS
  TARGET_LAG = DOWNSTREAM
  WAREHOUSE = ews_transform_wh
  REFRESH_MODE = INCREMENTAL
AS
  SELECT
      a.alert_id,
      a.member_id,
      a.institution_id,
      a.alert_timestamp,
      UPPER(a.alert_type) AS alert_type,
      UPPER(a.severity) AS severity,
      a.alert_source,
      a.description,
      a.related_txn_id,
      a.rule_id,
      COALESCE(a.confidence_score, 0.0) AS confidence_score,
      UPPER(a.status) AS status,
      a.assigned_to,
      a.resolution_notes,
      a.resolved_at,
      -- Enrichment from members
      m.risk_tier AS member_risk_tier,
      m.kyc_verified AS member_kyc_verified,
      m.member_since
  FROM BRONZE.RAW_ALERTS a
  LEFT JOIN SILVER.ENRICHED_MEMBERS m ON a.member_id = m.member_id
  WHERE a.alert_id IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY a.alert_id ORDER BY a._loaded_at DESC) = 1;

-- =============================================================================
-- Validation
-- =============================================================================

SHOW DYNAMIC TABLES IN SCHEMA SILVER;
