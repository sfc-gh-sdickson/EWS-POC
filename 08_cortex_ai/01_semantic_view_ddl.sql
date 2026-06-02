/*=============================================================================
  EWS POC - UC13: Semantic View DDL (deployed to EWS_POC.ANALYTICS)
  
  This file documents the CREATE SEMANTIC VIEW statement that was deployed.
  The semantic view replaces the staged YAML approach and provides:
  - Native Snowflake object (no file management)
  - Queryable via SELECT FROM SEMANTIC_VIEW(...)
  - Compatible with Cortex Analyst REST API
  - Shareable via Snowflake Data Sharing
  
  SNOWFLAKE ADVANTAGE: Semantic Views are first-class database objects.
  No staging, no file uploads, no external semantic layer tool.
=============================================================================*/

-- This was deployed to EWS_POC.ANALYTICS.EWS_FRAUD_ANALYTICS
-- To view the current definition:
SELECT GET_DDL('SEMANTIC_VIEW', 'EWS_POC.ANALYTICS.EWS_FRAUD_ANALYTICS', TRUE);

-- To query using Cortex Analyst natural language:
-- Use semantic_view parameter in REST API: "EWS_POC.ANALYTICS.EWS_FRAUD_ANALYTICS"

-- Example direct query of the semantic view:
SELECT * FROM SEMANTIC_VIEW(
  EWS_POC.ANALYTICS.EWS_FRAUD_ANALYTICS
  METRICS fraud_signals.total_fraud_signals, fraud_signals.critical_signals
  DIMENSIONS fraud_signals.severity, institutions.region
);

-- Show all metrics available:
SHOW SEMANTIC METRICS IN EWS_POC.ANALYTICS.EWS_FRAUD_ANALYTICS;

-- Show all dimensions available:
SHOW SEMANTIC DIMENSIONS IN EWS_POC.ANALYTICS.EWS_FRAUD_ANALYTICS;
