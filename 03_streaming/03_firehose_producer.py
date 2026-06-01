"""
=============================================================================
EWS POC - UC02 Step 3: Kinesis Firehose Producer (Event Generator)

PURPOSE: Simulate real-time event production by sending events to an
Amazon Kinesis Data Firehose delivery stream. Firehose buffers events
and delivers them as files to S3, where Snowpipe AUTO_INGEST picks them up.

ARCHITECTURE:
  This script → Kinesis Firehose → S3 (buffered files) → Snowpipe → Bronze Iceberg

SNOWFLAKE ADVANTAGE: No custom consumer code on the Snowflake side. Firehose
handles buffering, compression, and delivery. Snowpipe AUTO_INGEST handles
pickup, scheduling, and loading — all serverless, all managed.

PREREQUISITES:
  pip install boto3

  AWS credentials configured (IAM role or access keys) with permission to
  put records into the Firehose delivery stream.

USAGE:
  python 03_firehose_producer.py
=============================================================================
"""

import json
import time
import uuid
import random
from datetime import datetime, timezone

import boto3


# =============================================================================
# Configuration
# =============================================================================

FIREHOSE_STREAM_NAME = "<EWS_FIREHOSE_DELIVERY_STREAM>"  # Replace with actual stream name
AWS_REGION = "us-east-1"  # Replace with actual region

# Firehose client
firehose_client = boto3.client("firehose", region_name=AWS_REGION)


def generate_event() -> dict:
    """Generate a simulated real-time payment/fraud event."""
    event_types = ["TXN", "ALERT", "LOGIN", "CARD_SWIPE"]
    channels = ["ONLINE", "POS", "ATM", "MOBILE"]
    institutions = [f"FI{10000 + i}" for i in range(50)]
    members = [f"MBR{100000 + i}" for i in range(10000)]

    return {
        "event_id": str(uuid.uuid4()),
        "event_time": datetime.now(timezone.utc).isoformat(),
        "event_type": random.choice(event_types),
        "member_id": random.choice(members),
        "institution_id": random.choice(institutions),
        "amount": round(random.uniform(1.00, 5000.00), 2),
        "channel": random.choice(channels),
        "device_id": f"DEV-{uuid.uuid4().hex[:12]}",
        "ip_address": f"{random.randint(1,255)}.{random.randint(0,255)}.{random.randint(0,255)}.{random.randint(1,254)}",
        "geo_lat": round(random.uniform(25.0, 48.0), 7),
        "geo_lon": round(random.uniform(-125.0, -70.0), 7),
        "risk_score": round(random.uniform(0.0, 1.0), 2),
    }


def send_batch(batch_size: int = 500) -> dict:
    """Send a batch of records to Kinesis Firehose (max 500 per PutRecordBatch)."""
    records = []
    for _ in range(batch_size):
        event = generate_event()
        # Firehose expects each record as bytes with newline delimiter
        record_data = json.dumps(event) + "\n"
        records.append({"Data": record_data.encode("utf-8")})

    response = firehose_client.put_record_batch(
        DeliveryStreamName=FIREHOSE_STREAM_NAME,
        Records=records,
    )
    return response


def main():
    print("=" * 70)
    print("EWS POC - Kinesis Firehose Event Producer")
    print("=" * 70)
    print()
    print(f"Delivery Stream: {FIREHOSE_STREAM_NAME}")
    print(f"Region: {AWS_REGION}")
    print()
    print("Architecture:")
    print("  This script → Kinesis Firehose → S3 → Snowpipe AUTO_INGEST → Bronze Iceberg")
    print()
    print("Firehose buffers events and delivers to S3 every 60-300 seconds.")
    print("Snowpipe picks up new files automatically (serverless, no compute to manage).")
    print()

    total_events = 0
    total_batches = 20  # 20 batches x 500 = 10,000 events
    batch_size = 500

    print(f"Sending {total_batches * batch_size:,} events in {total_batches} batches...")
    print()
    print(f"{'Batch':<8} {'Events Sent':<15} {'Failed':<10} {'Latency (ms)'}")
    print("-" * 55)

    for batch_num in range(1, total_batches + 1):
        start = time.time()
        response = send_batch(batch_size)
        latency_ms = (time.time() - start) * 1000

        failed = response.get("FailedPutCount", 0)
        total_events += batch_size - failed

        print(f"{batch_num:<8} {total_events:<15,} {failed:<10} {latency_ms:.0f}")

        # Throttle slightly to avoid Firehose limits
        time.sleep(0.2)

    print()
    print(f"{'=' * 70}")
    print(f"COMPLETE: {total_events:,} events sent to Firehose")
    print()
    print("Next steps:")
    print("  1. Firehose will buffer and deliver files to S3 (60-300s)")
    print("  2. S3 event notification triggers Snowpipe SQS queue")
    print("  3. Snowpipe AUTO_INGEST loads files into BRONZE.STREAMING_EVENTS")
    print("  4. Run 06_exactly_once_proof.sql to validate data landed")
    print(f"{'=' * 70}")


if __name__ == "__main__":
    main()
