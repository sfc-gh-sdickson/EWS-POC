# Sub-Second Data Freshness — Architecture Recommendations

**Status:** Deferred — revisit if customer requires sub-second latency  
**Date:** June 2, 2026  
**Author:** Snowflake Solutions Engineering  

---

## Problem Statement

EWS requires sub-second data freshness for the online feature store (UC04) and real-time fraud detection paths. The current architecture uses Dynamic Tables with a minimum target lag of 5 minutes. Dynamic Tables have a **hard platform minimum of 60 seconds** — sub-second refresh is not achievable with Dynamic Tables alone.

---

## Current Architecture (Deployed)

```
Events → Kinesis Firehose (60s buffer) → S3 → Snowpipe AUTO_INGEST (~60s) → Bronze Iceberg
Bronze → Dynamic Table (5 min lag) → Silver
Silver → Dynamic Table (10 min lag) → Gold
Silver → Dynamic Table (5 min lag) → Online Feature Store
```

**End-to-end latency: ~2-6 minutes** (Firehose buffer + Snowpipe pickup + DT refresh)

---

## Recommended Architecture (Sub-Second)

```
Events → Snowpipe Streaming SDK (<1s) → Bronze Iceberg (immediately queryable)
Bronze → Stream + Task (1s trigger) → Online Feature Store (~1-2s)
Bronze → Dynamic Table (5 min) → Silver → Gold (analytics path unchanged)
```

**End-to-end latency: <2 seconds** for the streaming-to-feature path

---

## Change 1: Replace Kinesis Firehose with Snowpipe Streaming SDK

### Why

Kinesis Firehose buffers events for 60-300 seconds before writing files to S3. Snowpipe AUTO_INGEST then takes another ~60 seconds to detect and load the file. This architecture fundamentally cannot achieve sub-second latency.

Snowpipe Streaming SDK writes **directly to the table** — no S3 intermediary, no file buffering. Data is queryable in under 1 second.

### What Changes

| Component | Current | Proposed |
|-----------|---------|----------|
| Producer | boto3 `put_record_batch()` to Firehose | `snowpipe-streaming` SDK `append_row()` |
| Transport | Firehose → S3 → SQS → Snowpipe | Direct SDK → Snowflake (REST) |
| Latency | 2-6 minutes | Sub-second |
| Infrastructure | Firehose delivery stream + S3 bucket + SQS | PIPE object only |
| SDK | boto3 (Python) | snowpipe-streaming (Python/Java/Node.js) |

### Implementation

```sql
-- Create PIPE for high-performance streaming
CREATE OR REPLACE PIPE BRONZE.EWS_STREAMING_PIPE
AS COPY INTO BRONZE.STREAMING_EVENTS
  FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;
```

```python
# Python producer (~20 lines replaces entire Firehose setup)
from snowpipe_streaming import SnowpipeStreamingClient

config = {
    "url": "https://<account>.snowflakecomputing.com",
    "user": "<user>",
    "account": "<account>",
    "private_key_file": "rsa_key.p8",
    "role": "EWS_SERVICE",
}

client = SnowpipeStreamingClient(config)
channel = client.open_channel("ews_events_ch", offset_token="0")

# Sub-second: data queryable immediately after this returns
channel.append_row({"event_id": "...", "event_time": "...", ...})
```

### Prerequisites

- RSA key pair for authentication (no password auth for SDK)
- `pip install snowpipe-streaming`
- PIPE object created with `DATA_SOURCE(TYPE => 'STREAMING')`

---

## Change 2: Replace Online Feature DT with Stream + Task (1-second trigger)

### Why

Dynamic Tables have a 60-second minimum target lag. For sub-second feature freshness, we need a Stream + Task pattern with a 1-second schedule that fires only when new data arrives.

### What Changes

| Component | Current | Proposed |
|-----------|---------|----------|
| Feature materialization | Dynamic Table (5 min lag) | Stream + Task (1s schedule) |
| Trigger | Snowflake DT scheduler | `WHEN SYSTEM$STREAM_HAS_DATA()` |
| Refresh logic | Full recompute (DT FULL mode) | Incremental MERGE (only new events) |
| Latency | ~5 minutes | ~1-2 seconds |

### Implementation

