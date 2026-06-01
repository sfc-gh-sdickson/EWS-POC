/*=============================================================================
  EWS POC - UC14: Agentic AI + Git Integration
  
  PURPOSE: Use Cortex LLM functions to generate pipeline code and DQ rules,
  then commit artifacts to a Snowflake-connected Git repository.
  
  SNOWFLAKE ADVANTAGE: LLMs callable FROM SQL. No API gateway. No model
  hosting. No GPU cluster. All within governance boundary.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE WAREHOUSE ews_ai_wh;

-- =============================================================================
-- 1. AGENTIC PIPELINE GENERATION: LLM writes transformation code
-- =============================================================================

-- Ask the LLM to generate a Dynamic Table based on table schema
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'claude-3-5-sonnet',
    'You are a Snowflake data engineer. Given this Bronze table schema:
    
    CREATE TABLE BRONZE.RAW_TRANSACTIONS (
        txn_id VARCHAR(50) NOT NULL,
        member_id VARCHAR(20) NOT NULL,
        institution_id VARCHAR(20) NOT NULL,
        txn_timestamp TIMESTAMP_LTZ NOT NULL,
        amount NUMBER(15,2) NOT NULL,
        currency_code VARCHAR(3),
        txn_type VARCHAR(20),
        channel VARCHAR(20),
        risk_score NUMBER(5,2)
    );
    
    Generate a CREATE DYNAMIC TABLE statement for the Silver zone that:
    1. Removes nulls in required fields
    2. Deduplicates on txn_id (keep latest)
    3. Standardizes string fields to UPPER
    4. Adds a computed risk_category column (LOW/MEDIUM/HIGH/CRITICAL)
    5. Uses INCREMENTAL refresh mode with TARGET_LAG = DOWNSTREAM
    
    Output ONLY the SQL, no explanation.'
) AS generated_pipeline;

-- =============================================================================
-- 2. AGENTIC DQ RULES: LLM suggests Data Metric Functions
-- =============================================================================

SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'claude-3-5-sonnet',
    'You are a Snowflake data quality engineer. Given this table:
    
    GOLD.DAILY_MEMBER_SUMMARY with columns:
    - member_id (VARCHAR), txn_date (DATE), txn_count (NUMBER)
    - total_amount (NUMBER), avg_amount (NUMBER), max_risk_score (NUMBER)
    
    Generate 3 Data Metric Function (DMF) definitions that would catch
    data quality issues. Use CREATE DATA METRIC FUNCTION syntax.
    Each should check a different quality dimension (freshness, volume, validity).
    
    Output ONLY the SQL.'
) AS generated_dq_rules;

-- =============================================================================
-- 3. GIT INTEGRATION: Native version control (no Jenkins/GitHub Actions)
-- =============================================================================

-- Create API integration for GitHub
CREATE OR REPLACE API INTEGRATION ews_github_api_int
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/ews-org/')
  ENABLED = TRUE
  COMMENT = 'GitHub API integration for EWS POC artifacts';

-- Create secret for Git credentials
CREATE OR REPLACE SECRET EWS_POC.STAGING.EWS_GIT_SECRET
  TYPE = password
  USERNAME = '<GITHUB_USER>'
  PASSWORD = '<GITHUB_PAT>'
  COMMENT = 'GitHub Personal Access Token for EWS POC repo';

-- Create Git repository connection
CREATE OR REPLACE GIT REPOSITORY EWS_POC.STAGING.POC_REPO
  API_INTEGRATION = ews_github_api_int
  GIT_CREDENTIALS = EWS_POC.STAGING.EWS_GIT_SECRET
  ORIGIN = 'https://github.com/ews-org/poc-artifacts.git'
  COMMENT = 'EWS POC artifact repository for human-in-the-loop review';

-- Fetch latest from remote
ALTER GIT REPOSITORY EWS_POC.STAGING.POC_REPO FETCH;

-- List repository contents
SHOW GIT BRANCHES IN GIT REPOSITORY EWS_POC.STAGING.POC_REPO;

-- =============================================================================
-- 4. CORTEX AGENT (multi-step AI orchestration)
-- =============================================================================

-- Note: Cortex Agent DDL syntax - verify against latest docs
-- CREATE OR REPLACE CORTEX AGENT EWS_POC.ANALYTICS.DATA_ENGINEERING_AGENT
--   LLM = 'claude-3-5-sonnet'
--   TOOLS = (...)
--   COMMENT = 'Agentic data engineering assistant for EWS POC';
