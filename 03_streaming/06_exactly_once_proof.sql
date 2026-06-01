/*=============================================================================
  EWS POC - UC02 Step 6: Exactly-Once Validation Queries
  
  PURPOSE: Prove that Kinesis Firehose → Snowpipe AUTO_INGEST → Silver DT
           delivers exactly-once semantics via file-level deduplication
           (Snowpipe) and row-level deduplication (Silver Dynamic Table).
  
  ARCHITECTURE:
    Firehose at-least-once → Bronze (may have dupes) → Silver DT (deduped)
  
  SNOWFLAKE ADVANTAGE: Snowpipe provides file-level exactly-once (won't
  re-load the same file). Silver Dynamic Table provides row-level dedup
  via QUALIFY ROW_NUMBER() — all declarative, no custom code.
=============================================================================*/

USE ROLE EWS_ANALYST;
USE DATABASE EWS_POC;
USE SCHEMA BRONZE;
USE WAREHOUSE ews_analytics_wh;

-- =============================================================================
-- 1. BRONZE LAYER: Check raw data (may contain duplicates from Firehose at-least-once)
-- =============================================================================

SELECT
    'BRONZE RAW CHECK' AS test_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT event_id) AS unique_events,
    COUNT(*) - COUNT(DISTINCT event_id) AS duplicate_rows,
    CASE
        WHEN COUNT(*) > COUNT(DISTINCT event_id) THEN 'EXPECTED: Bronze has duplicates (Firehose at-least-once)'
        ELSE 'No duplicates in Bronze (clean delivery)'
    END AS result
FROM BRONZE.STREAMING_EVENTS
WHERE event_id LIKE 'DUP-%';

-- =============================================================================
-- 2. SILVER LAYER: Verify deduplication (exactly-once after DT processing)
-- Expected: Each event_id appears exactly once in Silver
-- =============================================================================

SELECT
    'SILVER DEDUP CHECK' AS test_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT event_id) AS unique_events,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT event_id) THEN 'PASS: Silver has exactly-once (DT dedup working)'
        ELSE 'FAIL: Silver has duplicates (' || (COUNT(*) - COUNT(DISTINCT event_id)) || ' extra rows)'
    END AS result
FROM SILVER.DEDUP_EVENTS
WHERE event_id LIKE 'DUP-%';

-- =============================================================================
-- 2. EVENT-TIME ORDERING: Verify late-arriving events are queryable and ordered
-- Expected: Events ordered by event_time regardless of arrival time
-- =============================================================================

SELECT
    'LATE ARRIVAL CHECK' AS test_name,
    event_id,
    event_time,
    _ingest_time,
    TIMESTAMPDIFF('hour', event_time, _ingest_time) AS hours_late,
    CASE
        WHEN _ingest_time > event_time THEN 'CONFIRMED LATE'
        ELSE 'ON TIME'
    END AS arrival_status
FROM BRONZE.STREAMING_EVENTS
WHERE event_id LIKE 'LATE-%'
ORDER BY event_time ASC;

-- Verify ordering is correct when querying by event_time
SELECT
    event_id,
    event_time,
    LAG(event_time) OVER (ORDER BY event_time) AS prev_event_time,
    CASE
        WHEN event_time >= LAG(event_time) OVER (ORDER BY event_time) THEN 'ORDERED'
        WHEN LAG(event_time) OVER (ORDER BY event_time) IS NULL THEN 'FIRST'
        ELSE 'OUT OF ORDER'
    END AS order_check
FROM BRONZE.STREAMING_EVENTS
WHERE event_id LIKE 'LATE-%'
ORDER BY event_time;

-- =============================================================================
-- 3. BURST HANDLING: Verify all burst events landed in Bronze
-- Expected: All 1000 burst events present in Bronze
-- =============================================================================

SELECT
    'BURST CHECK' AS test_name,
    COUNT(*) AS burst_events_received,
    1000 AS burst_events_sent,
    CASE
        WHEN COUNT(*) >= 1000 THEN 'PASS: All burst events landed'
        ELSE 'PENDING: ' || (1000 - COUNT(*)) || ' events not yet loaded (check Firehose buffer)'
    END AS result,
    MIN(event_time) AS first_event,
    MAX(event_time) AS last_event
FROM BRONZE.STREAMING_EVENTS
WHERE event_id LIKE 'BURST-%';

-- =============================================================================
-- 4. LATENCY MEASUREMENT: Firehose-to-queryable latency
-- Measures end-to-end: event_time → Firehose buffer → S3 → Snowpipe → queryable
-- Expected: 2-6 minutes depending on Firehose buffer interval
-- =============================================================================

SELECT
    'E2E LATENCY' AS test_name,
    COUNT(*) AS sample_size,
    ROUND(AVG(TIMESTAMPDIFF('second', event_time, _ingest_time)), 0) AS avg_latency_sec,
    ROUND(MIN(TIMESTAMPDIFF('second', event_time, _ingest_time)), 0) AS min_latency_sec,
    ROUND(MAX(TIMESTAMPDIFF('second', event_time, _ingest_time)), 0) AS max_latency_sec,
    CASE
        WHEN AVG(TIMESTAMPDIFF('second', event_time, _ingest_time)) < 360 THEN 'GOOD: Under 6 minutes'
        ELSE 'CHECK: Latency exceeds 6 minutes (verify Firehose buffer interval)'
    END AS assessment
FROM BRONZE.STREAMING_EVENTS
WHERE event_id LIKE 'BURST-%'
  AND _ingest_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP());

-- =============================================================================
-- 5. OVERALL SUMMARY
-- =============================================================================

SELECT
    event_type,
    COUNT(*) AS event_count,
    MIN(event_time) AS earliest_event,
    MAX(event_time) AS latest_event,
    COUNT(DISTINCT member_id) AS unique_members
FROM BRONZE.STREAMING_EVENTS
GROUP BY event_type
ORDER BY event_count DESC;
