# =============================================================================
# EWS POC Database and Schemas
# =============================================================================

resource "snowflake_database" "ews_poc" {
  name    = "EWS_POC"
  comment = "Early Warning Services Proof of Concept - Snowflake compute-only on Iceberg"
}

resource "snowflake_schema" "bronze" {
  database = snowflake_database.ews_poc.name
  name     = "BRONZE"
  comment  = "Raw ingestion zone - batch files and streaming events land here"
}

resource "snowflake_schema" "silver" {
  database = snowflake_database.ews_poc.name
  name     = "SILVER"
  comment  = "Cleansed/enriched zone - Dynamic Tables transform Bronze data"
}

resource "snowflake_schema" "gold" {
  database = snowflake_database.ews_poc.name
  name     = "GOLD"
  comment  = "Curated analytics zone - aggregated and business-ready tables"
}

resource "snowflake_schema" "feature_store" {
  database = snowflake_database.ews_poc.name
  name     = "FEATURE_STORE"
  comment  = "Online and offline feature store"
}

resource "snowflake_schema" "analytics" {
  database = snowflake_database.ews_poc.name
  name     = "ANALYTICS"
  comment  = "Semantic layer and BI views"
}

resource "snowflake_schema" "staging" {
  database = snowflake_database.ews_poc.name
  name     = "STAGING"
  comment  = "Dead letter, quarantine, temp processing"
}

resource "snowflake_schema" "governance" {
  database = snowflake_database.ews_poc.name
  name     = "GOVERNANCE"
  comment  = "Tags, policies, DMFs"
}
