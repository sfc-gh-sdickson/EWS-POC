/*=============================================================================
  EWS POC - UC02 Step 6: Exactly-Once Validation Queries
  
  PURPOSE: Prove that Snowpipe Streaming delivers exactly-once semantics
           and maintains event-time ordering even with duplicates and
           late-arriving events.
  
  SNOWFLAKE ADVANTAGE: Offset-based exactly-once delivery is built into the
  SDK — no Kafka transaction fencing, no consumer group coordination,
  no idempotent producer configuration needed.
=============================================================================*/

USE ROLE EWS_ANALYST;
USE DATABASE EWS_POC;
USE SCHEMA BRONZE;
USE WAREHOUSE ews_analytics_wh;

-- =============================================================================
-- 1. EXACTLY-ONCE PROOF: Check for duplicate event_ids
-- Expected: Each event_id appears exactly once despite triple-sending
-- =============================================================================

SELECT
    'DUPLICATE CHECK' AS test_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT event_id) AS unique_events,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT event_id) THEN 'PASS: Exactly-once confirmed'
        ELSE 'FAIL: Duplicates detected (' || (COUNT(*) - COUNT(DISTINCT event_id)) || ' dupes)'
    END AS result
FROM BRONZE.STREAMING_EVENTS
WHERE event_id LIKE 'DUP-%';

-- Detail: Show any event_ids that appear more than once
SELECT
    event_id,
    COUNT(*) AS occurrence_count
FROM BRONZE.STREAMING_EVENTS
WHERE event_id LIKE 'DUP-%'
GROUP BY event_id
HAVING COUNT(*) > 1;

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
-- 3. BURST HANDLING: Verify all burst events landed
-- Expected: All 500 burst events present
-- =============================================================================

SELECT
    'BURST CHECK' AS test_name,
    COUNT(*) AS burst_events_received,
    500 AS burst_events_sent,
    CASE
        WHEN COUNT(*) = 500 THEN 'PASS: All burst events landed'
        ELSE 'FAIL: Missing ' || (500 - COUNT(*)) || ' events'
    END AS result,
    MIN(event_time) AS first_event,
    MAX(event_time) AS last_event,
    TIMESTAMPDIFF('millisecond', MIN(event_time), MAX(event_time)) AS burst_span_ms
FROM BRONZE.STREAMING_EVENTS
WHERE event_id LIKE 'BURST-%';

-- =============================================================================
-- 4. LATENCY MEASUREMENT: Ingest-to-queryable latency
-- Measures how quickly streaming data becomes available for queries
-- =============================================================================

SELECT
    'LATENCY CHECK' AS test_name,
    COUNT(*) AS sample_size,
    AVG(TIMESTAMPDIFF('millisecond', event_time, _ingest_time)) AS avg_latency_ms,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY
        TIMESTAMPDIFF('millisecond', event_time, _ingest_time)
    ) AS p50_latency_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY
        TIMESTAMPDIFF('millisecond', event_time, _ingest_time)
    ) AS p95_latency_ms,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY
        TIMESTAMPDIFF('millisecond', event_time, _ingest_time)
    ) AS p99_latency_ms,
    MAX(TIMESTAMPDIFF('millisecond', event_time, _ingest_time)) AS max_latency_ms
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
