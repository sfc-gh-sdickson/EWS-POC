/*=============================================================================
  EWS POC - Step 1.4: Role-Based Access Control (RBAC)
  
  PURPOSE: Create a functional role hierarchy following Snowflake best practices.
           Roles map to job functions, not individual users.
  
  SNOWFLAKE ADVANTAGE: Native hierarchical RBAC with inheritance, row access
  policies, and tag-based governance. No external authorization service needed.
  Competitors require Apache Ranger, custom RBAC views, or application-level
  access control.
  
  ROLE HIERARCHY:
    ACCOUNTADMIN
      └── EWS_ADMIN (full POC management)
            ├── EWS_ENGINEER (pipeline development, DDL)
            │     └── EWS_ANALYST (read Gold/Analytics, write queries)
            │           └── EWS_VIEWER (read-only dashboards)
            ├── EWS_COMPLIANCE (audit, governance, all schemas read)
            └── EWS_SERVICE (application/service account access)
=============================================================================*/

USE ROLE SECURITYADMIN;

-- =============================================================================
-- Create Functional Roles
-- =============================================================================

CREATE OR REPLACE ROLE EWS_ADMIN
  COMMENT = 'Full administrative access to EWS POC database and warehouses';

CREATE OR REPLACE ROLE EWS_ENGINEER
  COMMENT = 'Data engineering - create/modify pipelines, DDL on all schemas';

CREATE OR REPLACE ROLE EWS_ANALYST
  COMMENT = 'Business analyst - read Gold/Analytics, run queries, use Cortex Analyst';

CREATE OR REPLACE ROLE EWS_VIEWER
  COMMENT = 'Dashboard viewer - read-only access to Gold zone views';

CREATE OR REPLACE ROLE EWS_COMPLIANCE
  COMMENT = 'Compliance officer - read all schemas, governance admin, audit access';

CREATE OR REPLACE ROLE EWS_SERVICE
  COMMENT = 'Service account - streaming ingest, scheduled tasks, API access';

-- =============================================================================
-- Role Hierarchy (grant child roles to parent roles)
-- =============================================================================

GRANT ROLE EWS_VIEWER TO ROLE EWS_ANALYST;
GRANT ROLE EWS_ANALYST TO ROLE EWS_ENGINEER;
GRANT ROLE EWS_ENGINEER TO ROLE EWS_ADMIN;
GRANT ROLE EWS_COMPLIANCE TO ROLE EWS_ADMIN;
GRANT ROLE EWS_SERVICE TO ROLE EWS_ADMIN;
GRANT ROLE EWS_ADMIN TO ROLE SYSADMIN;

-- =============================================================================
-- Database and Schema Grants
-- =============================================================================

USE ROLE SYSADMIN;

-- EWS_ADMIN: Full control
GRANT ALL ON DATABASE EWS_POC TO ROLE EWS_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_ADMIN;

-- EWS_ENGINEER: Create objects in all schemas
GRANT USAGE ON DATABASE EWS_POC TO ROLE EWS_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_ENGINEER;
GRANT CREATE TABLE ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_ENGINEER;
GRANT CREATE VIEW ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_ENGINEER;
GRANT CREATE DYNAMIC TABLE ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_ENGINEER;
GRANT CREATE ICEBERG TABLE ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_ENGINEER;
GRANT CREATE TASK ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_ENGINEER;
GRANT CREATE PIPE ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_ENGINEER;
GRANT CREATE STAGE ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_ENGINEER;
GRANT CREATE FILE FORMAT ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_ENGINEER;
GRANT CREATE FUNCTION ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_ENGINEER;

-- EWS_ANALYST: Read Gold and Analytics, write to Staging
GRANT USAGE ON DATABASE EWS_POC TO ROLE EWS_ANALYST;
GRANT USAGE ON SCHEMA EWS_POC.GOLD TO ROLE EWS_ANALYST;
GRANT USAGE ON SCHEMA EWS_POC.ANALYTICS TO ROLE EWS_ANALYST;
GRANT USAGE ON SCHEMA EWS_POC.FEATURE_STORE TO ROLE EWS_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA EWS_POC.GOLD TO ROLE EWS_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA EWS_POC.ANALYTICS TO ROLE EWS_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA EWS_POC.FEATURE_STORE TO ROLE EWS_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA EWS_POC.GOLD TO ROLE EWS_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA EWS_POC.ANALYTICS TO ROLE EWS_ANALYST;

