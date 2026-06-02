# EWS POC — Step-by-Step Execution Guide

## Prerequisites

Before executing any scripts, ensure:

1. Snowflake account (Enterprise edition or higher)
2. ACCOUNTADMIN role access for initial setup
3. AWS IAM Role configured with trust policy for Snowflake
4. EWS S3 bucket created with appropriate directory structure
5. RSA key pair generated for Snowpipe Streaming SDK authentication
6. Python 3.9+ with `snowpipe-streaming` and `snowflake-snowpark-python` packages

---

## Phase 1: Foundation (Run First)

### Step 1.1: Storage Integration
```
File: 01_foundation/01_storage_integration.sql
Role: ACCOUNTADMIN
```
1. Replace `<EWS_AWS_ACCOUNT_ID>`, `<EWS_SNOWFLAKE_ROLE>`, `<EWS_BUCKET_NAME>`
2. Execute the CREATE STORAGE INTEGRATION statement
3. Run `DESC INTEGRATION ews_s3_integration`
4. Copy `STORAGE_AWS_IAM_USER_ARN` and `STORAGE_AWS_EXTERNAL_ID` from output
5. Update the AWS IAM trust policy on the EWS role with these values
6. Wait 5 minutes for IAM propagation

### Step 1.2: External Volume
```
File: 01_foundation/02_external_volume.sql
Role: ACCOUNTADMIN
```
1. Replace the same placeholders as above
2. Execute the CREATE EXTERNAL VOLUME statement
3. Run `SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('ews_iceberg_vol')` to confirm access
4. Expect: Success message confirming read/write access

### Step 1.3: Database, Schemas, Warehouses
```
File: 01_foundation/03_database_schemas.sql
Role: SYSADMIN
```
1. Execute the entire file — creates database, 7 schemas, 4 warehouses
2. Verify: `SHOW SCHEMAS IN DATABASE EWS_POC` (expect 7 schemas)
3. Verify: `SHOW WAREHOUSES LIKE 'ews_%'` (expect 4 warehouses)

### Step 1.4: RBAC Setup
```
File: 01_foundation/04_rbac_setup.sql
Role: SECURITYADMIN + SYSADMIN
```
1. Execute all role creation statements
2. Execute all grant statements
3. Verify: `SHOW ROLES LIKE 'EWS_%'` (expect 6 roles)

---

## Phase 2: Batch Ingestion (UC01)

### Step 2.1: Bronze Iceberg Tables
```
File: 02_batch_ingestion/01_bronze_iceberg_tables.sql
Role: EWS_ENGINEER
```
1. Execute all CREATE ICEBERG TABLE statements
2. Verify: `SHOW ICEBERG TABLES IN SCHEMA BRONZE` (expect 4 tables)

### Step 2.2: File Formats
```
File: 02_batch_ingestion/02_file_formats.sql
Role: EWS_ENGINEER
```
Execute all CREATE FILE FORMAT statements.

### Step 2.3: External Stages
```
File: 02_batch_ingestion/03_external_stages.sql
Role: EWS_ENGINEER
```
1. Replace `<EWS_BUCKET_NAME>` placeholders
2. Execute all CREATE STAGE statements
3. Test: `LIST @ews_txn_landing_stage` (should list files if any exist)

### Step 2.4: Load Data
```
File: 02_batch_ingestion/04_copy_into_scripts.sql
Role: EWS_ENGINEER
```
1. Place test files in S3 landing zones
2. Execute COPY INTO statements
3. Check results: `SELECT COUNT(*) FROM BRONZE.RAW_TRANSACTIONS`

### Step 2.5: Capture Rejected Records
```
File: 02_batch_ingestion/05_dead_letter_table.sql
Role: EWS_ENGINEER
```
1. Execute the dead letter table creation
2. Execute the VALIDATE() extraction INSERT statements
3. Check: `SELECT * FROM STAGING.DEAD_LETTER_RECORDS LIMIT 10`

### Step 2.6: Attach Quality Checks
```
File: 02_batch_ingestion/06_dmf_quality_checks.sql
Role: EWS_ENGINEER
```
Execute all DMF creation and attachment statements.

---

## Phase 3: Streaming (UC02)

### Step 3.1: Create PIPE and Target Table
```
Files: 03_streaming/01_streaming_pipe.sql, 02_streaming_target_table.sql
Role: EWS_ENGINEER
```
Execute both files in order.

### Step 3.2: Configure Streaming Client
```
File: 03_streaming/04_profile_template.json
```
1. Copy to `profile.json`
2. Replace placeholders with actual values
3. Ensure RSA key pair is in the same directory

### Step 3.3: Run Streaming Ingest
```
File: 03_streaming/03_streaming_client.py
```
```bash
pip install snowpipe-streaming
python 03_streaming/03_streaming_client.py
```
Expected: 1000 events ingested, sub-second latency reported.

