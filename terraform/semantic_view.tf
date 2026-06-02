# =============================================================================
# Semantic View for Cortex Analyst
# =============================================================================

resource "snowflake_unsafe_execute" "semantic_view" {
  execute = <<-SQL
    CREATE OR REPLACE SEMANTIC VIEW ${snowflake_database.ews_poc.name}.${snowflake_schema.analytics.name}.EWS_FRAUD_ANALYTICS
      TABLES (
        daily_summary AS ${snowflake_database.ews_poc.name}.${snowflake_schema.gold.name}.DAILY_MEMBER_SUMMARY
          PRIMARY KEY (member_id, txn_date)
          WITH SYNONYMS ('transactions', 'daily transactions')
          COMMENT = 'Daily aggregated transaction metrics per member',
        fraud_signals AS ${snowflake_database.ews_poc.name}.${snowflake_schema.gold.name}.FRAUD_SIGNALS
          PRIMARY KEY (signal_id)
          WITH SYNONYMS ('fraud', 'alerts', 'fraud alerts')
          COMMENT = 'Combined fraud alerts and high-risk events',
        members AS ${snowflake_database.ews_poc.name}.${snowflake_schema.gold.name}.MEMBER_ACTIVITY
          PRIMARY KEY (member_id)
          WITH SYNONYMS ('customers', 'members')
          COMMENT = 'Member profiles with 30-day activity summary',
        institutions AS ${snowflake_database.ews_poc.name}.${snowflake_schema.gold.name}.INSTITUTION_SUMMARY
          PRIMARY KEY (institution_id)
          WITH SYNONYMS ('banks', 'financial institutions')
          COMMENT = 'Aggregated metrics per financial institution'
      )
      RELATIONSHIPS (
        daily_summary_to_members AS daily_summary (member_id) REFERENCES members (member_id),
        daily_summary_to_institutions AS daily_summary (institution_id) REFERENCES institutions (institution_id),
        fraud_to_members AS fraud_signals (member_id) REFERENCES members (member_id),
        fraud_to_institutions AS fraud_signals (institution_id) REFERENCES institutions (institution_id)
      )
      DIMENSIONS (
        daily_summary.transaction_date AS txn_date COMMENT = 'Date of transactions',
        fraud_signals.signal_source AS signal_source COMMENT = 'ALERT or HIGH_RISK_EVENT',
        fraud_signals.severity AS severity COMMENT = 'HIGH or CRITICAL',
        members.risk_tier AS risk_tier COMMENT = 'Member risk: LOW, MEDIUM, HIGH, CRITICAL',
        institutions.institution_name AS institution_name COMMENT = 'Financial institution name',
        institutions.institution_type AS institution_type COMMENT = 'BANK, CREDIT_UNION, FINTECH, PROCESSOR',
        institutions.region AS region COMMENT = 'Geographic region'
      )
      METRICS (
        daily_summary.total_transactions AS SUM(txn_count) COMMENT = 'Total transaction count',
        daily_summary.total_volume AS SUM(total_amount) COMMENT = 'Total transaction volume USD',
        fraud_signals.total_fraud_signals AS COUNT(signal_id) COMMENT = 'Total fraud signals',
        fraud_signals.critical_signals AS COUNT(CASE WHEN severity = 'CRITICAL' THEN 1 END) COMMENT = 'Critical severity signals',
        members.total_members AS COUNT(DISTINCT member_id) COMMENT = 'Total members',
        institutions.total_institutions AS COUNT(DISTINCT institution_id) COMMENT = 'Total institutions'
      )
      COMMENT = 'EWS Fraud Analytics - Cortex Analyst semantic view'
      AI_SQL_GENERATION 'Round numeric results to 2 decimal places. Default time range is last 30 days.'
      AI_QUESTION_CATEGORIZATION 'Reject questions about individual member PII. Ask to clarify volume vs count if ambiguous.'
  SQL
  revert  = "DROP SEMANTIC VIEW IF EXISTS ${snowflake_database.ews_poc.name}.${snowflake_schema.analytics.name}.EWS_FRAUD_ANALYTICS"

  depends_on = [
    snowflake_unsafe_execute.dt_daily_member_summary,
    snowflake_unsafe_execute.dt_fraud_signals,
  ]
}
