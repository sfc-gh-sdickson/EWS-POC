/*=============================================================================
  EWS POC - UC10-11: Self-Service Analytics, Governance, Data Sharing
=============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE EWS_POC;

-- =============================================================================
-- Horizon: Tag-Based Governance (no external tool needed)
-- =============================================================================

USE SCHEMA GOVERNANCE;

CREATE OR REPLACE TAG GOVERNANCE.SENSITIVITY
  ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'PII', 'RESTRICTED'
  COMMENT = 'Data sensitivity classification';

CREATE OR REPLACE TAG GOVERNANCE.DATA_DOMAIN
  ALLOWED_VALUES 'MEMBER', 'TRANSACTION', 'ALERT', 'INSTITUTION'
  COMMENT = 'Business domain classification';

-- Apply tags to sensitive columns
ALTER TABLE SILVER.ENRICHED_MEMBERS MODIFY COLUMN ssn_hash
  SET TAG GOVERNANCE.SENSITIVITY = 'PII';
ALTER TABLE SILVER.ENRICHED_MEMBERS MODIFY COLUMN email
  SET TAG GOVERNANCE.SENSITIVITY = 'PII';
ALTER TABLE SILVER.ENRICHED_MEMBERS MODIFY COLUMN phone_normalized
  SET TAG GOVERNANCE.SENSITIVITY = 'PII';
ALTER TABLE SILVER.ENRICHED_MEMBERS MODIFY COLUMN date_of_birth
  SET TAG GOVERNANCE.SENSITIVITY = 'PII';

-- =============================================================================
-- Row Access Policy: Regional data segmentation
-- =============================================================================

CREATE OR REPLACE ROW ACCESS POLICY GOVERNANCE.INSTITUTION_REGION_ACCESS
  AS (region_val VARCHAR) RETURNS BOOLEAN ->
    CURRENT_ROLE() IN ('EWS_ADMIN', 'EWS_COMPLIANCE')
    OR region_val IN (
        SELECT value FROM TABLE(SPLIT_TO_TABLE(
            COALESCE(CURRENT_SESSION()::VARIANT:allowed_regions::VARCHAR, 'ALL'), ','
        ))
    )
    OR 'ALL' IN (
        SELECT value FROM TABLE(SPLIT_TO_TABLE(
            COALESCE(CURRENT_SESSION()::VARIANT:allowed_regions::VARCHAR, 'ALL'), ','
        ))
    );

-- =============================================================================
-- Dynamic Data Masking: Auto-mask PII for non-privileged roles
-- =============================================================================

CREATE OR REPLACE MASKING POLICY GOVERNANCE.MASK_PII
  AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('EWS_ADMIN', 'EWS_COMPLIANCE') THEN val
        ELSE '***MASKED***'
    END;

-- Apply masking to PII columns
ALTER TABLE SILVER.ENRICHED_MEMBERS MODIFY COLUMN email
  SET MASKING POLICY GOVERNANCE.MASK_PII;

-- =============================================================================
-- SSO and Network Policy for BI Tools
-- =============================================================================

CREATE OR REPLACE NETWORK POLICY ews_bi_network_policy
  ALLOWED_IP_LIST = (
    '0.0.0.0/0'  -- Replace with actual Tableau/Power BI IP ranges
  )
  COMMENT = 'Network policy for BI tool connectivity (Tableau, Power BI)';

-- =============================================================================
-- Zero-Copy Data Sharing (uniquely Snowflake)
-- =============================================================================

CREATE OR REPLACE SHARE ews_fraud_signals_share
  COMMENT = 'EWS Fraud Signals - shared to partner institutions';

GRANT USAGE ON DATABASE EWS_POC TO SHARE ews_fraud_signals_share;
GRANT USAGE ON SCHEMA EWS_POC.GOLD TO SHARE ews_fraud_signals_share;
GRANT SELECT ON TABLE EWS_POC.GOLD.FRAUD_SIGNALS TO SHARE ews_fraud_signals_share;
GRANT SELECT ON TABLE EWS_POC.GOLD.INSTITUTION_SUMMARY TO SHARE ews_fraud_signals_share;

-- Add consumer accounts
-- ALTER SHARE ews_fraud_signals_share ADD ACCOUNTS = <consumer_account>;

-- =============================================================================
-- Marketplace: Consume vendor data (one command)
-- =============================================================================

-- Example: Mount a sanctions list from Snowflake Marketplace
-- CREATE DATABASE ews_vendor_sanctions FROM SHARE <vendor_account>.sanctions_data_share;
-- CREATE DATABASE ews_vendor_geolocation FROM SHARE <vendor_account>.geolocation_share;

SHOW SHARES;
