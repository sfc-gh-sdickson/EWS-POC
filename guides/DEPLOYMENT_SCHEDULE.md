# EWS POC — Deployment Schedule and Work Breakdown

## Gantt Chart

```mermaid
gantt
    title EWS POC Deployment Schedule
    dateFormat  YYYY-MM-DD
    axisFormat  %b %d

    section Phase 1: Foundation
    AWS IAM Trust Policy Setup           :p1a, 2026-06-09, 2d
    Storage Integration                  :p1b, after p1a, 1d
    External Volume Configuration        :p1c, after p1b, 1d
    Database, Schemas, Warehouses        :p1d, after p1c, 1d
    RBAC Role Hierarchy and Grants       :p1e, after p1d, 1d
    Foundation Validation                :milestone, p1m, after p1e, 0d

    section Phase 2: UC01 Batch Ingestion
    Bronze Iceberg Table DDL             :p2a, after p1e, 1d
    File Formats (CSV, Fixed, EBCDIC)    :p2b, after p2a, 1d
    External Stages (S3 Landing Zones)   :p2c, after p2b, 1d
    COPY INTO Scripts + Test Data        :p2d, after p2c, 2d
    Dead Letter Table + VALIDATE()       :p2e, after p2d, 1d
    DMF Quality Checks                   :p2f, after p2e, 1d
    Batch Ingestion Validation           :milestone, p2m, after p2f, 0d

    section Phase 3: UC02 Streaming
    RSA Key Pair Generation              :p3a, after p1e, 1d
    PIPE Object Creation                 :p3b, after p2a, 1d
    Python SDK Client Development        :p3c, after p3b, 2d
    Anomaly Injection Script             :p3d, after p3c, 1d
    Exactly-Once Validation              :p3e, after p3d, 1d
    Streaming Validation                 :milestone, p3m, after p3e, 0d

    section Phase 4: UC03 Pipeline
    Silver Dynamic Tables (4 DTs)        :p4a, after p2m, 2d
    Gold Dynamic Tables (4 DTs)          :p4b, after p4a, 2d
    DMF Quality Gates                    :p4c, after p4b, 1d
    Quarantine Task                      :p4d, after p4c, 1d
    Pipeline Monitoring Queries          :p4e, after p4d, 1d
    Pipeline Validation                  :milestone, p4m, after p4e, 0d

    section Phase 5: UC04-05 Feature Store
    Online Feature DT (1-min lag)        :p5a, after p4m, 2d
    SLO Measurement Queries              :p5b, after p5a, 1d
    Defect Injection + Rematerialization :p5c, after p5b, 1d
    Offline Time Travel Queries          :p5d, after p5c, 1d
    Bi-Temporal Snowpark Join            :p5e, after p5d, 2d
    Feature Store Validation             :milestone, p5m, after p5e, 0d

    section Phase 6: UC09 Analytics
    Warehouse Fleet Tuning               :p6a, after p4m, 1d
    BI Workload Queries                  :p6b, after p6a, 1d
    DS Exploration Queries               :p6c, after p6b, 1d
    90-Day Time Travel Queries           :p6d, after p6c, 1d
    Concurrent Load Test (50 users)      :p6e, after p6d, 2d
    Query Profiling and Report           :p6f, after p6e, 1d
    Analytics Validation                 :milestone, p6m, after p6f, 0d

    section Phase 7: UC10-11 Governance
    Horizon Tags + Classification        :p7a, after p4m, 1d
    Row Access Policies                  :p7b, after p7a, 1d
    Dynamic Data Masking                 :p7c, after p7b, 1d
    SSO + Network Policy Config          :p7d, after p7c, 1d
    Data Share Packaging                 :p7e, after p7d, 1d
    Marketplace Consumption              :p7f, after p7e, 1d
    Governance Validation                :milestone, p7m, after p7f, 0d

    section Phase 8: UC13-14 Cortex AI
    Semantic YAML Model                  :p8a, after p4m, 2d
    Cortex Analyst REST Client           :p8b, after p8a, 2d
    Multi-Turn Prompt Testing            :p8c, after p8b, 1d
    Agentic Pipeline Generation          :p8d, after p8c, 2d
    Git Integration Setup                :p8e, after p8d, 1d
    Cortex AI Validation                 :milestone, p8m, after p8e, 0d

    section Phase 9: Integration Testing
    End-to-End Pipeline Test             :p9a, after p5m, 2d
    Performance Benchmarks               :p9b, after p6m, 2d
    Security Review                      :p9c, after p7m, 1d
    Demo Preparation                     :p9d, after p9a, 2d
    POC Complete                         :milestone, p9m, after p9d, 0d
```

---

## Work Breakdown Structure (WBS)

### Phase 1: Foundation Infrastructure

