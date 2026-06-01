"""
=============================================================================
EWS POC - UC05 Step 6: Bi-Temporal Join (Snowpark Python)

PURPOSE: Point-in-time correct feature retrieval using both business_time
(when event occurred) and system_time (when ingested). This handles
late-arriving corrections properly.

SNOWFLAKE ADVANTAGE: Snowpark runs INSIDE Snowflake — zero data movement.
Competitors ship data to external Spark/Pandas for complex joins.
=============================================================================
"""

from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, max as sf_max, lit, current_timestamp
from snowflake.snowpark.types import TimestampType
from datetime import datetime


def create_session() -> Session:
    """Create Snowpark session using connection parameters."""
    connection_params = {
        "account": "<ACCOUNT_IDENTIFIER>",
        "user": "<USER>",
        "password": "<PASSWORD>",  # Or use key-pair auth
        "role": "EWS_ENGINEER",
        "warehouse": "ews_analytics_wh",
        "database": "EWS_POC",
        "schema": "FEATURE_STORE",
    }
    return Session.builder.configs(connection_params).create()


def bitemporal_feature_retrieval(
    session: Session,
    decision_date: str,
    query_timestamp: str = None,
):
    """
    Retrieve point-in-time correct features for ML training.

    Uses bi-temporal logic:
      - business_date <= decision_date (feature must exist BEFORE decision)
      - system_time <= query_timestamp (handles late corrections)

    This ensures we never use future information (data leakage prevention).
    """

    if query_timestamp is None:
        query_timestamp = datetime.utcnow().isoformat()

    print(f"Bi-Temporal Feature Retrieval")
    print(f"  Decision Date (business time): {decision_date}")
    print(f"  Query Timestamp (system time): {query_timestamp}")
    print(f"  Logic: features WHERE business_date <= '{decision_date}'")
    print(f"         AND system_time <= '{query_timestamp}'")
    print()

    # Load feature table
    features = session.table("FEATURE_STORE.OFFLINE_MEMBER_FEATURES")

    # Apply bi-temporal filter
    # business_date: When the feature represents (must be before decision)
    # system_time: When the feature was computed (handles late corrections)
    pit_features = features.filter(
        (col("business_date") <= lit(decision_date)) &
        (col("system_time") <= lit(query_timestamp))
    )

    # For each member, get the LATEST feature row that satisfies the temporal constraint
    # This is the "as-of" join equivalent
    latest_features = pit_features.group_by("member_id").agg(
        sf_max("business_date").alias("latest_business_date"),
        sf_max("system_time").alias("latest_system_time"),
    )

    # Join back to get full feature vectors at the correct point in time
    result = pit_features.join(
        latest_features,
        (pit_features["member_id"] == latest_features["member_id"]) &
        (pit_features["business_date"] == latest_features["latest_business_date"]) &
        (pit_features["system_time"] == latest_features["latest_system_time"]),
    ).select(
        pit_features["member_id"],
        pit_features["institution_id"],
        pit_features["risk_tier"],
        pit_features["account_age_days"],
        pit_features["txn_count_30d"],
        pit_features["total_spend_30d"],
        pit_features["avg_txn_30d"],
        pit_features["channels_used_30d"],
        pit_features["open_alerts"],
        pit_features["business_date"],
        pit_features["system_time"],
    )

    return result


def main():
    print("=" * 70)
    print("EWS POC - Bi-Temporal Join for Point-in-Time Correct Features")
    print("=" * 70)
    print()
    print("Snowflake Advantage: This runs INSIDE Snowflake (zero data movement)")
    print("Competitors would ship data to external Spark/Pandas cluster")
    print()

    session = create_session()

    # Example: Get features as they were known on Jan 15, 2025
    # for a credit decision that was made on that date
    result = bitemporal_feature_retrieval(
        session=session,
        decision_date="2025-01-15",
        query_timestamp="2025-01-15T23:59:59",
    )

    print("Results (first 10 rows):")
    result.show(10)

    print(f"\nTotal members with PIT features: {result.count()}")

    session.close()


if __name__ == "__main__":
    main()
