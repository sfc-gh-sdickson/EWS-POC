/*=============================================================================
  EWS POC - UC03 Step 5: Pipeline Monitoring
  
  PURPOSE: Monitor Dynamic Table refresh health using built-in system views.
  No external monitoring tool needed.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE WAREHOUSE ews_analytics_wh;

-- =============================================================================
-- 1. Current refresh status of all Dynamic Tables
-- =============================================================================

SELECT
    name,
    schema_name,
    target_lag,
    refresh_mode,
    scheduling_state,
    last_refresh_time,
    data_timestamp
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE database_name = 'EWS_POC'
ORDER BY schema_name, name;

-- =============================================================================
-- 2. Refresh history (success/failure/duration)
-- =============================================================================

SELECT
    name,
    schema_name,
    state,
    refresh_trigger,
    refresh_action,
    TIMESTAMPDIFF('second', refresh_start_time, refresh_end_time) AS refresh_duration_sec,
    refresh_start_time,
    refresh_end_time,
    statistics
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'EWS_POC'
))
WHERE refresh_start_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
ORDER BY refresh_start_time DESC
LIMIT 50;

-- =============================================================================
-- 3. Identify slow refreshes (over 60 seconds)
-- =============================================================================

SELECT
    name,
    schema_name,
    refresh_action,
    TIMESTAMPDIFF('second', refresh_start_time, refresh_end_time) AS duration_sec,
    refresh_start_time
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'EWS_POC'
))
WHERE TIMESTAMPDIFF('second', refresh_start_time, refresh_end_time) > 60
  AND state = 'SUCCEEDED'
ORDER BY duration_sec DESC;

-- =============================================================================
-- 4. Failed refreshes (troubleshooting)
-- =============================================================================

SELECT
    name,
    schema_name,
    state,
    state_message,
    refresh_start_time,
    statistics
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'EWS_POC'
))
WHERE state = 'FAILED'
  AND refresh_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY refresh_start_time DESC;
