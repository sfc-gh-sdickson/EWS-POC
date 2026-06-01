/*=============================================================================
  EWS POC - UC04 Step 1: Online Feature Table (Dynamic Table)
  UC05 Step 5: Offline Time Travel Queries
  UC05 Step 4: Gold Rematerialization
  
  Combined feature store implementation.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE WAREHOUSE ews_transform_wh;

-- =============================================================================
-- ONLINE FEATURE STORE: Dynamic Table fed by streaming events
-- TARGET_LAG = '1 minute' for sub-minute freshness
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE FEATURE_STORE.ONLINE_MEMBER_FEATURES
  TARGET_LAG = '1 minute'
  WAREHOUSE = ews_transform_wh
  REFRESH_MODE = INCREMENTAL
AS
  SELECT
      member_id,
      -- Velocity features (last 24 hours)
      COUNT(*) AS event_count_24h,
      COUNT(DISTINCT channel) AS unique_channels_24h,
      COUNT(DISTINCT ip_address) AS unique_ips_24h,
      COUNT(DISTINCT device_id) AS unique_devices_24h,
      -- Amount features
      SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS total_spend_24h,
      AVG(amount) AS avg_amount_24h,
      MAX(amount) AS max_amount_24h,
      -- Risk features
      MAX(risk_score) AS max_risk_score_24h,
      AVG(risk_score) AS avg_risk_score_24h,
      COUNT_IF(risk_score > 0.7) AS high_risk_events_24h,
      -- Timing features
      MAX(event_time) AS last_activity_time,
      MIN(event_time) AS first_activity_24h,
      -- Freshness metadata
      CURRENT_TIMESTAMP() AS feature_computed_at
  FROM SILVER.DEDUP_EVENTS
  WHERE event_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
  GROUP BY member_id;

-- =============================================================================
-- OFFLINE FEATURE STORE: Gold-sourced batch features for ML training
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE FEATURE_STORE.OFFLINE_MEMBER_FEATURES
  TARGET_LAG = '1 hour'
  WAREHOUSE = ews_transform_wh
  REFRESH_MODE = INCREMENTAL
AS
  SELECT
      m.member_id,
      m.institution_id,
      m.risk_tier,
      m.member_since,
      DATEDIFF('day', m.member_since, CURRENT_DATE()) AS account_age_days,
      -- 30-day aggregates
      COALESCE(s.txn_count_30d, 0) AS txn_count_30d,
      COALESCE(s.total_spend_30d, 0) AS total_spend_30d,
      COALESCE(s.avg_txn_30d, 0) AS avg_txn_30d,
      COALESCE(s.channels_used_30d, 0) AS channels_used_30d,
      COALESCE(s.open_alerts, 0) AS open_alerts,
      -- Business time (when feature represents)
      CURRENT_DATE() AS business_date,
      -- System time (when computed)
      CURRENT_TIMESTAMP() AS system_time
  FROM SILVER.ENRICHED_MEMBERS m
  LEFT JOIN GOLD.MEMBER_ACTIVITY s ON m.member_id = s.member_id;

-- =============================================================================
-- Validation
-- =============================================================================

SHOW DYNAMIC TABLES IN SCHEMA FEATURE_STORE;
