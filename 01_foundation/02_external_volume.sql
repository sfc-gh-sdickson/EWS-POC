/*=============================================================================
  EWS POC - Step 1.2: External Volume for Iceberg Tables
  
  PURPOSE: Create an external volume that allows Snowflake-managed Iceberg
           tables to store data and metadata in EWS-owned S3. This is the
           foundation for the entire compute-only architecture.
  
  SNOWFLAKE ADVANTAGE: External Volume with ALLOW_WRITES=TRUE gives Snowflake
  full DML capabilities (INSERT, UPDATE, DELETE, MERGE) on Iceberg tables
  while keeping ALL data physically in EWS S3. Competitors cannot offer
  full engine parity on externally-owned Iceberg storage.
  
  PREREQUISITES:
    - Storage integration (01_storage_integration.sql) created and configured
    - AWS IAM trust policy updated with Snowflake's ARN and External ID
    - S3 bucket exists with the /iceberg/ prefix directory
=============================================================================*/

USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- External Volume: EWS Iceberg Data Lake
-- All Iceberg tables in this POC will reference this volume
-- Data physically resides in EWS S3 — Snowflake provides compute only
-- =============================================================================

CREATE OR REPLACE EXTERNAL VOLUME ews_iceberg_vol
  STORAGE_LOCATIONS = (
    (
      NAME = 'ews_primary'
      STORAGE_PROVIDER = 'S3'
      STORAGE_BASE_URL = 's3://<EWS_BUCKET_NAME>/iceberg/'
      STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<EWS_AWS_ACCOUNT_ID>:role/<EWS_SNOWFLAKE_ROLE>'
    )
  )
  ALLOW_WRITES = TRUE;

-- =============================================================================
-- Verify the external volume and storage access
-- =============================================================================

DESC EXTERNAL VOLUME ews_iceberg_vol;

-- Verify Snowflake can read/write to the storage location
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('ews_iceberg_vol');

-- =============================================================================
-- Set as default external volume at account level (optional)
-- This means Iceberg tables can omit EXTERNAL_VOLUME in DDL
-- =============================================================================

-- ALTER ACCOUNT SET DEFAULT_EXTERNAL_VOLUME = 'ews_iceberg_vol';

-- =============================================================================
-- Validation
-- =============================================================================

SHOW EXTERNAL VOLUMES LIKE 'ews_iceberg%';
