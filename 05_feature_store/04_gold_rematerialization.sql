/*=============================================================================
  EWS POC - UC04 Step 4: Gold Rematerialization
  
  One command rebuilds the entire online feature store from Gold history,
  overwriting defective streaming values. No stream replay needed.
  
  SNOWFLAKE ADVANTAGE: ALTER DYNAMIC TABLE REFRESH replaces custom backfill
  pipelines. Competitors need Feast/Tecton + custom replay infrastructure.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;

-- =============================================================================
-- Trigger full rebuild of online features from Gold history
-- This overwrites any defective streaming values
-- =============================================================================

ALTER DYNAMIC TABLE FEATURE_STORE.ONLINE_MEMBER_FEATURES REFRESH;

-- =============================================================================
-- Verify rebuild completed
-- =============================================================================

SELECT
    name,
    state,
    refresh_action,
    refresh_start_time,
    refresh_end_time,
    TIMESTAMPDIFF('second', refresh_start_time, refresh_end_time) AS rebuild_seconds
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE name = 'ONLINE_MEMBER_FEATURES'
ORDER BY refresh_start_time DESC
LIMIT 5;
