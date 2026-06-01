"""
=============================================================================
EWS POC - UC09: Concurrent Load Test

PURPOSE: Simulate 50+ concurrent BI users hitting Gold Iceberg tables to
demonstrate multi-cluster auto-scaling.

SNOWFLAKE ADVANTAGE: Warehouse scales from 1 to 10 clusters automatically
based on queue depth. Per-second billing. No manual tuning.
=============================================================================
"""

import concurrent.futures
import time
import random
from snowflake.connector import connect


CONNECTION_PARAMS = {
    "account": "<ACCOUNT_IDENTIFIER>",
    "user": "<USER>",
    "password": "<PASSWORD>",
    "role": "EWS_ANALYST",
    "warehouse": "ews_analytics_wh",
    "database": "EWS_POC",
    "schema": "GOLD",
}

QUERIES = [
    # BI Dashboard queries
    """SELECT institution_id, COUNT(*) AS signal_count, AVG(event_risk_score) AS avg_risk
       FROM GOLD.FRAUD_SIGNALS WHERE signal_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
       GROUP BY 1 ORDER BY signal_count DESC LIMIT 20""",

    """SELECT member_id, txn_count_30d, total_spend_30d, open_alerts
       FROM GOLD.MEMBER_ACTIVITY WHERE risk_tier = 'HIGH' ORDER BY total_spend_30d DESC LIMIT 50""",

    """SELECT txn_date, SUM(txn_count) AS daily_txns, SUM(total_amount) AS daily_volume
       FROM GOLD.DAILY_MEMBER_SUMMARY WHERE txn_date >= DATEADD('day', -30, CURRENT_DATE())
       GROUP BY 1 ORDER BY 1""",

    # Data scientist exploration queries
    """SELECT member_id, txn_date, txn_count, total_amount, max_risk_score,
       AVG(total_amount) OVER (PARTITION BY member_id ORDER BY txn_date ROWS 6 PRECEDING) AS rolling_7d_avg
       FROM GOLD.DAILY_MEMBER_SUMMARY WHERE txn_date >= DATEADD('day', -90, CURRENT_DATE())
       ORDER BY member_id, txn_date""",

    """SELECT institution_id, active_members_30d, total_txns_30d, alerts_30d,
       ROUND(alerts_30d / NULLIF(active_members_30d, 0)::FLOAT, 4) AS alert_rate
       FROM GOLD.INSTITUTION_SUMMARY ORDER BY alert_rate DESC""",
]


def run_query(query_id: int) -> dict:
    """Execute a single query and measure latency."""
    query = random.choice(QUERIES)
    start = time.time()
    try:
        conn = connect(**CONNECTION_PARAMS)
        cursor = conn.cursor()
        cursor.execute(query)
        rows = cursor.fetchall()
        elapsed = time.time() - start
        cursor.close()
        conn.close()
        return {"id": query_id, "status": "SUCCESS", "elapsed_sec": elapsed, "rows": len(rows)}
    except Exception as e:
        elapsed = time.time() - start
        return {"id": query_id, "status": "FAILED", "elapsed_sec": elapsed, "error": str(e)}


def main():
    print("=" * 70)
    print("EWS POC - Concurrent Load Test (Multi-Cluster Auto-Scaling)")
    print("=" * 70)

    num_concurrent = 50
    print(f"\nLaunching {num_concurrent} concurrent queries...")
    print(f"Warehouse: ews_analytics_wh (MAX_CLUSTER_COUNT=10)")
    print()

    start_time = time.time()

    with concurrent.futures.ThreadPoolExecutor(max_workers=num_concurrent) as executor:
        futures = [executor.submit(run_query, i) for i in range(num_concurrent)]
        results = [f.result() for f in concurrent.futures.as_completed(futures)]

    total_time = time.time() - start_time

    # Summary
    successes = [r for r in results if r["status"] == "SUCCESS"]
    failures = [r for r in results if r["status"] == "FAILED"]
    latencies = [r["elapsed_sec"] for r in successes]

    print(f"\n{'=' * 70}")
    print(f"RESULTS:")
    print(f"  Total queries: {num_concurrent}")
    print(f"  Successful: {len(successes)}")
    print(f"  Failed: {len(failures)}")
    print(f"  Total wall-clock time: {total_time:.2f}s")
    print(f"  Avg latency: {sum(latencies)/len(latencies):.2f}s")
    print(f"  P50 latency: {sorted(latencies)[len(latencies)//2]:.2f}s")
    print(f"  P95 latency: {sorted(latencies)[int(len(latencies)*0.95)]:.2f}s")
    print(f"  Max latency: {max(latencies):.2f}s")
    print(f"{'=' * 70}")


if __name__ == "__main__":
    main()
