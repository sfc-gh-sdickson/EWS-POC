/*=============================================================================
  EWS POC - UC03 Step 2: Gold Zone Dynamic Tables
  
  PURPOSE: Curated, aggregated, business-ready tables built declaratively
  on top of Silver zone. These feed BI, AI, feature stores, and data shares.
  
  TARGET_LAG = '10 minutes' means data is at most 10 minutes stale.
  Snowflake handles all scheduling automatically.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE WAREHOUSE ews_transform_wh;

-- =============================================================================
-- Gold: Daily Member Summary (aggregated transaction metrics per member per day)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE GOLD.DAILY_MEMBER_SUMMARY
  TARGET_LAG = '10 minutes'
  WAREHOUSE = ews_transform_wh
  REFRESH_MODE = INCREMENTAL
AS
  SELECT
      member_id,
      institution_id,
      DATE_TRUNC('day', txn_timestamp)::DATE AS txn_date,
      COUNT(*) AS txn_count,
      SUM(CASE WHEN txn_type = 'DEBIT' THEN 1 ELSE 0 END) AS debit_count,
      SUM(CASE WHEN txn_type = 'CREDIT' THEN 1 ELSE 0 END) AS credit_count,
      SUM(amount) AS total_amount,
      SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS total_credits,
      SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) AS total_debits,
      AVG(amount) AS avg_amount,
      MAX(amount) AS max_amount,
      MIN(amount) AS min_amount,
      COUNT(DISTINCT channel) AS unique_channels,
      COUNT(DISTINCT merchant_category) AS unique_merchant_categories,
      MAX(risk_score) AS max_risk_score,
      AVG(risk_score) AS avg_risk_score
  FROM SILVER.CLEANSED_TRANSACTIONS
  GROUP BY member_id, institution_id, DATE_TRUNC('day', txn_timestamp)::DATE;

-- =============================================================================
-- Gold: Fraud Signals (high-risk events and alerts combined)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE GOLD.FRAUD_SIGNALS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = ews_transform_wh
  REFRESH_MODE = INCREMENTAL
AS
  SELECT
      COALESCE(a.alert_id, e.event_id) AS signal_id,
      COALESCE(a.member_id, e.member_id) AS member_id,
      COALESCE(a.institution_id, e.institution_id) AS institution_id,
      COALESCE(a.alert_timestamp, e.event_time) AS signal_time,
      CASE
          WHEN a.alert_id IS NOT NULL THEN 'ALERT'
          ELSE 'HIGH_RISK_EVENT'
      END AS signal_source,
      a.alert_type,
      a.severity,
      a.confidence_score AS alert_confidence,
      e.risk_score AS event_risk_score,
      e.amount AS event_amount,
      e.channel AS event_channel,
      e.ip_address,
      e.geo_lat,
      e.geo_lon,
      a.status AS alert_status
  FROM SILVER.ENRICHED_ALERTS a
  FULL OUTER JOIN SILVER.DEDUP_EVENTS e
      ON a.related_txn_id = e.event_id
  WHERE a.severity IN ('HIGH', 'CRITICAL')
     OR e.risk_score > 0.75;

-- =============================================================================
-- Gold: Member Activity Profile (latest activity summary per member)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE GOLD.MEMBER_ACTIVITY
  TARGET_LAG = '10 minutes'
  WAREHOUSE = ews_transform_wh
  REFRESH_MODE = INCREMENTAL
AS
  SELECT
      m.member_id,
      m.institution_id,
      m.first_name,
      m.last_name,
      m.risk_tier,
      m.kyc_verified,
      m.member_since,
      m.status AS member_status,
      -- Transaction summaries (last 30 days from Silver)
      COUNT(t.txn_id) AS txn_count_30d,
      SUM(t.amount) AS total_spend_30d,
      AVG(t.amount) AS avg_txn_30d,
      MAX(t.txn_timestamp) AS last_txn_time,
      COUNT(DISTINCT t.channel) AS channels_used_30d,
      -- Alert summaries
      COUNT(DISTINCT a.alert_id) AS open_alerts,
      MAX(a.alert_timestamp) AS last_alert_time
  FROM SILVER.ENRICHED_MEMBERS m
  LEFT JOIN SILVER.CLEANSED_TRANSACTIONS t
      ON m.member_id = t.member_id
      AND t.txn_timestamp >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  LEFT JOIN SILVER.ENRICHED_ALERTS a
      ON m.member_id = a.member_id
      AND a.status IN ('OPEN', 'INVESTIGATING')
  GROUP BY
      m.member_id, m.institution_id, m.first_name, m.last_name,
      m.risk_tier, m.kyc_verified, m.member_since, m.status;

-- =============================================================================
-- Gold: Institution Summary (aggregated metrics per financial institution)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE GOLD.INSTITUTION_SUMMARY
  TARGET_LAG = '30 minutes'
  WAREHOUSE = ews_transform_wh
  REFRESH_MODE = INCREMENTAL
AS
  SELECT
      i.institution_id,
      i.institution_name,
      i.institution_type,
      i.region,
      i.asset_size_tier,
      COUNT(DISTINCT t.member_id) AS active_members_30d,
      COUNT(t.txn_id) AS total_txns_30d,
      SUM(t.amount) AS total_volume_30d,
      AVG(t.risk_score) AS avg_risk_score,
      COUNT(DISTINCT a.alert_id) AS alerts_30d,
      SUM(CASE WHEN a.severity = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_alerts_30d
  FROM BRONZE.RAW_INSTITUTIONS i
  LEFT JOIN SILVER.CLEANSED_TRANSACTIONS t
      ON i.institution_id = t.institution_id
      AND t.txn_timestamp >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  LEFT JOIN SILVER.ENRICHED_ALERTS a
      ON i.institution_id = a.institution_id
      AND a.alert_timestamp >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  GROUP BY
      i.institution_id, i.institution_name, i.institution_type,
      i.region, i.asset_size_tier;

-- =============================================================================
-- Validation
-- =============================================================================

SHOW DYNAMIC TABLES IN SCHEMA GOLD;

-- View the auto-inferred pipeline DAG
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_GRAPH_HISTORY());