| WBS | Task | Deliverable | Dependencies | Resources |
|-----|------|-------------|--------------|-----------|
| 1.1 | AWS IAM Trust Policy | IAM Role with Snowflake trust | AWS Admin access | Cloud Ops |
| 1.2 | Storage Integration | `ews_s3_integration` object | 1.1 complete | Snowflake Admin |
| 1.3 | External Volume | `ews_iceberg_vol` (ALLOW_WRITES=TRUE) | 1.2 verified | Snowflake Admin |
| 1.4 | Database + Schemas | EWS_POC with 7 schemas | 1.3 verified | Data Engineer |
| 1.5 | Warehouse Fleet | 4 workload-specific warehouses | 1.4 complete | Data Engineer |
| 1.6 | RBAC Hierarchy | 6 functional roles + grants | 1.4 complete | Security Admin |

### Phase 2: UC01 — Batch Ingestion

| WBS | Task | Deliverable | Dependencies | Resources |
|-----|------|-------------|--------------|-----------|
| 2.1 | Bronze Table DDL | 4 Iceberg tables (txns, members, alerts, institutions) | Phase 1 | Data Engineer |
| 2.2 | File Format Definitions | 4 formats (delimited, fixed-width, EBCDIC, JSON) | 2.1 | Data Engineer |
| 2.3 | External Stages | 4 stages (one per file type) | 1.2, S3 paths confirmed | Data Engineer |
| 2.4 | Test Data Generation | Sample files in each format | 2.2, 2.3 | Data Engineer |
| 2.5 | COPY INTO Scripts | 3 ingestion scripts with ON_ERROR=CONTINUE | 2.1-2.4 | Data Engineer |
| 2.6 | Dead Letter Table | VALIDATE() extraction pipeline | 2.5 tested | Data Engineer |
| 2.7 | DMF Quality Checks | 5 DMFs attached to Bronze tables | 2.5 tested | Data Quality |

### Phase 3: UC02 — Real-Time Streaming

| WBS | Task | Deliverable | Dependencies | Resources |
|-----|------|-------------|--------------|-----------|
| 3.1 | Key Pair Authentication | RSA key pair + user config | Phase 1 | Security |
| 3.2 | Streaming Target Table | BRONZE.STREAMING_EVENTS Iceberg | 2.1 pattern | Data Engineer |
| 3.3 | PIPE Object | BRONZE.EWS_EVENT_PIPE | 3.2 | Data Engineer |
| 3.4 | Python SDK Client | Streaming producer (~30 lines) | 3.1, 3.3 | Developer |
| 3.5 | Anomaly Injection | Duplicate + late event script | 3.4 working | Developer |
| 3.6 | Validation Queries | Exactly-once + ordering proof | 3.5 executed | Data Engineer |

### Phase 4: UC03 — Medallion Pipeline

| WBS | Task | Deliverable | Dependencies | Resources |
|-----|------|-------------|--------------|-----------|
| 4.1 | Silver DTs (Cleanse) | 4 Dynamic Tables (INCREMENTAL) | Phase 2, Phase 3 | Data Engineer |
| 4.2 | Gold DTs (Aggregate) | 4 Dynamic Tables (INCREMENTAL) | 4.1 refreshing | Data Engineer |
| 4.3 | DMF Quality Gates | DMFs blocking zone promotion | 4.1, 4.2 | Data Quality |
| 4.4 | Quarantine Task | Snowflake Task for enforcement | 4.3 | Data Engineer |
| 4.5 | Monitoring Setup | Refresh history + alerting queries | 4.1, 4.2 | Platform Eng |

### Phase 5: UC04-05 — Feature Stores

| WBS | Task | Deliverable | Dependencies | Resources |
|-----|------|-------------|--------------|-----------|
| 5.1 | Online Feature DT | 1-minute lag Dynamic Table | Phase 4 complete | ML Engineer |
| 5.2 | SLO Measurement | p99 latency query (target: 1.5s) | 5.1 + streaming data | ML Engineer |
| 5.3 | Defect Injection | Bad data in stream | 5.1 running | ML Engineer |
| 5.4 | Rematerialization | ALTER DT REFRESH from Gold | 5.3 | ML Engineer |
| 5.5 | Offline Time Travel | AT(TIMESTAMP) queries | Phase 4, data age >1 day | ML Engineer |
| 5.6 | Bi-Temporal Join | Snowpark Python PIT join | 5.5 | ML Engineer |

### Phase 6: UC09 — Analytics Performance

| WBS | Task | Deliverable | Dependencies | Resources |
|-----|------|-------------|--------------|-----------|
| 6.1 | Warehouse Tuning | Query Acceleration enabled | Phase 1 warehouses | Platform Eng |
| 6.2 | BI Workload | 5 dashboard-style queries | Phase 4 Gold populated | Analyst |
| 6.3 | DS Workload | 5 ad-hoc exploration queries | Phase 4 Gold populated | Data Scientist |
| 6.4 | 90-Day Time Travel | Historical snapshot queries | Data age >1 day | Analyst |
| 6.5 | Concurrent Test | 50-user load test Python script | 6.2, 6.3 | Developer |
| 6.6 | Performance Report | QUERY_HISTORY analysis | 6.5 complete | Platform Eng |

