/*=============================================================================
  EWS POC - UC09: Multi-Cluster Warehouse + Time Travel 90-Day Queries
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;

-- =============================================================================
-- Warehouse configured in 01_foundation/03_database_schemas.sql
-- Key features demonstrated:
--   - MAX_CLUSTER_COUNT = 10 (auto-scales with concurrent queries)
--   - ENABLE_QUERY_ACCELERATION = TRUE (offloads scan-heavy queries)
--   - AUTO_SUSPEND = 60 (per-second billing, no waste)
-- =============================================================================

-- Verify configuration
SHOW WAREHOUSES LIKE 'ews_analytics_wh';

-- =============================================================================
-- BI Workload Queries (simulating concurrent dashboard queries)
-- =============================================================================

USE WAREHOUSE ews_analytics_wh;

-- Dashboard Query 1: Daily fraud alerts by institution
SELECT
    institution_id,
    DATE_TRUNC('day', signal_time)::DATE AS signal_date,
    signal_source,
    COUNT(*) AS signal_count,
    AVG(COALESCE(event_risk_score, alert_confidence)) AS avg_risk
FROM GOLD.FRAUD_SIGNALS
WHERE signal_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY 1, 2, 3
ORDER BY signal_date DESC, signal_count DESC;

-- Dashboard Query 2: Top members by transaction volume
SELECT
    ma.member_id,
    ma.first_name || ' ' || ma.last_name AS member_name,
    ma.institution_id,
    ma.risk_tier,
    ma.txn_count_30d,
    ma.total_spend_30d,
    ma.open_alerts
FROM GOLD.MEMBER_ACTIVITY ma
WHERE ma.txn_count_30d > 0
ORDER BY ma.total_spend_30d DESC
LIMIT 100;

-- Dashboard Query 3: Institution health overview
SELECT
    institution_name,
    institution_type,
    region,
    active_members_30d,
    total_txns_30d,
    total_volume_30d,
    alerts_30d,
    critical_alerts_30d,
    ROUND(alerts_30d::FLOAT / NULLIF(total_txns_30d, 0) * 10000, 2) AS alerts_per_10k_txns
FROM GOLD.INSTITUTION_SUMMARY
ORDER BY total_volume_30d DESC;

-- =============================================================================
-- 90-Day Time Travel Query (Iceberg snapshot-based)
-- =============================================================================

-- Query Gold data as it appeared 90 days ago
SELECT
    member_id,
    SUM(txn_count) AS total_txns_at_90d,
    SUM(total_amount) AS total_volume_at_90d,
    COUNT(DISTINCT txn_date) AS active_days_at_90d
FROM GOLD.DAILY_MEMBER_SUMMARY
  AT(TIMESTAMP => DATEADD('day', -90, CURRENT_TIMESTAMP())::TIMESTAMP_LTZ)
GROUP BY member_id
HAVING total_volume_at_90d > 10000
ORDER BY total_volume_at_90d DESC
LIMIT 50;

-- =============================================================================
-- Query Profiling: Measure performance
-- =============================================================================

SELECT
    query_id,
    query_text,
    warehouse_name,
    execution_status,
    total_elapsed_time / 1000.0 AS elapsed_seconds,
    bytes_scanned / (1024*1024*1024.0) AS gb_scanned,
    rows_produced,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned::FLOAT / NULLIF(partitions_total, 0) * 100, 1) AS prune_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE warehouse_name = 'EWS_ANALYTICS_WH'
  AND start_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
  AND execution_status = 'SUCCESS'
ORDER BY total_elapsed_time DESC
LIMIT 20;
