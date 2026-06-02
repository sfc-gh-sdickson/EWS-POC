# =============================================================================
# RBAC Role Hierarchy
# =============================================================================

resource "snowflake_account_role" "admin" {
  name    = "EWS_ADMIN"
  comment = "Full administrative access to EWS POC"
}

resource "snowflake_account_role" "engineer" {
  name    = "EWS_ENGINEER"
  comment = "Data engineering - create/modify pipelines, DDL on all schemas"
}

resource "snowflake_account_role" "analyst" {
  name    = "EWS_ANALYST"
  comment = "Business analyst - read Gold/Analytics, run queries, use Cortex Analyst"
}

resource "snowflake_account_role" "viewer" {
  name    = "EWS_VIEWER"
  comment = "Dashboard viewer - read-only access to Gold zone views"
}

resource "snowflake_account_role" "compliance" {
  name    = "EWS_COMPLIANCE"
  comment = "Compliance officer - read all schemas, governance admin"
}

resource "snowflake_account_role" "service" {
  name    = "EWS_SERVICE"
  comment = "Service account - streaming ingest, scheduled tasks"
}

# =============================================================================
# Role Hierarchy (parent-child grants)
# =============================================================================

resource "snowflake_grant_account_role" "viewer_to_analyst" {
  role_name        = snowflake_account_role.viewer.name
  parent_role_name = snowflake_account_role.analyst.name
}

resource "snowflake_grant_account_role" "analyst_to_engineer" {
  role_name        = snowflake_account_role.analyst.name
  parent_role_name = snowflake_account_role.engineer.name
}

resource "snowflake_grant_account_role" "engineer_to_admin" {
  role_name        = snowflake_account_role.engineer.name
  parent_role_name = snowflake_account_role.admin.name
}

resource "snowflake_grant_account_role" "compliance_to_admin" {
  role_name        = snowflake_account_role.compliance.name
  parent_role_name = snowflake_account_role.admin.name
}

resource "snowflake_grant_account_role" "service_to_admin" {
  role_name        = snowflake_account_role.service.name
  parent_role_name = snowflake_account_role.admin.name
}

resource "snowflake_grant_account_role" "admin_to_sysadmin" {
  role_name        = snowflake_account_role.admin.name
  parent_role_name = "SYSADMIN"
}

# =============================================================================
# Database Grants
# =============================================================================

resource "snowflake_grant_privileges_to_account_role" "engineer_db_usage" {
  account_role_name = snowflake_account_role.engineer.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.ews_poc.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_db_usage" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.ews_poc.name
  }
}

# =============================================================================
# Warehouse Grants
# =============================================================================

resource "snowflake_grant_privileges_to_account_role" "engineer_all_wh" {
  for_each          = toset(["EWS_INGEST_WH", "EWS_TRANSFORM_WH", "EWS_ANALYTICS_WH", "EWS_AI_WH"])
  account_role_name = snowflake_account_role.engineer.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = each.value
  }
  depends_on = [
    snowflake_warehouse.ingest,
    snowflake_warehouse.transform,
    snowflake_warehouse.analytics,
    snowflake_warehouse.ai,
  ]
}

resource "snowflake_grant_privileges_to_account_role" "analyst_analytics_wh" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.analytics.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_ai_wh" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.ai.name
  }
}
