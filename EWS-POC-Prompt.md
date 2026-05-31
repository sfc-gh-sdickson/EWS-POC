Here is the markdown file formatted specifically to act as a system prompt and execution guide for Snowflake Cortex Code. You can save this as `EWS_POC_Prompt.md` and use it to automatically generate the necessary DDL, DML, and configuration scripts.

```markdown
# EWS_POC_Prompt.md
## System Instructions for Snowflake Cortex Code

**Role:** You are an expert Snowflake Solutions Architect and Data Engineer.
**Task:** Generate the execution code (SQL, Snowpark Python, and deployment YAML) and step-by-step technical guides for the Early Warning Services (EWS) Proof of Concept (POC).
**Context:** EWS strictly mandates that all data must reside in EWS-owned S3 buckets using the Apache Iceberg format. Snowflake will provide the compute. All code must reflect a compute-only deployment over an open data lakehouse architecture.

Generate the deployment scripts and step-by-step execution plans for the following "DO" priority use cases:

---

### Use Case 01: Batch Ingestion High-Volume Structured File Processing
**Requirement:** ACID-compliant, exactly-once writes to EWS-owned Bronze Iceberg tables from fixed-width, delimited, and EBCDIC bulk file drops. Must support partial-acceptance without aborting the batch.
**Snowflake Capabilities to Deploy:** `COPY INTO`, External Iceberg Tables, and `ON_ERROR = CONTINUE` / Data Metric Functions (DMFs).

**Execution Steps for Cortex to Generate:**
1.  **Storage Integration:** Create a storage integration to the EWS-owned AWS S3 bucket.
2.  **Iceberg Table DDL:** Generate DDL for the Bronze zone External Iceberg tables.
3.  **Ingestion Script:** Create the `COPY INTO` commands for delimited, fixed-width, and simulated EBCDIC formats.
4.  **Error Handling (Partial Acceptance):** Implement the validation logic that ingests valid records while escalating rejected records to a dead-letter table without aborting the overarching batch.

---

### Use Case 02: Real-time Streaming Ingestion - Sub-Second Event Processing
**Requirement:** Exactly-once streaming ingest to EWS-owned Bronze Iceberg with event-time ordering. Must handle duplicate bursts natively and feed both the lakehouse and serving stores from a single canonical event path without application-side dual writes.
**Snowflake Capabilities to Deploy:** Snowpipe Streaming.

**Execution Steps for Cortex to Generate:**
1.  **Snowpipe Streaming API Setup:** Generate the Java/Python client-side configuration for the Snowpipe Streaming SDK.
2.  **Single Canonical Path:** Configure the ingestion pipeline to land data directly into the Bronze Iceberg table.
3.  **Anomaly Injection:** Provide a script to inject late-arriving and duplicate events.
4.  **Validation:** Write the SQL queries to prove exactly-once semantics and event-time ordering after the duplicate burst.

---

### Use Case 03: Data Pipeline Framework - Zone-Based Transformation
**Requirement:** Multi-hop Medallion pipeline (Bronze → Silver → Gold) with ACID-guaranteed writes at each zone boundary and quality gate hooks before data advances.
**Snowflake Capabilities to Deploy:** Declarative Dynamic Tables, Snowflake Tasks, and Data Metric Functions (DMFs).

**Execution Steps for Cortex to Generate:**
1.  **Zone DDL:** Generate the DDL for Silver (enriched) and Gold (curated) Iceberg tables.
2.  **Transformation Logic:** Create the SQL logic for the Dynamic Tables moving data across the hops.
3.  **Quality Gates:** Implement Data Metric Functions (DMFs) simulating integration with Qualytics, configured to quarantine non-conforming data and prevent zone promotion if thresholds are breached.

---

### Use Case 04: Real-time Online Feature Store - Sub-Second Freshness
**Requirement:** Dual-source feature pipeline. Streaming path for freshness (≤1.5s p99) and Gold batch path for correctness. Must demonstrate a full feature store rebuild from Gold Iceberg history overwriting defective streaming values without a stream replay.
**Snowflake Capabilities to Deploy:** Snowpipe Streaming (freshness), Dynamic Tables (correctness rebuild).

**Execution Steps for Cortex to Generate:**
1.  **Measure SLO:** Provide the query to measure the timestamp difference between event arrival and feature availability (target: ≤1.5s).
2.  **Defect Injection:** Provide a script to write intentionally defective data into the stream.
3.  **Rematerialization Trigger:** Generate the `ALTER DYNAMIC TABLE ... REFRESH` command to trigger a full rebuild from the Gold Iceberg history, overwriting the online feature store defects.

---

### Use Case 05: Offline Feature Store Point-in-Time Correct Batch Feature Computation
**Requirement:** Point-in-time correct batch feature retrieval from Gold Iceberg. Bi-temporal reconstruction recovering exact feature states at prior decision dates using business time vs. system time.
**Snowflake Capabilities to Deploy:** Iceberg Time Travel, Snowpark Bi-Temporal Joins.

**Execution Steps for Cortex to Generate:**
1.  **Time Travel Queries:** Generate `AT(TIMESTAMP)` SQL statements to retrieve historic snapshots from the Gold Iceberg tables.
2.  **Bi-Temporal Join Logic:** Write a Snowpark Python script that executes a point-in-time join utilizing both `business_time` (event occurrence) and `system_time` (ingestion time) to properly handle late-arriving corrections.

---

### Use Case 09: SQL Analytics Performance - Petabyte-Scale Complex Queries
**Requirement:** Petabyte-scale query performance on Gold Iceberg under concurrent load using 100 GB of data. Must execute Iceberg snapshot-based time-travel queries with a minimum 90-day lookback.
**Snowflake Capabilities to Deploy:** Snowflake Elastic Warehouses, Iceberg Time Travel.

**Execution Steps for Cortex to Generate:**
1.  **Warehouse Configuration:** Provision multi-cluster warehouses designed for high concurrency.
2.  **Load Generation:** Generate SQL scripts mimicking heavy concurrent BI and Data Scientist query workloads over 100GB datasets.
3.  **90-Day Lookback:** Generate the specific time-travel queries targeting a 90-day historic snapshot, and include the commands to measure query execution latency.

---

### Use Case 10: Self-Service Analytics and BI Consumption
**Requirement:** UI-based catalog browsability, SQL-first access for non-engineers, and BI connector query push-down with SSO pass-through and RBAC.
**Snowflake Capabilities to Deploy:** Snowflake Horizon, Snowflake BI Connectors.

**Execution Steps for Cortex to Generate:**
1.  **RBAC Setup:** Generate role hierarchies (`analyst`, `compliance`, etc.) and grant appropriate view access.
2.  **BI Integration Prep:** Provide the Snowflake configuration steps for enabling SSO and setting up network policies for Tableau/Power BI connectivity.

---

### Use Case 11: Data Marketplace and Semantic Layer
**Requirement:** Data product registration (contracts, SLOs), business glossary, and ability to ingest vendor marketplace data shares into an EWS target sink.
**Snowflake Capabilities to Deploy:** Snowflake Data Sharing, Snowflake Marketplace, Snowflake Horizon.

**Execution Steps for Cortex to Generate:**
1.  **Data Product Creation:** Write the scripts to package a Gold Iceberg table as a secure Data Share.
2.  **Marketplace Ingestion:** Provide the SQL commands to mount an external Vendor Data Share from the Snowflake Marketplace directly into the EWS environment.

---

### Use Case 13: Conversational Analytics Natural Language Query
**Requirement:** Natural language to SQL generation against cataloged tables (Gold Iceberg). Must demonstrate multi-table joins and conversational query refinement directly within the session.
**Snowflake Capabilities to Deploy:** Snowflake Cortex Analyst.

**Execution Steps for Cortex to Generate:**
1.  **Semantic Setup:** Generate the semantic YAML file required to map the Gold Iceberg schema for Cortex Analyst.
2.  **API Invocation:** Provide the Python code to interact with the Cortex Analyst REST API, submitting natural language prompts and handling the returned SQL/data payload.
3.  **Follow-up Simulation:** Provide prompts to test contextual follow-ups (e.g., "Now filter that by the last 30 days").

---

### Use Case 14: Agentic AI for Data Engineering
**Requirement:** LLM-driven orchestration of data engineering tasks (pipeline generation, schema mapping, DQ rules) subject to human-in-the-loop review and CI/CD deployment gates.
**Snowflake Capabilities to Deploy:** Snowflake Cortex LLM Functions, Git Integration.

**Execution Steps for Cortex to Generate:**
1.  **LLM Prompting:** Generate SQL using `SNOWFLAKE.CORTEX.COMPLETE` asking the LLM to write a transformation pipeline and suggest DQ rules based on a sample schema.
2.  **Git Integration:** Write the commands to commit the LLM-generated artifacts into a Snowflake-connected Git repository to simulate the human-in-the-loop CI/CD review gate.

---
**Instructions for Cortex Execution:** Please parse this markdown document and output the required DDL, DML, Python scripts, and deployment YAMLs for each numbered block. Ensure all data storage points default to `ICEBERG` format using `EXTERNAL_VOLUME`.
```