-- EWS_VIEWER: Read-only on Gold views
GRANT USAGE ON DATABASE EWS_POC TO ROLE EWS_VIEWER;
GRANT USAGE ON SCHEMA EWS_POC.GOLD TO ROLE EWS_VIEWER;
GRANT SELECT ON ALL VIEWS IN SCHEMA EWS_POC.GOLD TO ROLE EWS_VIEWER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA EWS_POC.GOLD TO ROLE EWS_VIEWER;

-- EWS_COMPLIANCE: Read everything for audit
GRANT USAGE ON DATABASE EWS_POC TO ROLE EWS_COMPLIANCE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE EWS_POC TO ROLE EWS_COMPLIANCE;
GRANT SELECT ON ALL TABLES IN DATABASE EWS_POC TO ROLE EWS_COMPLIANCE;
GRANT SELECT ON FUTURE TABLES IN DATABASE EWS_POC TO ROLE EWS_COMPLIANCE;
GRANT USAGE ON SCHEMA EWS_POC.GOVERNANCE TO ROLE EWS_COMPLIANCE;

-- EWS_SERVICE: Ingest and pipeline execution
GRANT USAGE ON DATABASE EWS_POC TO ROLE EWS_SERVICE;
GRANT USAGE ON SCHEMA EWS_POC.BRONZE TO ROLE EWS_SERVICE;
GRANT USAGE ON SCHEMA EWS_POC.STAGING TO ROLE EWS_SERVICE;
GRANT INSERT ON ALL TABLES IN SCHEMA EWS_POC.BRONZE TO ROLE EWS_SERVICE;
GRANT INSERT ON FUTURE TABLES IN SCHEMA EWS_POC.BRONZE TO ROLE EWS_SERVICE;

-- =============================================================================
-- Warehouse Grants
-- =============================================================================

-- Engineers get all warehouses
GRANT USAGE ON WAREHOUSE ews_ingest_wh TO ROLE EWS_ENGINEER;
GRANT USAGE ON WAREHOUSE ews_transform_wh TO ROLE EWS_ENGINEER;
GRANT USAGE ON WAREHOUSE ews_analytics_wh TO ROLE EWS_ENGINEER;
GRANT USAGE ON WAREHOUSE ews_ai_wh TO ROLE EWS_ENGINEER;

-- Analysts get analytics and AI warehouses
GRANT USAGE ON WAREHOUSE ews_analytics_wh TO ROLE EWS_ANALYST;
GRANT USAGE ON WAREHOUSE ews_ai_wh TO ROLE EWS_ANALYST;

-- Viewers get analytics warehouse (read-only queries)
GRANT USAGE ON WAREHOUSE ews_analytics_wh TO ROLE EWS_VIEWER;

-- Compliance gets analytics warehouse
GRANT USAGE ON WAREHOUSE ews_analytics_wh TO ROLE EWS_COMPLIANCE;

-- Service account gets ingest warehouse
GRANT USAGE ON WAREHOUSE ews_ingest_wh TO ROLE EWS_SERVICE;

-- =============================================================================
-- External Volume Grants
-- =============================================================================

USE ROLE ACCOUNTADMIN;
GRANT USAGE ON EXTERNAL VOLUME ews_iceberg_vol TO ROLE EWS_ENGINEER;
GRANT USAGE ON EXTERNAL VOLUME ews_iceberg_vol TO ROLE EWS_ADMIN;

-- =============================================================================
-- Integration Grants
-- =============================================================================

GRANT USAGE ON INTEGRATION ews_s3_integration TO ROLE EWS_ENGINEER;
GRANT USAGE ON INTEGRATION ews_s3_integration TO ROLE EWS_ADMIN;

-- =============================================================================
-- Assign roles to current user for POC testing
-- =============================================================================

GRANT ROLE EWS_ADMIN TO USER CURRENT_USER();

-- =============================================================================
-- Validation
-- =============================================================================

SHOW ROLES LIKE 'EWS_%';
SHOW GRANTS TO ROLE EWS_ENGINEER;
SHOW GRANTS TO ROLE EWS_ANALYST;
