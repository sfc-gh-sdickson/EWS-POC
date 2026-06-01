/*=============================================================================
  EWS POC - UC05: Offline Feature Store - Time Travel Queries
  
  SNOWFLAKE ADVANTAGE: Native Time Travel on Iceberg tables. Query any
  historical point up to 90 days. No manual snapshot management.
=============================================================================*/

USE ROLE EWS_ANALYST;
USE DATABASE EWS_POC;
USE WAREHOUSE ews_analytics_wh;

-- =============================================================================
-- 1. Point-in-time query: What did features look like 7 days ago?
-- =============================================================================

SELECT *
FROM FEATURE_STORE.OFFLINE_MEMBER_FEATURES
  AT(TIMESTAMP => DATEADD('day', -7, CURRENT_TIMESTAMP())::TIMESTAMP_LTZ)
WHERE member_id IN ('MBR100001', 'MBR100002', 'MBR100003')
ORDER BY member_id;

-- =============================================================================
-- 2. Compare current vs historical features (drift detection)
-- =============================================================================

SELECT
    curr.member_id,
    curr.txn_count_30d AS current_txn_count,
    hist.txn_count_30d AS historical_txn_count,
    curr.txn_count_30d - hist.txn_count_30d AS txn_count_change,
    curr.total_spend_30d AS current_spend,
    hist.total_spend_30d AS historical_spend,
    ROUND((curr.total_spend_30d - hist.total_spend_30d) / NULLIF(hist.total_spend_30d, 0) * 100, 1) AS spend_change_pct
FROM FEATURE_STORE.OFFLINE_MEMBER_FEATURES curr
JOIN FEATURE_STORE.OFFLINE_MEMBER_FEATURES
    AT(TIMESTAMP => DATEADD('day', -30, CURRENT_TIMESTAMP())::TIMESTAMP_LTZ) hist
    ON curr.member_id = hist.member_id
WHERE ABS(curr.total_spend_30d - hist.total_spend_30d) > 1000
ORDER BY ABS(spend_change_pct) DESC
LIMIT 20;

-- =============================================================================
-- 3. 90-day lookback: Feature state at a specific decision date
-- =============================================================================

SELECT *
FROM GOLD.DAILY_MEMBER_SUMMARY
  AT(TIMESTAMP => '2025-03-01 00:00:00'::TIMESTAMP_LTZ)
WHERE member_id = 'MBR100001'
ORDER BY txn_date DESC;
