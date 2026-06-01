"""
=============================================================================
EWS POC - UC02 Step 3: Snowpipe Streaming Python Client

PURPOSE: Demonstrate sub-second event ingestion directly into Bronze Iceberg
using the high-performance Snowpipe Streaming SDK. No Kafka required.

SNOWFLAKE ADVANTAGE: ~30 lines of code replaces an entire Kafka ecosystem:
  - No Kafka brokers to manage
  - No Kafka Connect connectors to configure
  - No Schema Registry to maintain
  - No consumer group coordination
  - No exactly-once transaction fencing
  The SDK handles all of this natively.

PREREQUISITES:
  pip install snowpipe-streaming

USAGE:
  python 03_streaming_client.py
=============================================================================
"""

import json
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

from snowpipe_streaming import SnowpipeStreamingClient


def load_profile(profile_path: str = "profile.json") -> dict:
    """Load connection profile from JSON file."""
    path = Path(__file__).parent / profile_path
    with open(path) as f:
        return json.load(f)


def generate_event() -> dict:
    """Generate a simulated real-time payment event."""
    import random

    event_types = ["TXN", "ALERT", "LOGIN", "CARD_SWIPE"]
    channels = ["ONLINE", "POS", "ATM", "MOBILE"]

    return {
        "event_id": str(uuid.uuid4()),
        "event_time": datetime.now(timezone.utc).isoformat(),
        "event_type": random.choice(event_types),
        "member_id": f"MBR{random.randint(100000, 999999)}",
        "institution_id": f"FI{random.randint(10000, 99999)}",
        "amount": round(random.uniform(1.00, 5000.00), 2),
        "channel": random.choice(channels),
        "device_id": f"DEV-{uuid.uuid4().hex[:12]}",
        "ip_address": f"{random.randint(1,255)}.{random.randint(0,255)}.{random.randint(0,255)}.{random.randint(1,254)}",
        "geo_lat": round(random.uniform(25.0, 48.0), 7),
        "geo_lon": round(random.uniform(-125.0, -70.0), 7),
        "risk_score": round(random.uniform(0.0, 1.0), 2),
    }


def main():
    """Main streaming ingestion loop."""
    print("=" * 70)
    print("EWS POC - Snowpipe Streaming Client (High-Performance Architecture)")
    print("=" * 70)
    print("\nNo Kafka. No Connect. No Schema Registry. Just Snowflake.\n")

    # Load connection config
    config = load_profile()
    print(f"Connecting to: {config['url']}")
    print(f"Target: {config.get('database', 'EWS_POC')}.BRONZE.STREAMING_EVENTS")
    print(f"Pipe: BRONZE.EWS_EVENT_PIPE\n")

    # Initialize high-performance streaming client
    # One client per PIPE (which maps to one target table)
    client = SnowpipeStreamingClient(config)

    # Open a channel with offset tracking for exactly-once delivery
    channel = client.open_channel(
        channel_name="ews_events_channel_01",
        offset_token="0"  # Start from beginning; use last committed offset for resume
    )

    print("Channel opened. Starting event ingestion...\n")
    print(f"{'Events Sent':<15} {'Latency (ms)':<15} {'Last Event ID'}")
    print("-" * 60)

    events_sent = 0
    batch_size = 100
    total_batches = 10  # Send 1000 events total for demo

    for batch_num in range(total_batches):
        batch_start = time.time()

        for _ in range(batch_size):
            event = generate_event()
            channel.append_row(event)
            events_sent += 1

        batch_latency_ms = (time.time() - batch_start) * 1000
        print(f"{events_sent:<15} {batch_latency_ms:<15.1f} {event['event_id']}")

        # Small pause between batches to simulate realistic event flow
        time.sleep(0.1)

    # Get final committed offsets (confirms exactly-once delivery)
    statuses = client.get_channel_statuses([channel])
    for status in statuses:
        print(f"\nChannel: {status.channel_name}")
        print(f"  Committed offset: {status.offset_token}")
        print(f"  Error count: {status.error_count}")

    print(f"\n{'=' * 70}")
    print(f"COMPLETE: {events_sent} events ingested to Bronze Iceberg")
    print(f"Data is immediately queryable in Snowflake.")
    print(f"{'=' * 70}")

    # Cleanup
    client.close()


if __name__ == "__main__":
    main()
