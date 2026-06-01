"""
=============================================================================
EWS POC - UC02 Step 5: Anomaly Injection Script

PURPOSE: Inject duplicate events and late-arriving events to prove that
Snowpipe Streaming handles these scenarios correctly via offset-based
exactly-once semantics.

USAGE:
  python 05_anomaly_injection.py
=============================================================================
"""

import json
import time
import uuid
from datetime import datetime, timezone, timedelta
from pathlib import Path

from snowpipe_streaming import SnowpipeStreamingClient


def load_profile(profile_path: str = "profile.json") -> dict:
    path = Path(__file__).parent / profile_path
    with open(path) as f:
        return json.load(f)


def main():
    print("=" * 70)
    print("EWS POC - Anomaly Injection: Duplicates + Late-Arriving Events")
    print("=" * 70)

    config = load_profile()
    client = SnowpipeStreamingClient(config)

    # =========================================================================
    # PHASE 1: Inject DUPLICATE events (same event_id sent multiple times)
    # The offset-based delivery ensures these are handled correctly
    # =========================================================================
    print("\n[Phase 1] Injecting DUPLICATE events...")

    channel = client.open_channel(
        channel_name="ews_anomaly_channel",
        offset_token="anomaly_start"
    )

    # Create 5 events that will be sent 3x each (15 total sends, 5 unique)
    duplicate_events = []
    for i in range(5):
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
        print(f"  Created event: {event['event_id']} (amount={event['amount']})")

    # Send each event 3 times (simulating network retries / at-least-once source)
    for attempt in range(3):
        for event in duplicate_events:
            channel.append_row(event)
        print(f"  Sent batch attempt {attempt + 1}/3 ({len(duplicate_events)} events)")

    print(f"  Total sends: {len(duplicate_events) * 3} (expecting {len(duplicate_events)} unique after dedup)")

    # =========================================================================
    # PHASE 2: Inject LATE-ARRIVING events (event_time in the past)
    # These should land correctly and be ordered by event_time in queries
    # =========================================================================
    print("\n[Phase 2] Injecting LATE-ARRIVING events...")

    late_events = []
    for hours_late in [1, 6, 12, 24, 72]:
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
        channel.append_row(event)
        print(f"  Injected: {event['event_id']} (event_time = {hours_late}h ago)")

    # =========================================================================
    # PHASE 3: Inject BURST of events (high velocity)
    # =========================================================================
    print("\n[Phase 3] Injecting BURST (500 events in <1 second)...")

    burst_start = time.time()
    for i in range(500):
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
        channel.append_row(event)
    burst_duration = time.time() - burst_start
    print(f"  500 events sent in {burst_duration:.3f}s ({500/burst_duration:.0f} events/sec)")

    # =========================================================================
    # Summary
    # =========================================================================
    statuses = client.get_channel_statuses([channel])
    for status in statuses:
        print(f"\n{'=' * 70}")
        print(f"Channel: {status.channel_name}")
        print(f"  Final offset: {status.offset_token}")
        print(f"  Error count: {status.error_count}")
        print(f"{'=' * 70}")

    print("\nAnomalies injected. Run 06_exactly_once_proof.sql to validate.")
    client.close()


if __name__ == "__main__":
    main()
