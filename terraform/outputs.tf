# =============================================================================
# Outputs
# =============================================================================

output "database_name" {
  description = "EWS POC database name"
  value       = snowflake_database.ews_poc.name
}

output "storage_integration_name" {
  description = "Storage integration name (run DESC INTEGRATION for IAM details)"
  value       = snowflake_storage_integration.ews_s3.name
}

output "warehouse_names" {
  description = "All warehouse names"
  value = {
    ingest    = snowflake_warehouse.ingest.name
    transform = snowflake_warehouse.transform.name
    analytics = snowflake_warehouse.analytics.name
    ai        = snowflake_warehouse.ai.name
  }
}

output "role_names" {
  description = "All EWS roles"
  value = {
    admin      = snowflake_account_role.admin.name
    engineer   = snowflake_account_role.engineer.name
    analyst    = snowflake_account_role.analyst.name
    viewer     = snowflake_account_role.viewer.name
    compliance = snowflake_account_role.compliance.name
    service    = snowflake_account_role.service.name
  }
}

output "schemas" {
  description = "All schema names"
  value = {
    bronze        = snowflake_schema.bronze.name
    silver        = snowflake_schema.silver.name
    gold          = snowflake_schema.gold.name
    feature_store = snowflake_schema.feature_store.name
    analytics     = snowflake_schema.analytics.name
    staging       = snowflake_schema.staging.name
    governance    = snowflake_schema.governance.name
  }
}

output "iam_trust_policy_note" {
  description = "After apply, run DESC INTEGRATION to get Snowflake IAM user ARN and external ID for AWS trust policy"
  value       = "Run: DESC INTEGRATION ${snowflake_storage_integration.ews_s3.name}; -- then update AWS IAM trust policy"
}