### Step 3.4: Inject Anomalies
```
File: 03_streaming/05_anomaly_injection.py
```
```bash
python 03_streaming/05_anomaly_injection.py
```
Expected: Duplicates, late events, and burst injected.

### Step 3.5: Validate Exactly-Once
```
File: 03_streaming/06_exactly_once_proof.sql
Role: EWS_ANALYST
```
Execute all validation queries. Expect PASS on all tests.

---

## Phase 4: Pipeline (UC03)

### Step 4.1-4.2: Create Dynamic Tables
```
Files: 04_pipeline/01_silver_dynamic_tables.sql, 02_gold_dynamic_tables.sql
Role: EWS_ENGINEER
```
Execute both files. Dynamic Tables will start refreshing automatically.

### Step 4.3: Monitor Pipeline
```
File: 04_pipeline/05_pipeline_monitoring.sql
Role: EWS_ENGINEER
```
Wait 2-3 minutes for initial refreshes, then run monitoring queries.

---

## Phase 5: Feature Store (UC04-05)

### Step 5.1: Create Feature Tables
```
File: 05_feature_store/01_online_feature_table.sql
Role: EWS_ENGINEER
```
Execute to create online and offline Dynamic Table features.

### Step 5.2: Measure SLO
```
File: 05_feature_store/02_slo_measurement.sql
```
Run after streaming data flows through the pipeline.

### Step 5.3: Test Rematerialization
```
File: 05_feature_store/04_gold_rematerialization.sql
```
Demonstrates one-command rebuild from Gold history.

### Step 5.4: Time Travel Queries
```
File: 05_feature_store/05_offline_time_travel.sql
```
Execute after data has been in the system for at least 1 day.

### Step 5.5: Bi-Temporal Join
```
File: 05_feature_store/06_bitemporal_join.py
```
```bash
pip install snowflake-snowpark-python
python 05_feature_store/06_bitemporal_join.py
```

---

## Phase 6: Analytics Performance (UC09)

### Step 6.1: Run Workload Queries
```
File: 06_analytics_perf/01_analytics_queries.sql
Role: EWS_ANALYST
```
Execute dashboard and time travel queries. Note latencies.

### Step 6.2: Concurrent Load Test
```
File: 06_analytics_perf/02_concurrent_load_test.py
```
```bash
pip install snowflake-connector-python
python 06_analytics_perf/02_concurrent_load_test.py
```
Observe multi-cluster auto-scaling in Snowsight warehouse activity.

---

## Phase 7: Governance and Sharing (UC10-11)

### Step 7.1: Configure Governance
```
File: 07_self_service/01_governance_sharing.sql
Role: ACCOUNTADMIN
```
Execute tags, policies, masking, sharing, and marketplace statements.

---

## Phase 8: Cortex AI (UC13-14)

### Step 8.1: Deploy Semantic View
```
File: 08_cortex_ai/01_semantic_view_ddl.sql
Role: ACCOUNTADMIN
```
The semantic view `EWS_POC.ANALYTICS.EWS_FRAUD_ANALYTICS` is created directly via DDL (no staging required). Run the CREATE SEMANTIC VIEW statement from the file, or verify it already exists:
```sql
SHOW SEMANTIC VIEWS IN SCHEMA EWS_POC.ANALYTICS;
SHOW SEMANTIC METRICS IN EWS_POC.ANALYTICS.EWS_FRAUD_ANALYTICS;
```

### Step 8.2: Test Cortex Analyst
```
File: 08_cortex_ai/02_cortex_analyst_app.py
```
```bash
python 08_cortex_ai/02_cortex_analyst_app.py
```

### Step 8.3: Agentic AI + Git Integration
```
File: 08_cortex_ai/03_agentic_ai_git.sql
Role: EWS_ENGINEER
```
Execute LLM pipeline generation and Git integration setup.

---

## Validation Checklist

After completing all phases:

- [ ] 4 Bronze Iceberg tables created with data
- [ ] Dead letter table capturing rejected records
- [ ] DMFs attached and running on Bronze tables
- [ ] Streaming events flowing sub-second
- [ ] Exactly-once semantics validated (no duplicates)
- [ ] Silver Dynamic Tables refreshing incrementally
- [ ] Gold Dynamic Tables producing aggregated data
- [ ] Online feature store refreshing within 1 minute
- [ ] Time Travel queries returning historical snapshots
- [ ] Multi-cluster warehouse auto-scaling under load
- [ ] Governance tags and masking policies active
- [ ] Data Share created and accessible
- [ ] Cortex Analyst answering NL questions
- [ ] LLM generating pipeline code from SQL
