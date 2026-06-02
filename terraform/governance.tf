# =============================================================================
# Governance: Tags, Masking Policies, Data Share
# =============================================================================

resource "snowflake_tag" "sensitivity" {
  database = snowflake_database.ews_poc.name
  schema   = snowflake_schema.governance.name
  name     = "SENSITIVITY"
  comment  = "Data sensitivity classification"
}

resource "snowflake_tag" "data_domain" {
  database = snowflake_database.ews_poc.name
  schema   = snowflake_schema.governance.name
  name     = "DATA_DOMAIN"
  comment  = "Business domain classification"
}

resource "snowflake_masking_policy" "mask_pii" {
  database         = snowflake_database.ews_poc.name
  schema           = snowflake_schema.governance.name
  name             = "MASK_PII"
  signature {
    column {
      name = "val"
      type = "VARCHAR"
    }
  }
  masking_expression = <<-SQL
    CASE
      WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'EWS_ADMIN') THEN val
      ELSE '***MASKED***'
    END
  SQL
  return_data_type = "VARCHAR"
  comment          = "Masks PII for non-privileged roles"
}

resource "snowflake_masking_policy" "mask_email" {
  database         = snowflake_database.ews_poc.name
  schema           = snowflake_schema.governance.name
  name             = "MASK_EMAIL"
  signature {
    column {
      name = "val"
      type = "VARCHAR"
    }
  }
  masking_expression = <<-SQL
    CASE
      WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'EWS_ADMIN') THEN val
      ELSE REGEXP_REPLACE(val, '(.)[^@]*(@.*)', '\\1***\\2')
    END
  SQL
  return_data_type = "VARCHAR"
  comment          = "Partially masks email addresses"
}

resource "snowflake_share" "fraud_signals" {
  name    = "EWS_FRAUD_SIGNALS_SHARE"
  comment = "EWS Fraud Signals - shared to partner institutions"
}
