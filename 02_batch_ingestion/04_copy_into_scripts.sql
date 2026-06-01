/*=============================================================================
  EWS POC - UC01 Step 4: COPY INTO Scripts (Batch Ingestion)
  
  PURPOSE: Execute batch ingestion with ON_ERROR=CONTINUE for partial
           acceptance. Valid records load into Bronze; rejected records
           are captured without aborting the batch.
  
  SNOWFLAKE ADVANTAGE: ON_ERROR=CONTINUE + VALIDATE() is a unique Snowflake
  capability. A single COPY INTO statement handles millions of records,
  loading valid rows and tracking rejects — no custom error handling,
  no try/catch blocks, no Spark accumulators.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE SCHEMA BRONZE;
USE WAREHOUSE ews_ingest_wh;

-- =============================================================================
-- 1. DELIMITED FILES: Transaction batch ingestion
-- ON_ERROR=CONTINUE ensures valid records load even if some rows fail
-- =============================================================================

COPY INTO BRONZE.RAW_TRANSACTIONS (
    txn_id, member_id, institution_id, txn_timestamp, amount,
    currency_code, txn_type, channel, merchant_category, merchant_name,
    merchant_country, status, auth_code, card_last_four, ip_address,
    device_fingerprint, risk_score, _loaded_at, _source_file
)
FROM (
    SELECT
        $1,                                     -- txn_id
        $2,                                     -- member_id
        $3,                                     -- institution_id
        TO_TIMESTAMP_LTZ($4),                   -- txn_timestamp
        TO_NUMBER($5, 15, 2),                   -- amount
        $6,                                     -- currency_code
        $7,                                     -- txn_type
        $8,                                     -- channel
        $9,                                     -- merchant_category
        $10,                                    -- merchant_name
        $11,                                    -- merchant_country
        $12,                                    -- status
        $13,                                    -- auth_code
        $14,                                    -- card_last_four
        $15,                                    -- ip_address
        $16,                                    -- device_fingerprint
        TRY_TO_NUMBER($17, 5, 2),               -- risk_score (may be malformed)
        CURRENT_TIMESTAMP(),                    -- _loaded_at
        METADATA$FILENAME                       -- _source_file
    FROM @ews_txn_landing_stage
)
ON_ERROR = CONTINUE
PURGE = FALSE
FORCE = FALSE;

-- =============================================================================
-- 2. FIXED-WIDTH FILES: Member profile ingestion
-- Load as single column, parse with SUBSTR positions
-- =============================================================================

COPY INTO BRONZE.RAW_MEMBERS (
    member_id, institution_id, first_name, last_name, date_of_birth,
    ssn_hash, email, phone, address_line1, city, state_code, zip_code,
    country_code, member_since, status, risk_tier, _loaded_at, _source_file
)
FROM (
    SELECT
        TRIM(SUBSTR($1, 1, 20)),                -- member_id (pos 1-20)
        TRIM(SUBSTR($1, 21, 20)),               -- institution_id (pos 21-40)
        TRIM(SUBSTR($1, 41, 50)),               -- first_name (pos 41-90)
        TRIM(SUBSTR($1, 91, 50)),               -- last_name (pos 91-140)
        TRY_TO_DATE(TRIM(SUBSTR($1, 141, 10)), 'YYYY-MM-DD'),  -- dob (pos 141-150)
        TRIM(SUBSTR($1, 151, 64)),              -- ssn_hash (pos 151-214)
        TRIM(SUBSTR($1, 215, 100)),             -- email (pos 215-314)
        TRIM(SUBSTR($1, 315, 20)),              -- phone (pos 315-334)
        TRIM(SUBSTR($1, 335, 100)),             -- address_line1 (pos 335-434)
        TRIM(SUBSTR($1, 435, 50)),              -- city (pos 435-484)
        TRIM(SUBSTR($1, 485, 2)),               -- state_code (pos 485-486)
        TRIM(SUBSTR($1, 487, 10)),              -- zip_code (pos 487-496)
        TRIM(SUBSTR($1, 497, 3)),               -- country_code (pos 497-499)
        TRY_TO_DATE(TRIM(SUBSTR($1, 500, 10)), 'YYYY-MM-DD'),  -- member_since (pos 500-509)
        TRIM(SUBSTR($1, 510, 20)),              -- status (pos 510-529)
        TRIM(SUBSTR($1, 530, 10)),              -- risk_tier (pos 530-539)
        CURRENT_TIMESTAMP(),                    -- _loaded_at
        METADATA$FILENAME                       -- _source_file
    FROM @ews_member_landing_stage
)
ON_ERROR = CONTINUE
PURGE = FALSE
FORCE = FALSE;

-- =============================================================================
-- 3. EBCDIC-CONVERTED FILES: Alert ingestion
-- =============================================================================

COPY INTO BRONZE.RAW_ALERTS (
    alert_id, member_id, institution_id, alert_timestamp, alert_type,
    severity, alert_source, description, related_txn_id, rule_id,
    confidence_score, status, assigned_to, _loaded_at, _source_file
)
FROM (
    SELECT
        $1,                                     -- alert_id
        $2,                                     -- member_id
        $3,                                     -- institution_id
        TO_TIMESTAMP_LTZ($4),                   -- alert_timestamp
        $5,                                     -- alert_type
        $6,                                     -- severity
        $7,                                     -- alert_source
        $8,                                     -- description
        $9,                                     -- related_txn_id
        $10,                                    -- rule_id
        TRY_TO_NUMBER($11, 5, 4),               -- confidence_score
        $12,                                    -- status
        $13,                                    -- assigned_to
        CURRENT_TIMESTAMP(),                    -- _loaded_at
        METADATA$FILENAME                       -- _source_file
    FROM @ews_alert_landing_stage
)
ON_ERROR = CONTINUE
PURGE = FALSE
FORCE = FALSE;

-- =============================================================================
-- 4. Check load results
-- =============================================================================

-- View most recent COPY INTO results
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'RAW_TRANSACTIONS',
    START_TIME => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC
LIMIT 10;
