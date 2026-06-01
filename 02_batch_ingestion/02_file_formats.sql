/*=============================================================================
  EWS POC - UC01 Step 2: File Formats
  
  PURPOSE: Define file format objects for all source file types EWS processes:
           delimited (CSV/TSV), fixed-width, and EBCDIC-converted files.
  
  SNOWFLAKE ADVANTAGE: Native support for complex file formats including
  fixed-width parsing without external pre-processing tools. Competitors
  require Spark custom readers or pre-processing Lambda functions.
=============================================================================*/

USE ROLE EWS_ENGINEER;
USE DATABASE EWS_POC;
USE SCHEMA BRONZE;

-- =============================================================================
-- Delimited Format: Standard CSV/TSV files (transactions)
-- =============================================================================

CREATE OR REPLACE FILE FORMAT ews_delimited_format
  TYPE = 'CSV'
  FIELD_DELIMITER = '|'
  RECORD_DELIMITER = '\n'
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL', 'null', '\\N')
  TRIM_SPACE = TRUE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
  DATE_FORMAT = 'YYYY-MM-DD'
  TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF3 TZHTZM'
  COMMENT = 'Pipe-delimited format for transaction files';

-- =============================================================================
-- Fixed-Width Format: Member profile records from legacy systems
-- Uses a custom approach: load as single-column then parse with SUBSTR
-- =============================================================================

CREATE OR REPLACE FILE FORMAT ews_fixed_width_format
  TYPE = 'CSV'
  FIELD_DELIMITER = 'NONE'
  RECORD_DELIMITER = '\n'
  SKIP_HEADER = 0
  TRIM_SPACE = FALSE
  COMMENT = 'Fixed-width format - records loaded as single column, parsed via SUBSTR in COPY transform';

-- =============================================================================
-- EBCDIC-Converted Format: Mainframe alert files (pre-converted to ASCII/UTF-8)
-- Assumes EBCDIC-to-ASCII conversion done at file transfer layer (e.g., MFT tool)
-- =============================================================================

CREATE OR REPLACE FILE FORMAT ews_ebcdic_converted_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  RECORD_DELIMITER = '\n'
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL', 'SPACES', '0000000000')
  TRIM_SPACE = TRUE
  ENCODING = 'UTF8'
  COMMENT = 'EBCDIC-converted format for mainframe alert files (pre-converted to ASCII at transfer)';

-- =============================================================================
-- JSON Format: For streaming event payloads and semi-structured data
-- =============================================================================

CREATE OR REPLACE FILE FORMAT ews_json_format
  TYPE = 'JSON'
  STRIP_OUTER_ARRAY = TRUE
  ALLOW_DUPLICATE = FALSE
  STRIP_NULL_VALUES = FALSE
  COMMENT = 'JSON format for streaming event files and API payloads';

-- =============================================================================
-- Validation
-- =============================================================================

SHOW FILE FORMATS IN SCHEMA BRONZE;