### Phase 7: UC10-11 — Governance and Sharing

| WBS | Task | Deliverable | Dependencies | Resources |
|-----|------|-------------|--------------|-----------|
| 7.1 | Horizon Tags | SENSITIVITY + DATA_DOMAIN tags | Phase 4 tables exist | Security |
| 7.2 | Row Access Policies | Regional segmentation policy | 7.1 | Security |
| 7.3 | Data Masking | PII masking for non-privileged roles | 7.1 | Security |
| 7.4 | SSO + Network Policy | BI tool connectivity config | EWS IdP details | Security |
| 7.5 | Data Share | Gold tables packaged as share | Phase 4 Gold populated | Data Engineer |
| 7.6 | Marketplace | Vendor share mounted | Marketplace listing available | Data Engineer |

### Phase 8: UC13-14 — Cortex AI

| WBS | Task | Deliverable | Dependencies | Resources |
|-----|------|-------------|--------------|-----------|
| 8.1 | Semantic YAML | Model for 4 Gold tables | Phase 4 Gold schema finalized | AI Engineer |
| 8.2 | Cortex Analyst Client | Python REST API client | 8.1 staged | AI Engineer |
| 8.3 | Prompt Testing | 10+ NL queries validated | 8.2 | AI Engineer |
| 8.4 | Agentic Pipeline Gen | CORTEX.COMPLETE for DDL/DQ | Phase 4 schema | AI Engineer |
| 8.5 | Git Integration | Snowflake Git repo connected | GitHub PAT | DevOps |

### Phase 9: Integration and Demo

| WBS | Task | Deliverable | Dependencies | Resources |
|-----|------|-------------|--------------|-----------|
| 9.1 | End-to-End Test | Full pipeline: file to feature | Phases 2-5 complete | All |
| 9.2 | Performance Benchmark | Latency report under load | Phase 6 complete | Platform Eng |
| 9.3 | Security Review | RBAC + masking verified | Phase 7 complete | Security |
| 9.4 | Demo Preparation | Runbook + talking points | 9.1-9.3 | SA Team |
| 9.5 | POC Delivery | Final handoff to EWS | 9.4 | SA Team |

---

## Critical Path

The critical path runs through the longest dependency chain:

```
Foundation (6 days)
  → Batch Ingestion (8 days)
    → Pipeline (7 days)
      → Feature Store (7 days)
        → Integration Testing (4 days)
```

**Total critical path: ~32 working days**

Phases 6 (Analytics), 7 (Governance), and 8 (Cortex AI) can run in parallel with Phase 5 once Phase 4 completes, saving approximately 14 days of serial execution.

---

## Resource Requirements

| Role | Allocation | Phases |
|------|-----------|--------|
| Snowflake Solutions Architect | Full-time | All phases |
| Data Engineer | Full-time | Phases 1-5 |
| ML/AI Engineer | Part-time | Phases 5, 8 |
| Security/Compliance | Part-time | Phases 1, 7 |
| Cloud Operations (AWS) | Part-time | Phase 1 only |
| EWS Technical Contact | As-needed | Validation checkpoints |

---

## Milestone Checkpoints

| Milestone | Criteria | Exit Gate |
|-----------|----------|-----------|
| **Foundation Complete** | All infra verified, SYSTEM$VERIFY passes | Can create Iceberg tables |
| **Ingestion Proven** | Batch + streaming data landing in Bronze | Records queryable |
| **Pipeline Running** | Dynamic Tables refreshing, Gold populated | Target lag met |
| **Features Available** | Online (1-min) + Offline (time travel) working | SLO measured |
| **Analytics Scaled** | 50 concurrent queries, auto-scaling observed | Latency report |
| **Governance Active** | Tags, masking, RLS all enforced | Security audit pass |
| **AI Functional** | Cortex Analyst answering NL questions | Multi-turn demo |
| **POC Complete** | All use cases demonstrated end-to-end | EWS sign-off |

---

## Risk Register

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| AWS IAM misconfiguration | Blocks Phase 1 | Medium | Pre-validate trust policy template |
| S3 permissions insufficient | Blocks all writes | Medium | Run SYSTEM$VERIFY early |
| Snowpipe Streaming SDK version | Blocks UC02 | Low | Pin SDK version, test early |
| Dynamic Table incremental not supported | Blocks UC03 | Low | Validate query patterns before build |
| Cortex Analyst model quality | Degrades UC13 | Medium | Use verified_queries in YAML |
| Data volume insufficient for perf test | Weakens UC09 | Medium | Pre-generate 100GB synthetic data |
| Network policy blocks BI tools | Blocks UC10 | Low | Coordinate IP ranges with EWS |
