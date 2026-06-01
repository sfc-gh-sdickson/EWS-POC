/*=============================================================================
  EWS POC - UC02 Step 1: Snowpipe Streaming PIPE Object
  
  PURPOSE: Create the PIPE object that defines the ingestion target for the
           high-performance Snowpipe Streaming SDK. The PIPE handles schema
           enforcement and transforms on the server side.
  
  SNOWFLAKE ADVANTAGE: The PIPE object replaces Kafka Connect + Schema Registry.
  Server-side schema enforcement means the client just sends data — no schema
  validation code needed in the application. One PIPE = one ingestion target.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE SCHEMA BRONZE;

-- =============================================================================
-- PIPE: High-performance streaming ingest into Bronze Iceberg
-- MATCH_BY_COLUMN_NAME: SDK sends named fields, PIPE maps to table columns
-- =============================================================================

CREATE OR REPLACE PIPE BRONZE.EWS_EVENT_PIPE
AS COPY INTO BRONZE.STREAMING_EVENTS
  FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- =============================================================================
-- Validation
-- =============================================================================

SHOW PIPES IN SCHEMA BRONZE;
DESC PIPE BRONZE.EWS_EVENT_PIPE;
