/*=============================================================================
  EWS POC - UC01 Step 3: External Stages
  
  PURPOSE: Create external stages pointing to S3 landing zones where EWS
           file drops occur. Each stage maps to a specific file type/zone.
  
  SNOWFLAKE ADVANTAGE: Stages integrate with storage integrations for secure,
  credential-free access. Support directory tables for file metadata queries.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE SCHEMA BRONZE;

-- =============================================================================
-- Landing Zone: Delimited transaction files
-- =============================================================================

CREATE OR REPLACE STAGE ews_txn_landing_stage
  STORAGE_INTEGRATION = ews_s3_integration
  URL = 's3://<EWS_BUCKET_NAME>-landing/transactions/'
  FILE_FORMAT = ews_delimited_format
  DIRECTORY = (ENABLE = TRUE AUTO_REFRESH = TRUE)
  COMMENT = 'Landing zone for delimited transaction files';

-- =============================================================================
-- Landing Zone: Fixed-width member profile files
-- =============================================================================

CREATE OR REPLACE STAGE ews_member_landing_stage
  STORAGE_INTEGRATION = ews_s3_integration
  URL = 's3://<EWS_BUCKET_NAME>-landing/members/'
  FILE_FORMAT = ews_fixed_width_format
  DIRECTORY = (ENABLE = TRUE AUTO_REFRESH = TRUE)
  COMMENT = 'Landing zone for fixed-width member profile files';

-- =============================================================================
-- Landing Zone: EBCDIC-converted alert files from mainframe
-- =============================================================================

CREATE OR REPLACE STAGE ews_alert_landing_stage
  STORAGE_INTEGRATION = ews_s3_integration
  URL = 's3://<EWS_BUCKET_NAME>-landing/alerts/'
  FILE_FORMAT = ews_ebcdic_converted_format
  DIRECTORY = (ENABLE = TRUE AUTO_REFRESH = TRUE)
  COMMENT = 'Landing zone for EBCDIC-converted mainframe alert files';

-- =============================================================================
-- Landing Zone: Institution reference data
-- =============================================================================

CREATE OR REPLACE STAGE ews_institution_landing_stage
  STORAGE_INTEGRATION = ews_s3_integration
  URL = 's3://<EWS_BUCKET_NAME>-landing/institutions/'
  FILE_FORMAT = ews_delimited_format
  DIRECTORY = (ENABLE = TRUE AUTO_REFRESH = TRUE)
  COMMENT = 'Landing zone for institution reference files';

-- =============================================================================
-- Validation: List files in stages
-- =============================================================================

-- LIST @ews_txn_landing_stage;
-- LIST @ews_member_landing_stage;
-- LIST @ews_alert_landing_stage;

-- Directory table query (Snowflake-unique feature)
-- SELECT * FROM DIRECTORY(@ews_txn_landing_stage);

SHOW STAGES IN SCHEMA BRONZE;
