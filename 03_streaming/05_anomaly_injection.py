"""
=============================================================================
EWS POC - UC02 Step 5: Anomaly Injection via Kinesis Firehose

PURPOSE: Inject duplicate events and late-arriving events through Firehose
to prove that Snowpipe + Bronze table deduplication handles these correctly.

Since Firehose provides at-least-once delivery, duplicates are expected.
Deduplication happens in the Silver zone Dynamic Table (QUALIFY ROW_NUMBER).

USAGE:
  python 05_anomaly_injection.py
=============================================================================
"""

import json
import time
import uuid
import random
from datetime import datetime, timezone, timedelta

import boto3


FIREHOSE_STREAM_NAME = "<EWS_FIREHOSE_DELIVERY_STREAM>"
AWS_REGION = "us-east-1"

firehose_client = boto3.client("firehose", region_name=AWS_REGION)


def send_events(events: list):
    """Send a list of events to Firehose."""
    records = [
        {"Data": (json.dumps(e) + "\n").encode("utf-8")}
        for e in events
    ]
    # Firehose batch limit is 500
    for i in range(0, len(records), 500):
        chunk = records[i:i+500]
        firehose_client.put_record_batch(
            DeliveryStreamName=FIREHOSE_STREAM_NAME,
            Records=chunk,
        )


def main():
    print("=" * 70)
    print("EWS POC - Anomaly Injection via Kinesis Firehose")
    print("=" * 70)

    # =========================================================================
    # PHASE 1: DUPLICATE events (same event_id sent multiple times)
    # Firehose provides at-least-once delivery, so duplicates are realistic.
    # Silver zone DT deduplicates on event_id using QUALIFY ROW_NUMBER.
    # =========================================================================
    print("\n[Phase 1] Injecting DUPLICATE events (3x each)...")

    duplicate_events = []
    for i in range(10):
        event = {
            "event_id": f"DUP-{uuid.uuid4().hex[:8]}",
            "event_time": datetime.now(timezone.utc).isoformat(),
            "event_type": "TXN",
            "member_id": f"MBR{100000 + i}",
            "institution_id": "FI10001",
            "amount": round(100.0 + i * 50, 2),
            "channel": "ONLINE",
            "risk_score": 0.1,
        }
        duplicate_events.append(event)
        print(f"  Event: {event['event_id']} (amount={event['amount']})")

    # Send each event 3 times (simulating at-least-once + retries)
    all_records = duplicate_events * 3  # 30 records, 10 unique
    send_events(all_records)
    print(f"  Sent {len(all_records)} records ({len(duplicate_events)} unique)")
    print(f"  Silver zone DT will deduplicate to {len(duplicate_events)} rows")

    # =========================================================================
    # PHASE 2: LATE-ARRIVING events (event_time in the past)
    # =========================================================================
    print("\n[Phase 2] Injecting LATE-ARRIVING events...")

    late_events = []
    for hours_late in [1, 6, 12, 24, 48, 72]:
        late_time = datetime.now(timezone.utc) - timedelta(hours=hours_late)
        event = {
            "event_id": f"LATE-{uuid.uuid4().hex[:8]}",
            "event_time": late_time.isoformat(),
            "event_type": "ALERT",
            "member_id": f"MBR{200000 + hours_late}",
            "institution_id": "FI10002",
            "amount": round(hours_late * 100.0, 2),
            "channel": "ATM",
            "risk_score": 0.85,
        }
        late_events.append(event)
        print(f"  Event: {event['event_id']} ({hours_late}h late)")

    send_events(late_events)
    print(f"  Sent {len(late_events)} late-arriving events")

    # =========================================================================
    # PHASE 3: BURST of events (high velocity)
    # =========================================================================
    print("\n[Phase 3] Injecting BURST (1000 events)...")

    burst_events = []
    for i in range(1000):
        event = {
            "event_id": f"BURST-{uuid.uuid4().hex[:8]}",
            "event_time": datetime.now(timezone.utc).isoformat(),
            "event_type": "CARD_SWIPE",
            "member_id": f"MBR{300000 + (i % 50)}",
            "institution_id": f"FI{10000 + (i % 10)}",
            "amount": round(5.0 + (i % 100), 2),
            "channel": "POS",
            "risk_score": round(0.01 * (i % 100), 2),
        }
        burst_events.append(event)

    start = time.time()
    send_events(burst_events)
    duration = time.time() - start
    print(f"  Sent 1000 burst events in {duration:.2f}s ({1000/duration:.0f} events/sec)")

    # =========================================================================
    # Summary
    # =========================================================================
    print(f"\n{'=' * 70}")
    print("Anomalies injected via Kinesis Firehose.")
    print()
    print("Timeline:")
    print("  1. Firehose will buffer and deliver to S3 (60-300s)")
    print("  2. Snowpipe AUTO_INGEST loads files to Bronze (file-level exactly-once)")
    print("  3. Silver Dynamic Table deduplicates on event_id")
    print()
    print("Run 06_exactly_once_proof.sql AFTER Snowpipe processes the files.")
    print(f"{'=' * 70}")


if __name__ == "__main__":
    main()