```sql
-- Step 1: Create a standard table for the online feature store (not a DT)
CREATE OR REPLACE TABLE FEATURE_STORE.ONLINE_MEMBER_FEATURES_RT (
    member_id STRING NOT NULL,
    event_count_24h NUMBER,
    unique_channels_24h NUMBER,
    total_spend_24h NUMBER(15,2),
    max_risk_score_24h NUMBER(5,2),
    last_activity_time TIMESTAMP_LTZ,
    feature_computed_at TIMESTAMP_LTZ
);

-- Step 2: Create a Stream on the Bronze streaming events table
CREATE OR REPLACE STREAM BRONZE.STREAMING_EVENTS_STREAM
  ON TABLE BRONZE.STREAMING_EVENTS
  APPEND_ONLY = TRUE;

-- Step 3: Create a Task that runs every 1 second when stream has data
CREATE OR REPLACE TASK FEATURE_STORE.REFRESH_ONLINE_FEATURES
  WAREHOUSE = ews_transform_wh
  SCHEDULE = '1 SECOND'
  WHEN SYSTEM$STREAM_HAS_DATA('EWS_POC.BRONZE.STREAMING_EVENTS_STREAM')
AS
  MERGE INTO FEATURE_STORE.ONLINE_MEMBER_FEATURES_RT target
  USING (
      SELECT
          member_id,
          COUNT(*) AS new_event_count,
          COUNT(DISTINCT channel) AS new_channels,
          SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS new_spend,
          MAX(risk_score) AS new_max_risk,
          MAX(event_time) AS new_last_activity
      FROM BRONZE.STREAMING_EVENTS_STREAM
      GROUP BY member_id
  ) source
  ON target.member_id = source.member_id
  WHEN MATCHED THEN UPDATE SET
      event_count_24h = target.event_count_24h + source.new_event_count,
      unique_channels_24h = GREATEST(target.unique_channels_24h, source.new_channels),
      total_spend_24h = target.total_spend_24h + source.new_spend,
      max_risk_score_24h = GREATEST(target.max_risk_score_24h, source.new_max_risk),
      last_activity_time = GREATEST(target.last_activity_time, source.new_last_activity),
      feature_computed_at = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT (
      member_id, event_count_24h, unique_channels_24h, total_spend_24h,
      max_risk_score_24h, last_activity_time, feature_computed_at
  ) VALUES (
      source.member_id, source.new_event_count, source.new_channels,
      source.new_spend, source.new_max_risk, source.new_last_activity,
      CURRENT_TIMESTAMP()
  );

-- Step 4: Resume the task
ALTER TASK FEATURE_STORE.REFRESH_ONLINE_FEATURES RESUME;
```

### Considerations

- The 1-second Task fires only when the stream has data (no wasted compute)
- MERGE is incremental — only processes new rows from the stream
- The 24-hour window requires a separate scheduled task to decay old counts (e.g., hourly)
- Warehouse stays warm during active streaming periods (AUTO_SUSPEND = 60)

---

## Change 3: Keep Dynamic Tables for Analytics (No Change)

The Silver → Gold pipeline serving BI dashboards, Cortex Analyst, and data sharing does **not** need sub-second freshness. 5-10 minute lag is appropriate for:

- `SILVER.CLEANSED_TRANSACTIONS` (5 min)
- `SILVER.ENRICHED_MEMBERS` (5 min)
- `GOLD.DAILY_MEMBER_SUMMARY` (10 min)
- `GOLD.FRAUD_SIGNALS` (5 min)
- `GOLD.MEMBER_ACTIVITY` (10 min)
- `GOLD.INSTITUTION_SUMMARY` (30 min)

These remain unchanged.

---

## Dual-Path Architecture Summary

```
                    ┌─────────────────────────────────────────┐
                    │          REAL-TIME PATH (<2s)            │
                    │                                         │
Events ──► Snowpipe Streaming SDK ──► Bronze (immediate) ──► │
                    │                     │                    │
                    │                     ▼                    │
                    │         Stream + Task (1s trigger)       │
                    │                     │                    │
                    │                     ▼                    │
                    │      Online Feature Store (1-2s fresh)   │
                    └─────────────────────────────────────────┘

                    ┌─────────────────────────────────────────┐
                    │       ANALYTICS PATH (5-10 min)          │
                    │                                         │
              Bronze ──► DT Silver (5 min) ──► DT Gold (10 min)
                    │                              │           │
                    │                              ▼           │
                    │            BI / Cortex Analyst / Shares  │
                    └─────────────────────────────────────────┘
```

---

## Cost Implications

| Component | Current Cost | Proposed Cost | Delta |
|-----------|-------------|---------------|-------|
| Firehose | AWS cost (per GB ingested) | Eliminated | Savings |
| Snowpipe AUTO_INGEST | Serverless credits (per file) | Eliminated | Savings |
| Snowpipe Streaming | N/A | Per-GB ingested (flat) | New cost |
| 1-second Task | N/A | Warehouse credits when stream has data | New cost |
| DT Feature Store | Warehouse credits (5 min refresh) | Eliminated for RT path | Savings |

**Net impact:** Roughly cost-neutral. Firehose + Snowpipe savings offset Snowpipe Streaming + Task costs. The 1-second Task only fires when data arrives (no idle cost).

---

## Implementation Effort

| Task | Effort | Dependencies |
|------|--------|-------------|
| Generate RSA key pair | 10 min | None |
| Create PIPE object for streaming | 5 min | Key pair configured |
| Rewrite producer from boto3 to snowpipe-streaming | 1 hour | pip install snowpipe-streaming |
| Create Stream on Bronze table | 5 min | None |
| Create 1-second Task with MERGE | 30 min | Stream created |
| Test end-to-end latency | 1 hour | All above complete |
| Update validation queries | 30 min | Test complete |
| **Total** | **~3-4 hours** | |

---

## Decision Criteria

Implement this change if:

- Customer confirms sub-second SLO for online feature freshness
- Customer confirms real-time fraud detection requires <2 second response
- Customer is willing to manage RSA key pair authentication for SDK

Keep current architecture if:

- 2-6 minute latency is acceptable for all use cases
- Customer prefers fully serverless (no SDK client to manage)
- Kinesis Firehose is already deployed and integrated with upstream systems

---

## References

- [Snowpipe Streaming SDK Documentation](https://docs.snowflake.com/en/user-guide/snowpipe-streaming/snowpipe-streaming-high-performance-getting-started)
- [Snowpipe Streaming Configuration](https://docs.snowflake.com/en/user-guide/snowpipe-streaming/snowpipe-streaming-high-performance-configurations)
- [Streams and Tasks](https://docs.snowflake.com/en/user-guide/streams-intro)
- [Task Scheduling (1-second minimum)](https://docs.snowflake.com/en/sql-reference/sql/create-task)
