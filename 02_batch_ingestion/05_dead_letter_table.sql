/*=============================================================================
  EWS POC - UC01 Step 5: Dead Letter Table and VALIDATE() Extraction
  
  PURPOSE: Capture rejected records from COPY INTO operations without aborting
           the batch. Uses Snowflake's unique VALIDATE() function to extract
           error details from the last load operation.
  
  SNOWFLAKE ADVANTAGE: VALIDATE() is a Snowflake-only function that returns
  all rejected rows with error reasons from the last COPY INTO — without
  re-parsing the source files. No other platform offers this capability.
  Competitors need separate error-handling infrastructure.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE WAREHOUSE ews_ingest_wh;

-- =============================================================================
-- Dead Letter Table: Stores all rejected records with error context
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE STAGING.DEAD_LETTER_RECORDS (
    rejection_id        VARCHAR(50)     DEFAULT UUID_STRING(),
    source_table        VARCHAR(200)    NOT NULL,
    source_file         VARCHAR(500),
    row_number          NUMBER,
    rejected_record     VARCHAR(10000),
    error_message       VARCHAR(2000),
    error_column_name   VARCHAR(200),
    error_category      VARCHAR(50),       -- PARSE_ERROR, TYPE_MISMATCH, CONSTRAINT, UNKNOWN
    rejection_timestamp TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    reprocessed         BOOLEAN         DEFAULT FALSE,
    reprocessed_at      TIMESTAMP_LTZ
)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'ews_iceberg_vol'
  BASE_LOCATION = 'staging/dead_letter/'
  COMMENT = 'Dead letter table capturing all rejected records from batch ingestion';

-- =============================================================================
-- Extract rejected records using VALIDATE() (Snowflake-unique)
-- Run this AFTER each COPY INTO operation
-- =============================================================================

-- Extract rejects from RAW_TRANSACTIONS load
INSERT INTO STAGING.DEAD_LETTER_RECORDS (
    source_table, source_file, row_number, rejected_record,
    error_message, error_column_name, error_category
)
SELECT
    'BRONZE.RAW_TRANSACTIONS',
    "file",
    "line",
    "rejected_record",
    "error",
    "column_name",
    CASE
        WHEN "error" ILIKE '%conversion%' THEN 'TYPE_MISMATCH'
        WHEN "error" ILIKE '%parse%' THEN 'PARSE_ERROR'
        WHEN "error" ILIKE '%null%' THEN 'CONSTRAINT'
        ELSE 'UNKNOWN'
    END
FROM TABLE(VALIDATE(BRONZE.RAW_TRANSACTIONS, JOB_ID => '_last'));

-- Extract rejects from RAW_MEMBERS load
INSERT INTO STAGING.DEAD_LETTER_RECORDS (
    source_table, source_file, row_number, rejected_record,
    error_message, error_column_name, error_category
)
SELECT
    'BRONZE.RAW_MEMBERS',
    "file",
    "line",
    "rejected_record",
    "error",
    "column_name",
    CASE
        WHEN "error" ILIKE '%conversion%' THEN 'TYPE_MISMATCH'
        WHEN "error" ILIKE '%parse%' THEN 'PARSE_ERROR'
        WHEN "error" ILIKE '%null%' THEN 'CONSTRAINT'
        ELSE 'UNKNOWN'
    END
FROM TABLE(VALIDATE(BRONZE.RAW_MEMBERS, JOB_ID => '_last'));

-- Extract rejects from RAW_ALERTS load
INSERT INTO STAGING.DEAD_LETTER_RECORDS (
    source_table, source_file, row_number, rejected_record,
    error_message, error_column_name, error_category
)
SELECT
    'BRONZE.RAW_ALERTS',
    "file",
    "line",
    "rejected_record",
    "error",
    "column_name",
    CASE
        WHEN "error" ILIKE '%conversion%' THEN 'TYPE_MISMATCH'
        WHEN "error" ILIKE '%parse%' THEN 'PARSE_ERROR'
        WHEN "error" ILIKE '%null%' THEN 'CONSTRAINT'
        ELSE 'UNKNOWN'
    END
FROM TABLE(VALIDATE(BRONZE.RAW_ALERTS, JOB_ID => '_last'));

-- =============================================================================
-- Dead Letter Summary Report
-- =============================================================================

SELECT
    source_table,
    error_category,
    COUNT(*) AS rejection_count,
    MIN(rejection_timestamp) AS first_rejection,
    MAX(rejection_timestamp) AS last_rejection
FROM STAGING.DEAD_LETTER_RECORDS
WHERE reprocessed = FALSE
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- =============================================================================
-- Rejection rate by source file (for operational alerting)
-- =============================================================================

SELECT
    source_table,
    source_file,
    COUNT(*) AS rejected_rows,
    rejection_timestamp::DATE AS load_date
FROM STAGING.DEAD_LETTER_RECORDS
WHERE rejection_timestamp >= DATEADD('day', -1, CURRENT_TIMESTAMP())
GROUP BY 1, 2, 4
ORDER BY 3 DESC;
