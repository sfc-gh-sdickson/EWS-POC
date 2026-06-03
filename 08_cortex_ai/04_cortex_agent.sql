/*=============================================================================
  EWS POC - EXTRA: Cortex Agent (Structured + Unstructured AI)
  
  PURPOSE: Multi-tool agent that combines Cortex Analyst (semantic view NL-to-SQL)
  with Cortex Search (alert text search) for unified fraud investigation.
  
  SNOWFLAKE ADVANTAGE: Native agent orchestration over both structured and
  unstructured data. No LangChain. No external LLM. No vector DB. No RAG infra.
  All within Snowflake's governance boundary.
=============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE EWS_POC;
USE WAREHOUSE ews_ai_wh;

-- =============================================================================
-- 1. CORTEX SEARCH SERVICE: Index alert descriptions for semantic search
-- =============================================================================

-- Note: Cortex Search requires change tracking. Since ENRICHED_ALERTS is a 
-- Dynamic Table with FULL refresh (no change tracking), we materialize a copy.
CREATE OR REPLACE TABLE EWS_POC.ANALYTICS.ALERTS_FOR_SEARCH AS
SELECT alert_id, member_id, institution_id, alert_type, severity,
       description, alert_timestamp::STRING AS alert_time
FROM EWS_POC.SILVER.ENRICHED_ALERTS;

CREATE OR REPLACE CORTEX SEARCH SERVICE EWS_POC.ANALYTICS.ALERT_SEARCH
  ON description
  WAREHOUSE = ews_ai_wh
  TARGET_LAG = '1 hour'
  AS (
    SELECT alert_id, member_id, institution_id, alert_type, severity,
           description, alert_time
    FROM EWS_POC.ANALYTICS.ALERTS_FOR_SEARCH
  );

-- =============================================================================
-- 2. CORTEX AGENT: Combines Semantic View + Search Service
-- =============================================================================

CREATE OR REPLACE AGENT EWS_POC.ANALYTICS.EWS_FRAUD_AGENT
  COMMENT = 'EWS Fraud Analytics Agent - combines structured analytics with alert search'
  FROM SPECIFICATION
$$
models:
  orchestration: auto

orchestration:
  budget:
    seconds: 300
    tokens: 200000

instructions:
  orchestration: "You are an EWS (Early Warning Services) fraud analytics assistant. You help analysts investigate fraud patterns, member risk, and institutional activity. Use query_fraud_analytics for metrics, counts, trends, and aggregations. Use search_alerts when the user asks about specific alert descriptions or wants to find alerts by keyword."
  response: "Provide clear, concise answers. Round numbers to 2 decimal places. When showing data, format it as tables."
  sample_questions:
    - question: "How many fraud signals do we have by severity?"
    - question: "Which institutions have the most critical alerts?"
    - question: "Search alerts for account takeover activity"

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "query_fraud_analytics"
      description: "Query structured fraud analytics data including transaction volumes, fraud signal counts, member risk profiles, and institution metrics. Use for questions about counts, totals, trends, and aggregations over Gold-layer curated tables."
  - tool_spec:
      type: "cortex_search"
      name: "search_alerts"
      description: "Search alert descriptions and investigation notes. Use when the user asks about specific alert content, wants to find alerts by keyword or pattern, or needs context about what fraud was detected."

tool_resources:
  query_fraud_analytics:
    semantic_view: "EWS_POC.ANALYTICS.EWS_FRAUD_ANALYTICS"
  search_alerts:
    name: "EWS_POC.ANALYTICS.ALERT_SEARCH"
    max_results: "5"
$$;

-- =============================================================================
-- 3. TEST: Invoke the agent
-- =============================================================================

-- Test via SQL (basic check):
-- SELECT SNOWFLAKE.CORTEX.AGENT('EWS_POC.ANALYTICS.EWS_FRAUD_AGENT', 'How many fraud signals by severity?');
