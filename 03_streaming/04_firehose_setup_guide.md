# EWS POC - UC02: Kinesis Firehose Configuration Guide

## Architecture

```
Event Sources → Kinesis Data Firehose → S3 (EWS-owned) → Snowpipe AUTO_INGEST → Bronze Iceberg
```

Kinesis Data Firehose handles buffering, batching, compression, and reliable delivery to S3.
Snowpipe AUTO_INGEST is serverless and picks up files automatically via S3 event notifications.

---

## Step 1: Create Kinesis Firehose Delivery Stream

In AWS Console (or via CloudFormation/Terraform):

```json
{
  "DeliveryStreamName": "ews-events-firehose",
  "DeliveryStreamType": "DirectPut",
  "S3DestinationConfiguration": {
    "RoleARN": "arn:aws:iam::<EWS_ACCOUNT>:role/firehose-delivery-role",
    "BucketARN": "arn:aws:s3:::<EWS_BUCKET_NAME>-landing",
    "Prefix": "firehose/events/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/",
    "ErrorOutputPrefix": "firehose/errors/",
    "BufferingHints": {
      "SizeInMBs": 64,
      "IntervalInSeconds": 60
    },
    "CompressionFormat": "UNCOMPRESSED",
    "CloudWatchLoggingOptions": {
      "Enabled": true,
      "LogGroupName": "/aws/kinesisfirehose/ews-events",
      "LogStreamName": "DestinationDelivery"
    }
  }
}
```

### Key Configuration Choices:
- **Buffer Interval: 60 seconds** — balances latency vs file count (Snowpipe has overhead per file)
- **Buffer Size: 64 MB** — ensures reasonable file sizes for efficient COPY INTO
- **No compression** — simplifies Snowpipe loading (or use GZIP with matching file format)
- **Partitioned prefix** — enables efficient time-based pruning

---

## Step 2: Configure S3 Event Notifications

After creating the Snowpipe pipe (see `01_streaming_pipe.sql`), get the SQS queue ARN:

```sql
SHOW PIPES LIKE 'EWS_FIREHOSE_PIPE' IN SCHEMA BRONZE;
-- Record the 'notification_channel' value (SQS ARN)
```

Then configure the S3 bucket event notification:

1. Go to AWS S3 Console → `<EWS_BUCKET_NAME>-landing` → Properties → Event notifications
2. Create notification:
   - **Name:** `snowpipe-firehose-events`
   - **Prefix:** `firehose/events/`
   - **Events:** `s3:ObjectCreated:*`
   - **Destination:** SQS Queue → Enter the ARN from SHOW PIPES output

---

## Step 3: IAM Permissions

The Firehose delivery role needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetBucketLocation",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::<EWS_BUCKET_NAME>-landing",
        "arn:aws:s3:::<EWS_BUCKET_NAME>-landing/firehose/*"
      ]
    }
  ]
}
```

---

## Step 4: Validate End-to-End

1. Run the producer: `python 03_firehose_producer.py`
2. Wait 60-120 seconds for Firehose buffer flush
3. Check Snowpipe status:
   ```sql
   SELECT SYSTEM$PIPE_STATUS('EWS_POC.BRONZE.EWS_FIREHOSE_PIPE');
   ```
4. Verify data landed:
   ```sql
   SELECT COUNT(*) FROM BRONZE.STREAMING_EVENTS
   WHERE _channel_name = 'kinesis_firehose'
     AND _ingest_time >= DATEADD('minute', -5, CURRENT_TIMESTAMP());
   ```

---

## Latency Expectations

| Component | Typical Latency |
|-----------|----------------|
| Producer → Firehose | < 100ms |
| Firehose buffer flush | 60-300s (configurable) |
| S3 event notification | < 5s |
| Snowpipe file pickup | < 60s |
| **End-to-end** | **~2-6 minutes** |

For sub-second requirements, use Snowpipe Streaming SDK instead. The Firehose approach
is ideal for near-real-time (minutes) with zero consumer infrastructure to manage.

---

## Snowflake Advantage vs Competitors

| Aspect | Snowflake (Snowpipe) | Competitor Approach |
|--------|---------------------|-------------------|
| Consumer code | Zero (AUTO_INGEST) | Custom Spark/Flink consumer |
| Infrastructure | Serverless, managed | Kafka Connect cluster + monitoring |
| Scaling | Automatic | Manual consumer group rebalancing |
| Exactly-once | File-level (S3 dedup) | Kafka transaction fencing |
| Cost model | Per-file (serverless credits) | Per-cluster-hour |
| Compression support | Native (GZIP, ZSTD, etc) | Custom decompression logic |
