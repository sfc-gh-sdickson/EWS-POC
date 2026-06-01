/*=============================================================================
  EWS POC - Step 1.1: Storage Integration
  
  PURPOSE: Create an AWS S3 storage integration allowing Snowflake to access
           EWS-owned S3 buckets for Iceberg table data and file staging.
  
  SNOWFLAKE ADVANTAGE: Single integration covers all access patterns (stages,
  external volumes, Iceberg metadata). Competitors require separate IAM configs
  for each service (EMR, Redshift Spectrum, Glue, etc.)
  
  PREREQUISITES:
    - ACCOUNTADMIN role or CREATE INTEGRATION privilege
    - AWS IAM Role with trust policy for Snowflake
    - EWS S3 bucket(s) created and accessible
  
  INSTRUCTIONS:
    1. Replace <EWS_AWS_ACCOUNT_ID> with the EWS AWS account ID
    2. Replace <EWS_SNOWFLAKE_ROLE> with the IAM role name
    3. Replace <EWS_BUCKET_NAME> with the actual S3 bucket name
    4. Execute this script
    5. Run DESC INTEGRATION to get the Snowflake IAM user ARN and External ID
    6. Update the AWS IAM trust policy with those values
=============================================================================*/

USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- Storage Integration for EWS S3 Buckets
-- Grants Snowflake read/write access to EWS-owned storage
-- =============================================================================

CREATE OR REPLACE STORAGE INTEGRATION ews_s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<EWS_AWS_ACCOUNT_ID>:role/<EWS_SNOWFLAKE_ROLE>'
  ENABLED = TRUE
  STORAGE_ALLOWED_LOCATIONS = (
    's3://<EWS_BUCKET_NAME>/',
    's3://<EWS_BUCKET_NAME>-landing/',
    's3://<EWS_BUCKET_NAME>-archive/'
  )
  COMMENT = 'EWS POC: Storage integration for EWS-owned S3 buckets (Iceberg data lake)';

-- =============================================================================
-- Retrieve integration details for AWS IAM trust policy configuration
-- =============================================================================

DESC INTEGRATION ews_s3_integration;

-- NOTE: Record these values from the output:
--   STORAGE_AWS_IAM_USER_ARN  -> Use in IAM trust policy Principal
--   STORAGE_AWS_EXTERNAL_ID   -> Use in IAM trust policy Condition

/*
  AWS IAM Trust Policy Template (apply to the role specified above):
  
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "<STORAGE_AWS_IAM_USER_ARN from DESC output>"
        },
        "Action": "sts:AssumeRole",
        "Condition": {
          "StringEquals": {
            "sts:ExternalId": "<STORAGE_AWS_EXTERNAL_ID from DESC output>"
          }
        }
      }
    ]
  }
  
  Required IAM Policy (attach to the role):
  
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource": [
          "arn:aws:s3:::<EWS_BUCKET_NAME>/*",
          "arn:aws:s3:::<EWS_BUCKET_NAME>",
          "arn:aws:s3:::<EWS_BUCKET_NAME>-landing/*",
          "arn:aws:s3:::<EWS_BUCKET_NAME>-landing"
        ]
      }
    ]
  }
*/

-- =============================================================================
-- Validation: Verify the integration is active
-- =============================================================================

SHOW INTEGRATIONS LIKE 'ews_s3%';
