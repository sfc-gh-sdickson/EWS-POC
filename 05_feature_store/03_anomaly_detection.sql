/*=============================================================================
  EWS POC - EXTRA: Anomaly Detection (Snowflake ML Functions)
  
  PURPOSE: Train an anomaly detection model on daily aggregate spending to
  identify unusual patterns that may indicate fraud, system errors, or 
  operational anomalies.
  
  SNOWFLAKE ADVANTAGE: Native ML functions callable from SQL. No Spark. 
  No MLflow. No external model hosting. No GPU cluster. Train and infer
  in the same engine where the data lives.
=============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE EWS_POC;
USE WAREHOUSE ews_ai_wh;

-- =============================================================================
-- 1. PREPARE TRAINING AND DETECTION DATA
-- =============================================================================

-- Training data: all days except the most recent 7
CREATE OR REPLACE VIEW EWS_POC.ANALYTICS.AD_TRAINING_DATA AS
SELECT txn_date::TIMESTAMP_NTZ AS txn_date, 
       SUM(total_amount) AS total_daily_spend
FROM EWS_POC.GOLD.DAILY_MEMBER_SUMMARY
WHERE txn_date < DATEADD('day', -7, CURRENT_DATE())
GROUP BY txn_date ORDER BY txn_date;

-- Detection data: most recent 7 days
CREATE OR REPLACE VIEW EWS_POC.ANALYTICS.AD_DETECT_DATA AS
SELECT txn_date::TIMESTAMP_NTZ AS txn_date, 
       SUM(total_amount) AS total_daily_spend
FROM EWS_POC.GOLD.DAILY_MEMBER_SUMMARY
WHERE txn_date >= DATEADD('day', -7, CURRENT_DATE())
GROUP BY txn_date ORDER BY txn_date;

-- =============================================================================
-- 2. TRAIN ANOMALY DETECTION MODEL
-- =============================================================================

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION EWS_POC.ANALYTICS.SPENDING_ANOMALY_MODEL(
  INPUT_DATA => TABLE(EWS_POC.ANALYTICS.AD_TRAINING_DATA),
  TIMESTAMP_COLNAME => 'TXN_DATE',
  TARGET_COLNAME => 'TOTAL_DAILY_SPEND',
  LABEL_COLNAME => ''
);

-- =============================================================================
-- 3. DETECT ANOMALIES AND STORE RESULTS
-- =============================================================================

CREATE OR REPLACE TABLE EWS_POC.GOLD.SPENDING_ANOMALIES AS
SELECT * FROM TABLE(
  EWS_POC.ANALYTICS.SPENDING_ANOMALY_MODEL!DETECT_ANOMALIES(
    INPUT_DATA => TABLE(EWS_POC.ANALYTICS.AD_DETECT_DATA),
    TIMESTAMP_COLNAME => 'TXN_DATE',
    TARGET_COLNAME => 'TOTAL_DAILY_SPEND',
    CONFIG_OBJECT => {'prediction_interval': 0.95}
  )
);

-- =============================================================================
-- 4. VERIFY: Show anomalous days
-- =============================================================================

SELECT TS AS anomaly_date, Y AS actual_spend, FORECAST, 
       LOWER_BOUND, UPPER_BOUND, PERCENTILE, DISTANCE
FROM EWS_POC.GOLD.SPENDING_ANOMALIES
WHERE IS_ANOMALY = TRUE
ORDER BY TS;
