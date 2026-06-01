/*=============================================================================
  EWS POC - UC02 Step 1: Snowpipe Auto-Ingest PIPE (Kinesis Firehose → S3 → Snowpipe)
  
  PURPOSE: Create the auto-ingest PIPE that automatically loads data when
           Kinesis Firehose delivers files to the S3 landing zone. S3 event
           notifications trigger Snowpipe via SQS to load new files.
  
  ARCHITECTURE:
    Kinesis Data Firehose → S3 (EWS-owned) → S3 Event Notification → 
    SQS Queue (Snowflake-managed) → Snowpipe AUTO_INGEST → Bronze Iceberg
  
  SNOWFLAKE ADVANTAGE: Snowpipe AUTO_INGEST is serverless — no compute to manage,
  no cluster to scale. Snowflake provisions resources automatically when files
  land. Combined with Kinesis Firehose buffering, this achieves near-real-time
  ingest (configurable 60-300s buffer) with exactly-once file-level delivery.
  No custom consumers. No checkpoint management.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE SCHEMA BRONZE;

-- =============================================================================
-- External Stage: Kinesis Firehose delivery destination
-- Firehose writes buffered event files (JSON/Parquet) to this S3 path
-- =============================================================================

CREATE OR REPLACE STAGE BRONZE.EWS_FIREHOSE_STAGE
  STORAGE_INTEGRATION = ews_s3_integration
  URL = 's3://<EWS_BUCKET_NAME>-landing/firehose/events/'
  FILE_FORMAT = ews_json_format
  DIRECTORY = (ENABLE = TRUE AUTO_REFRESH = TRUE)
  COMMENT = 'Kinesis Firehose delivery destination for real-time events';

-- =============================================================================
-- PIPE: Auto-ingest from Firehose landing zone
-- AUTO_INGEST=TRUE subscribes to S3 event notifications via SQS
-- Snowflake manages the SQS queue automatically
-- =============================================================================

CREATE OR REPLACE PIPE BRONZE.EWS_FIREHOSE_PIPE
  AUTO_INGEST = TRUE
  COMMENT = 'Auto-ingest pipe: Kinesis Firehose → S3 → Snowpipe → Bronze Iceberg'
AS
  COPY INTO BRONZE.STREAMING_EVENTS (
      event_id, event_time, event_type, member_id, institution_id,
      payload, amount, channel, device_id, ip_address,
      geo_lat, geo_lon, risk_score, _ingest_time, _channel_name
  )
  FROM (
      SELECT
          $1:event_id::VARCHAR,
          $1:event_time::TIMESTAMP_LTZ,
          $1:event_type::VARCHAR,
          $1:member_id::VARCHAR,
          $1:institution_id::VARCHAR,
          $1,                                        -- Full payload as VARIANT
          $1:amount::NUMBER(15,2),
          $1:channel::VARCHAR,
          $1:device_id::VARCHAR,
          $1:ip_address::VARCHAR,
          $1:geo_lat::NUMBER(10,7),
          $1:geo_lon::NUMBER(10,7),
          $1:risk_score::NUMBER(5,2),
          CURRENT_TIMESTAMP(),                       -- _ingest_time
          'kinesis_firehose'                         -- _channel_name
      FROM @BRONZE.EWS_FIREHOSE_STAGE
  )
  FILE_FORMAT = ews_json_format;

-- =============================================================================
-- Get the SQS queue ARN for S3 event notification configuration
-- =============================================================================

SHOW PIPES LIKE 'EWS_FIREHOSE_PIPE' IN SCHEMA BRONZE;

-- NOTE: Record the value in the 'notification_channel' column.
-- This is the SQS queue ARN that must be configured as the destination
-- for S3 event notifications on the Firehose delivery bucket.

-- =============================================================================
-- Validation
-- =============================================================================

-- Check pipe status
SELECT SYSTEM$PIPE_STATUS('EWS_POC.BRONZE.EWS_FIREHOSE_PIPE');

-- After files land, check load history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'STREAMING_EVENTS',
    START_TIME => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC
LIMIT 10;
