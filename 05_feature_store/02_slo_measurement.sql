/*=============================================================================
  EWS POC - UC04 Step 2: SLO Measurement
  
  Measure streaming-to-feature latency. Target: <=1.5s p99.
=============================================================================*/

USE ROLE EWS_ANALYST;
USE DATABASE EWS_POC;
USE WAREHOUSE ews_analytics_wh;

-- =============================================================================
-- Measure: Time from event arrival to feature availability
-- =============================================================================

SELECT
    'FEATURE FRESHNESS SLO' AS metric,
    COUNT(*) AS sample_size,
    ROUND(AVG(TIMESTAMPDIFF('millisecond', last_activity_time, feature_computed_at)), 0) AS avg_latency_ms,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY
        TIMESTAMPDIFF('millisecond', last_activity_time, feature_computed_at)
    ), 0) AS p50_latency_ms,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY
        TIMESTAMPDIFF('millisecond', last_activity_time, feature_computed_at)
    ), 0) AS p95_latency_ms,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY
        TIMESTAMPDIFF('millisecond', last_activity_time, feature_computed_at)
    ), 0) AS p99_latency_ms,
    CASE
        WHEN PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY
            TIMESTAMPDIFF('millisecond', last_activity_time, feature_computed_at)
        ) <= 1500 THEN 'PASS: p99 <= 1.5s'
        ELSE 'FAIL: p99 > 1.5s'
    END AS slo_status
FROM FEATURE_STORE.ONLINE_MEMBER_FEATURES
WHERE feature_computed_at >= DATEADD('hour', -1, CURRENT_TIMESTAMP());
