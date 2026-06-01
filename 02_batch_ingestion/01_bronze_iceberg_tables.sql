/*=============================================================================
  EWS POC - UC01 Step 1: Bronze Iceberg Tables
  
  PURPOSE: Create Snowflake-managed Iceberg tables in the Bronze zone for
           raw data landing. These tables physically store data in EWS S3
           while Snowflake manages the Iceberg metadata and provides full DML.
  
  SNOWFLAKE ADVANTAGE: Full DML (INSERT, UPDATE, DELETE, MERGE) + Dynamic Table
  support + Time Travel on Iceberg tables — while data stays in EWS S3.
  Competitors offer read-only access to external Iceberg or require Delta format.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE SCHEMA BRONZE;
USE WAREHOUSE ews_ingest_wh;

-- =============================================================================
-- RAW_TRANSACTIONS: Core payment transaction records (delimited file source)
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE BRONZE.RAW_TRANSACTIONS (
    txn_id              VARCHAR(50)     NOT NULL,
    member_id           VARCHAR(20)     NOT NULL,
    institution_id      VARCHAR(20)     NOT NULL,
    txn_timestamp       TIMESTAMP_LTZ   NOT NULL,
    amount              NUMBER(15,2)    NOT NULL,
    currency_code       VARCHAR(3)      DEFAULT 'USD',
    txn_type            VARCHAR(20),        -- DEBIT, CREDIT, TRANSFER, ATM
    channel             VARCHAR(20),        -- ONLINE, POS, ATM, MOBILE, BRANCH
    merchant_category   VARCHAR(50),
    merchant_name       VARCHAR(200),
    merchant_country    VARCHAR(3),
    status              VARCHAR(20),        -- COMPLETED, PENDING, DECLINED, REVERSED
    auth_code           VARCHAR(20),
    card_last_four      VARCHAR(4),
    ip_address          VARCHAR(45),
    device_fingerprint  VARCHAR(100),
    risk_score          NUMBER(5,2),
    _loaded_at          TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    _source_file        VARCHAR(500)
)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'ews_iceberg_vol'
  BASE_LOCATION = 'bronze/raw_transactions/'
  COMMENT = 'Raw payment transactions from batch file ingestion (delimited format)';

-- =============================================================================
-- RAW_MEMBERS: Member/customer profile records (fixed-width file source)
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE BRONZE.RAW_MEMBERS (
    member_id           VARCHAR(20)     NOT NULL,
    institution_id      VARCHAR(20)     NOT NULL,
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    date_of_birth       DATE,
    ssn_hash            VARCHAR(64),        -- SHA-256 hashed SSN
    email               VARCHAR(200),
    phone               VARCHAR(20),
    address_line1       VARCHAR(200),
    address_line2       VARCHAR(200),
    city                VARCHAR(100),
    state_code          VARCHAR(2),
    zip_code            VARCHAR(10),
    country_code        VARCHAR(3)      DEFAULT 'US',
    member_since        DATE,
    status              VARCHAR(20),        -- ACTIVE, SUSPENDED, CLOSED
    risk_tier           VARCHAR(10),        -- LOW, MEDIUM, HIGH, CRITICAL
    kyc_verified        BOOLEAN         DEFAULT FALSE,
    last_activity_date  DATE,
    _loaded_at          TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    _source_file        VARCHAR(500)
)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'ews_iceberg_vol'
  BASE_LOCATION = 'bronze/raw_members/'
  COMMENT = 'Raw member profiles from batch file ingestion (fixed-width format)';

-- =============================================================================
-- RAW_ALERTS: Fraud and compliance alert records (EBCDIC-converted source)
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE BRONZE.RAW_ALERTS (
    alert_id            VARCHAR(50)     NOT NULL,
    member_id           VARCHAR(20)     NOT NULL,
    institution_id      VARCHAR(20)     NOT NULL,
    alert_timestamp     TIMESTAMP_LTZ   NOT NULL,
    alert_type          VARCHAR(50),        -- FRAUD_SUSPECTED, AML_SAR, VELOCITY, IDENTITY
    severity            VARCHAR(10),        -- LOW, MEDIUM, HIGH, CRITICAL
    alert_source        VARCHAR(50),        -- RULE_ENGINE, ML_MODEL, MANUAL, THIRD_PARTY
    description         VARCHAR(1000),
    related_txn_id      VARCHAR(50),
    rule_id             VARCHAR(50),
    confidence_score    NUMBER(5,4),        -- 0.0000 to 1.0000
    status              VARCHAR(20),        -- OPEN, INVESTIGATING, RESOLVED, FALSE_POSITIVE
    assigned_to         VARCHAR(100),
    resolution_notes    VARCHAR(2000),
    resolved_at         TIMESTAMP_LTZ,
    _loaded_at          TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    _source_file        VARCHAR(500)
)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'ews_iceberg_vol'
  BASE_LOCATION = 'bronze/raw_alerts/'
  COMMENT = 'Raw fraud/compliance alerts from EBCDIC mainframe files';

-- =============================================================================
-- RAW_INSTITUTIONS: Financial institution reference data
-- =============================================================================

CREATE OR REPLACE ICEBERG TABLE BRONZE.RAW_INSTITUTIONS (
    institution_id      VARCHAR(20)     NOT NULL,
    institution_name    VARCHAR(200)    NOT NULL,
    institution_type    VARCHAR(50),        -- BANK, CREDIT_UNION, FINTECH, PROCESSOR
    routing_number      VARCHAR(9),
    charter_type        VARCHAR(20),
    regulatory_body     VARCHAR(50),        -- OCC, FDIC, NCUA, STATE
    state_code          VARCHAR(2),
    region              VARCHAR(20),        -- NORTHEAST, SOUTHEAST, MIDWEST, WEST, SOUTHWEST
    asset_size_tier     VARCHAR(20),        -- SMALL, MEDIUM, LARGE, MEGA
    ews_member_since    DATE,
    status              VARCHAR(20),        -- ACTIVE, SUSPENDED, TERMINATED
    _loaded_at          TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    _source_file        VARCHAR(500)
)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'ews_iceberg_vol'
  BASE_LOCATION = 'bronze/raw_institutions/'
  COMMENT = 'Financial institution reference data';

-- =============================================================================
-- Validation
-- =============================================================================

SHOW ICEBERG TABLES IN SCHEMA BRONZE;
