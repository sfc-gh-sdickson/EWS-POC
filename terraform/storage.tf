# =============================================================================
# Storage Integration and External Volume for Iceberg
# =============================================================================

resource "snowflake_storage_integration" "ews_s3" {
  name                      = "EWS_S3_INTEGRATION"
  type                      = "EXTERNAL_STAGE"
  storage_provider          = "S3"
  storage_aws_role_arn      = var.aws_iam_role_arn
  enabled                   = true
  storage_allowed_locations = ["s3://${var.s3_bucket_name}/"]
  comment                   = "EWS POC: Storage integration for EWS-owned S3 bucket (Iceberg data lake)"
}

# External Volume (managed via SQL - Terraform provider may not support yet)
# Using snowflake_unsafe_execute for resources not yet in the provider
resource "snowflake_unsafe_execute" "external_volume" {
  execute = <<-SQL
    CREATE OR REPLACE EXTERNAL VOLUME ews_iceberg_vol
      STORAGE_LOCATIONS = (
        (
          NAME = 'ews_primary'
          STORAGE_PROVIDER = 'S3'
          STORAGE_BASE_URL = 's3://${var.s3_bucket_name}/${var.s3_iceberg_path}'
          STORAGE_AWS_ROLE_ARN = '${var.aws_iam_role_arn}'
        )
      )
      ALLOW_WRITES = TRUE
  SQL
  revert  = "DROP EXTERNAL VOLUME IF EXISTS ews_iceberg_vol"
}
