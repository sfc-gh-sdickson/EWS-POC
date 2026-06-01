/*=============================================================================
  EWS POC - UC01 Step 6: Data Metric Functions (DMFs) for Quality Checks
  
  PURPOSE: Create native Data Metric Functions that automatically run quality
           checks on Bronze tables after data loads. DMFs are Snowflake's
           built-in data quality framework.
  
  SNOWFLAKE ADVANTAGE: DMFs are native to the platform — no Great Expectations,
  no Soda, no dbt tests, no separate quality tool. Results are visible in
  Snowsight UI, queryable via INFORMATION_SCHEMA, and can trigger alerts.
  Quality metadata lives alongside table metadata.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE SCHEMA GOVERNANCE;
USE WAREHOUSE ews_transform_wh;

-- =============================================================================
-- DMF 1: Null Rate — Percentage of null values in a column
-- =============================================================================

CREATE OR REPLACE DATA METRIC FUNCTION GOVERNANCE.DM_NULL_RATE(
    ARG_T TABLE(ARG_C VARCHAR)
)
RETURNS NUMBER(5,4)
AS
$$
    SELECT
        CASE WHEN COUNT(*) = 0 THEN 0
             ELSE COUNT_IF(ARG_C IS NULL) / COUNT(*)
        END
    FROM ARG_T
$$;

-- =============================================================================
-- DMF 2: Duplicate Rate — Percentage of duplicate values
-- =============================================================================

CREATE OR REPLACE DATA METRIC FUNCTION GOVERNANCE.DM_DUPLICATE_RATE(
    ARG_T TABLE(ARG_C VARCHAR)
)
RETURNS NUMBER(5,4)
AS
$$
    SELECT
        CASE WHEN COUNT(*) = 0 THEN 0
             ELSE 1.0 - (COUNT(DISTINCT ARG_C) / COUNT(*))
        END
    FROM ARG_T
$$;

-- =============================================================================
-- DMF 3: Freshness — Hours since newest record (staleness detection)
-- =============================================================================

CREATE OR REPLACE DATA METRIC FUNCTION GOVERNANCE.DM_FRESHNESS_HOURS(
    ARG_T TABLE(ARG_C TIMESTAMP_LTZ)
)
RETURNS NUMBER(10,2)
AS
$$
    SELECT
        COALESCE(
            TIMESTAMPDIFF('minute', MAX(ARG_C), CURRENT_TIMESTAMP()) / 60.0,
            -1
        )
    FROM ARG_T
$$;

-- =============================================================================
-- DMF 4: Value Range Compliance — Percentage of values within expected range
-- =============================================================================

CREATE OR REPLACE DATA METRIC FUNCTION GOVERNANCE.DM_POSITIVE_AMOUNT_RATE(
    ARG_T TABLE(ARG_C NUMBER)
)
RETURNS NUMBER(5,4)
AS
$$
    SELECT
        CASE WHEN COUNT(*) = 0 THEN 1.0
             ELSE COUNT_IF(ARG_C >= 0) / COUNT(*)
        END
    FROM ARG_T
$$;

-- =============================================================================
-- DMF 5: Row Count — Total rows (for volume anomaly detection)
-- =============================================================================

CREATE OR REPLACE DATA METRIC FUNCTION GOVERNANCE.DM_ROW_COUNT(
    ARG_T TABLE(ARG_C VARCHAR)
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*) FROM ARG_T
$$;

-- =============================================================================
-- Attach DMFs to Bronze Tables
-- =============================================================================

USE SCHEMA BRONZE;

-- Set DMF schedule: run on every data change
ALTER TABLE BRONZE.RAW_TRANSACTIONS
  SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

ALTER TABLE BRONZE.RAW_MEMBERS
  SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

ALTER TABLE BRONZE.RAW_ALERTS
  SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- Attach specific DMFs to RAW_TRANSACTIONS
ALTER TABLE BRONZE.RAW_TRANSACTIONS
  ADD DATA METRIC FUNCTION GOVERNANCE.DM_NULL_RATE ON (txn_id);

ALTER TABLE BRONZE.RAW_TRANSACTIONS
  ADD DATA METRIC FUNCTION GOVERNANCE.DM_NULL_RATE ON (member_id);

ALTER TABLE BRONZE.RAW_TRANSACTIONS
  ADD DATA METRIC FUNCTION GOVERNANCE.DM_DUPLICATE_RATE ON (txn_id);

ALTER TABLE BRONZE.RAW_TRANSACTIONS
  ADD DATA METRIC FUNCTION GOVERNANCE.DM_FRESHNESS_HOURS ON (txn_timestamp);

-- Attach DMFs to RAW_MEMBERS
ALTER TABLE BRONZE.RAW_MEMBERS
  ADD DATA METRIC FUNCTION GOVERNANCE.DM_NULL_RATE ON (member_id);

ALTER TABLE BRONZE.RAW_MEMBERS
  ADD DATA METRIC FUNCTION GOVERNANCE.DM_DUPLICATE_RATE ON (member_id);

-- Attach DMFs to RAW_ALERTS
ALTER TABLE BRONZE.RAW_ALERTS
  ADD DATA METRIC FUNCTION GOVERNANCE.DM_NULL_RATE ON (alert_id);

ALTER TABLE BRONZE.RAW_ALERTS
  ADD DATA METRIC FUNCTION GOVERNANCE.DM_FRESHNESS_HOURS ON (alert_timestamp);

-- =============================================================================
-- Query DMF Results (via INFORMATION_SCHEMA)
-- =============================================================================

SELECT *
FROM TABLE(INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
    REF_ENTITY_NAME => 'EWS_POC.BRONZE.RAW_TRANSACTIONS',
    REF_ENTITY_DOMAIN => 'TABLE'
));

-- View DMF evaluation history
-- SELECT * FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
-- WHERE TABLE_NAME = 'RAW_TRANSACTIONS'
-- ORDER BY MEASUREMENT_TIME DESC
-- LIMIT 20;
