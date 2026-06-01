/*=============================================================================
  EWS POC - Step 1.3: Database, Schemas, and Warehouses
  
  PURPOSE: Create the EWS POC database with zone-based schemas following the
           Medallion architecture, plus workload-specific warehouses.
  
  SNOWFLAKE ADVANTAGE: Independent warehouses per workload enable true elastic
  scaling without resource contention. Ingest, transform, analytics, and AI
  workloads each get dedicated compute that auto-scales independently.
  Competitors require shared clusters with WLM/scheduler tuning.
  
  PREREQUISITES:
    - ACCOUNTADMIN or SYSADMIN role
    - External volume created (02_external_volume.sql)
=============================================================================*/

USE ROLE SYSADMIN;

-- =============================================================================
-- Database
-- =============================================================================

CREATE OR REPLACE DATABASE EWS_POC
  COMMENT = 'Early Warning Services Proof of Concept - Snowflake compute-only on Iceberg';

-- =============================================================================
-- Schemas (Medallion Architecture + Feature Store + Governance)
-- =============================================================================

-- Bronze: Raw ingestion landing zone (batch + streaming)
CREATE OR REPLACE SCHEMA EWS_POC.BRONZE
  COMMENT = 'Raw ingestion zone - batch files and streaming events land here';

-- Silver: Cleansed, enriched, deduplicated data (Dynamic Tables)
CREATE OR REPLACE SCHEMA EWS_POC.SILVER
  COMMENT = 'Cleansed/enriched zone - Dynamic Tables transform Bronze data';

-- Gold: Curated, aggregated, business-ready data (Dynamic Tables)
CREATE OR REPLACE SCHEMA EWS_POC.GOLD
  COMMENT = 'Curated analytics zone - aggregated and business-ready tables';

-- Feature Store: Online (streaming-fed) and Offline (time-travel) features
CREATE OR REPLACE SCHEMA EWS_POC.FEATURE_STORE
  COMMENT = 'Feature store - online (sub-minute) and offline (point-in-time) features';

-- Analytics: Semantic layer, BI views, Cortex Analyst integration
CREATE OR REPLACE SCHEMA EWS_POC.ANALYTICS
  COMMENT = 'Analytics and semantic layer for BI tools and Cortex Analyst';

-- Staging: Dead letter, quarantine, temporary processing
CREATE OR REPLACE SCHEMA EWS_POC.STAGING
  COMMENT = 'Temporary processing - dead letter tables, quarantine, temp data';

-- Governance: Tags, policies, DMF definitions, classification
CREATE OR REPLACE SCHEMA EWS_POC.GOVERNANCE
  COMMENT = 'Governance objects - tags, access policies, data metric functions';

-- =============================================================================
-- Warehouse Fleet (Workload Isolation)
-- Each workload gets independent, auto-scaling compute
-- =============================================================================

-- Ingestion Warehouse: Batch COPY INTO operations
CREATE OR REPLACE WAREHOUSE ews_ingest_wh
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Batch ingestion workloads (COPY INTO)';

-- Transform Warehouse: Dynamic Table refreshes and pipeline processing
CREATE OR REPLACE WAREHOUSE ews_transform_wh
  WAREHOUSE_SIZE = 'LARGE'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Pipeline transformation workloads (Dynamic Tables)';

-- Analytics Warehouse: BI queries, ad-hoc exploration, concurrent users
CREATE OR REPLACE WAREHOUSE ews_analytics_wh
  WAREHOUSE_SIZE = 'XLARGE'
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 10
  SCALING_POLICY = 'STANDARD'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  ENABLE_QUERY_ACCELERATION = TRUE
  QUERY_ACCELERATION_MAX_SCALE_FACTOR = 8
  COMMENT = 'Analytics workloads - multi-cluster auto-scaling for concurrency';

-- AI Warehouse: Cortex functions, LLM calls, feature computation
CREATE OR REPLACE WAREHOUSE ews_ai_wh
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 120
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'AI/ML workloads - Cortex functions, Analyst, Agents';

-- =============================================================================
-- Set defaults
-- =============================================================================

ALTER DATABASE EWS_POC SET DEFAULT_DDL_COLLATION = 'en-ci';

-- =============================================================================
-- Validation
-- =============================================================================

SHOW SCHEMAS IN DATABASE EWS_POC;
SHOW WAREHOUSES LIKE 'ews_%';
