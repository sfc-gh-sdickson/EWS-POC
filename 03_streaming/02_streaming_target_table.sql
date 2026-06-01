/*=============================================================================
  EWS POC - UC02 Step 2: Streaming Target Table (Bronze Iceberg)
  
  PURPOSE: Create the Bronze Iceberg table that receives real-time streaming
           events via Snowpipe Streaming SDK. Designed for event-time ordered
           data with deduplication support.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE SCHEMA BRONZE;

-- =============================================================================
-- STREAMING_EVENTS: Target table for real-time event ingest
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE BRONZE.STREAMING_EVENTS (
    event_id            VARCHAR(50)     NOT NULL,
    event_time          TIMESTAMP_LTZ   NOT NULL,
    event_type          VARCHAR(50)     NOT NULL,   -- TXN, ALERT, LOGIN, CARD_SWIPE
    member_id           VARCHAR(20)     NOT NULL,
    institution_id      VARCHAR(20),
    payload             VARIANT,                    -- Full event payload (semi-structured)
    amount              NUMBER(15,2),
    channel             VARCHAR(20),
    device_id           VARCHAR(100),
    ip_address          VARCHAR(45),
    geo_lat             NUMBER(10,7),
    geo_lon             NUMBER(10,7),
    risk_score          NUMBER(5,2),
    _ingest_time        TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    _channel_name       VARCHAR(100),
    _offset_token       VARCHAR(100)
)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'ews_iceberg_vol'
  BASE_LOCATION = 'bronze/streaming_events/'
  COMMENT = 'Real-time streaming events via Snowpipe Streaming SDK (high-performance)';

-- =============================================================================
-- Validation
-- =============================================================================

DESC TABLE BRONZE.STREAMING_EVENTS;
