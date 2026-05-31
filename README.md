# Early Warning Services (EWS) - Snowflake Proof of Concept

## Executive Summary

This Proof of Concept demonstrates that Snowflake delivers a **complete, unified data platform** for Early Warning Services — replacing dozens of disparate tools with a single engine. All data remains in **EWS-owned S3 buckets** using the **Apache Iceberg** open table format. Snowflake provides compute-only access with full ACID compliance, sub-second streaming, declarative pipelines, native AI, and zero-copy data sharing.

**Architecture Principle:** Every component runs natively within Snowflake. No Kafka. No Airflow. No external feature store. No separate governance tool. No external LLM infrastructure.

---

## Architecture Overview

<svg viewBox="0 0 1200 680" xmlns="http://www.w3.org/2000/svg" style="background:#ffffff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
  <!-- Title -->
  <text x="600" y="40" text-anchor="middle" font-size="22" font-weight="bold" fill="#1a1a2e">EWS POC — Snowflake Compute-Only Architecture</text>
  <text x="600" y="62" text-anchor="middle" font-size="13" fill="#666">Data remains in EWS-owned S3 (Iceberg) | Snowflake provides compute, governance, and AI</text>

  <!-- EWS S3 Layer -->
  <rect x="30" y="90" width="1140" height="80" rx="8" fill="#fff3e0" stroke="#e65100" stroke-width="1.5"/>
  <text x="60" y="115" font-size="12" font-weight="bold" fill="#e65100">EWS-OWNED S3 (Apache Iceberg Format)</text>
  <rect x="60" y="125" width="140" height="32" rx="4" fill="#ffffff" stroke="#e65100" stroke-width="1"/>
  <text x="130" y="146" text-anchor="middle" font-size="10" fill="#333">Bronze Iceberg</text>
  <rect x="220" y="125" width="140" height="32" rx="4" fill="#ffffff" stroke="#e65100" stroke-width="1"/>
  <text x="290" y="146" text-anchor="middle" font-size="10" fill="#333">Silver Iceberg</text>
  <rect x="380" y="125" width="140" height="32" rx="4" fill="#ffffff" stroke="#e65100" stroke-width="1"/>
  <text x="450" y="146" text-anchor="middle" font-size="10" fill="#333">Gold Iceberg</text>
  <rect x="540" y="125" width="160" height="32" rx="4" fill="#ffffff" stroke="#e65100" stroke-width="1"/>
  <text x="620" y="146" text-anchor="middle" font-size="10" fill="#333">Feature Store Iceberg</text>
  <rect x="720" y="125" width="160" height="32" rx="4" fill="#ffffff" stroke="#e65100" stroke-width="1"/>
  <text x="800" y="146" text-anchor="middle" font-size="10" fill="#333">Metadata + Snapshots</text>
  <rect x="900" y="125" width="240" height="32" rx="4" fill="#ffffff" stroke="#e65100" stroke-width="1"/>
  <text x="1020" y="146" text-anchor="middle" font-size="10" fill="#333">External Volume (ALLOW_WRITES=TRUE)</text>

  <!-- Snowflake Compute Layer -->
  <rect x="30" y="190" width="1140" height="420" rx="10" fill="#e3f2fd" stroke="#29B5E8" stroke-width="2"/>
  <text x="60" y="215" font-size="14" font-weight="bold" fill="#0277bd">SNOWFLAKE COMPUTE LAYER</text>

  <!-- Ingestion Zone -->
  <rect x="50" y="230" width="340" height="160" rx="6" fill="#ffffff" stroke="#1565c0" stroke-width="1.5"/>
  <text x="70" y="252" font-size="11" font-weight="bold" fill="#1565c0">INGESTION</text>
  <rect x="65" y="262" width="145" height="50" rx="4" fill="#e8f5e9" stroke="#2e7d32" stroke-width="1"/>
  <text x="137" y="282" text-anchor="middle" font-size="9" font-weight="bold" fill="#2e7d32">Batch (UC01)</text>
  <text x="137" y="298" text-anchor="middle" font-size="8" fill="#333">COPY INTO + DMFs</text>
  <rect x="225" y="262" width="150" height="50" rx="4" fill="#e8f5e9" stroke="#2e7d32" stroke-width="1"/>
  <text x="300" y="282" text-anchor="middle" font-size="9" font-weight="bold" fill="#2e7d32">Streaming (UC02)</text>
  <text x="300" y="298" text-anchor="middle" font-size="8" fill="#333">Snowpipe Streaming</text>
  <rect x="65" y="322" width="310" height="55" rx="4" fill="#fce4ec" stroke="#c62828" stroke-width="1"/>
  <text x="220" y="342" text-anchor="middle" font-size="9" font-weight="bold" fill="#c62828">Error Handling</text>
  <text x="220" y="358" text-anchor="middle" font-size="8" fill="#333">ON_ERROR=CONTINUE | VALIDATE() | Dead Letter Table</text>
  <text x="220" y="372" text-anchor="middle" font-size="8" fill="#333">Partial acceptance without aborting batch</text>

  <!-- Pipeline Zone -->
  <rect x="410" y="230" width="360" height="160" rx="6" fill="#ffffff" stroke="#1565c0" stroke-width="1.5"/>
  <text x="430" y="252" font-size="11" font-weight="bold" fill="#1565c0">PIPELINE (UC03)</text>
  <rect x="425" y="262" width="100" height="45" rx="4" fill="#fff8e1" stroke="#f57f17" stroke-width="1"/>
  <text x="475" y="280" text-anchor="middle" font-size="9" font-weight="bold" fill="#f57f17">Bronze</text>
  <text x="475" y="296" text-anchor="middle" font-size="8" fill="#333">Raw</text>
  <!-- Arrow -->
  <path d="M530 284 L545 284" stroke="#333" stroke-width="1.5" marker-end="url(#arrowhead)"/>
  <rect x="550" y="262" width="100" height="45" rx="4" fill="#e8eaf6" stroke="#283593" stroke-width="1"/>
  <text x="600" y="280" text-anchor="middle" font-size="9" font-weight="bold" fill="#283593">Silver</text>
  <text x="600" y="296" text-anchor="middle" font-size="8" fill="#333">Dynamic Table</text>
  <!-- Arrow -->
  <path d="M655 284 L670 284" stroke="#333" stroke-width="1.5" marker-end="url(#arrowhead)"/>
  <rect x="675" y="262" width="80" height="45" rx="4" fill="#e0f2f1" stroke="#00695c" stroke-width="1"/>
  <text x="715" y="280" text-anchor="middle" font-size="9" font-weight="bold" fill="#00695c">Gold</text>
  <text x="715" y="296" text-anchor="middle" font-size="8" fill="#333">Dynamic Table</text>
  <rect x="425" y="320" width="330" height="58" rx="4" fill="#f3e5f5" stroke="#6a1b9a" stroke-width="1"/>
  <text x="590" y="340" text-anchor="middle" font-size="9" font-weight="bold" fill="#6a1b9a">Quality Gates (DMFs)</text>
  <text x="590" y="356" text-anchor="middle" font-size="8" fill="#333">Data Metric Functions block zone promotion</text>
  <text x="590" y="370" text-anchor="middle" font-size="8" fill="#333">Quarantine non-conforming records</text>

  <!-- Feature Store Zone -->
  <rect x="790" y="230" width="360" height="160" rx="6" fill="#ffffff" stroke="#1565c0" stroke-width="1.5"/>
  <text x="810" y="252" font-size="11" font-weight="bold" fill="#1565c0">FEATURE STORE (UC04-05)</text>
  <rect x="805" y="262" width="155" height="50" rx="4" fill="#e1f5fe" stroke="#0277bd" stroke-width="1"/>
  <text x="882" y="280" text-anchor="middle" font-size="9" font-weight="bold" fill="#0277bd">Online Features</text>
  <text x="882" y="296" text-anchor="middle" font-size="8" fill="#333">DT: 1-min lag from stream</text>
  <rect x="975" y="262" width="155" height="50" rx="4" fill="#e1f5fe" stroke="#0277bd" stroke-width="1"/>
  <text x="1052" y="280" text-anchor="middle" font-size="9" font-weight="bold" fill="#0277bd">Offline Features</text>
  <text x="1052" y="296" text-anchor="middle" font-size="8" fill="#333">Time Travel + Bi-temporal</text>
  <rect x="805" y="322" width="325" height="55" rx="4" fill="#e8f5e9" stroke="#2e7d32" stroke-width="1"/>
  <text x="967" y="342" text-anchor="middle" font-size="9" font-weight="bold" fill="#2e7d32">Rematerialization</text>
  <text x="967" y="358" text-anchor="middle" font-size="8" fill="#333">ALTER DYNAMIC TABLE REFRESH rebuilds from Gold</text>
  <text x="967" y="372" text-anchor="middle" font-size="8" fill="#333">No stream replay | No custom backfill</text>

  <!-- Analytics + AI Layer -->
  <rect x="50" y="405" width="540" height="100" rx="6" fill="#ffffff" stroke="#1565c0" stroke-width="1.5"/>
  <text x="70" y="427" font-size="11" font-weight="bold" fill="#1565c0">ANALYTICS + AI (UC09, UC13-14)</text>
  <rect x="65" y="437" width="155" height="55" rx="4" fill="#ede7f6" stroke="#4527a0" stroke-width="1"/>
  <text x="142" y="455" text-anchor="middle" font-size="9" font-weight="bold" fill="#4527a0">Multi-Cluster WH</text>
  <text x="142" y="471" text-anchor="middle" font-size="8" fill="#333">Auto-scale 1-10 clusters</text>
  <text x="142" y="484" text-anchor="middle" font-size="8" fill="#333">Query Acceleration</text>
  <rect x="235" y="437" width="155" height="55" rx="4" fill="#ede7f6" stroke="#4527a0" stroke-width="1"/>
  <text x="312" y="455" text-anchor="middle" font-size="9" font-weight="bold" fill="#4527a0">Cortex Analyst</text>
  <text x="312" y="471" text-anchor="middle" font-size="8" fill="#333">NL-to-SQL (native)</text>
  <text x="312" y="484" text-anchor="middle" font-size="8" fill="#333">Semantic YAML model</text>
  <rect x="405" y="437" width="170" height="55" rx="4" fill="#ede7f6" stroke="#4527a0" stroke-width="1"/>
  <text x="490" y="455" text-anchor="middle" font-size="9" font-weight="bold" fill="#4527a0">Cortex Agents + LLMs</text>
  <text x="490" y="471" text-anchor="middle" font-size="8" fill="#333">Agentic pipeline gen</text>
  <text x="490" y="484" text-anchor="middle" font-size="8" fill="#333">CORTEX.COMPLETE in SQL</text>

  <!-- Governance + Sharing Layer -->
  <rect x="610" y="405" width="540" height="100" rx="6" fill="#ffffff" stroke="#1565c0" stroke-width="1.5"/>
  <text x="630" y="427" font-size="11" font-weight="bold" fill="#1565c0">GOVERNANCE + SHARING (UC10-11)</text>
  <rect x="625" y="437" width="155" height="55" rx="4" fill="#fff3e0" stroke="#e65100" stroke-width="1"/>
  <text x="702" y="455" text-anchor="middle" font-size="9" font-weight="bold" fill="#e65100">Snowflake Horizon</text>
  <text x="702" y="471" text-anchor="middle" font-size="8" fill="#333">Tags | Classification</text>
  <text x="702" y="484" text-anchor="middle" font-size="8" fill="#333">Row Access Policies</text>
  <rect x="795" y="437" width="155" height="55" rx="4" fill="#fff3e0" stroke="#e65100" stroke-width="1"/>
  <text x="872" y="455" text-anchor="middle" font-size="9" font-weight="bold" fill="#e65100">Data Sharing</text>
  <text x="872" y="471" text-anchor="middle" font-size="8" fill="#333">Zero-copy shares</text>
  <text x="872" y="484" text-anchor="middle" font-size="8" fill="#333">No ETL, instant access</text>
  <rect x="965" y="437" width="165" height="55" rx="4" fill="#fff3e0" stroke="#e65100" stroke-width="1"/>
  <text x="1047" y="455" text-anchor="middle" font-size="9" font-weight="bold" fill="#e65100">Marketplace</text>
  <text x="1047" y="471" text-anchor="middle" font-size="8" fill="#333">Vendor data (1 command)</text>
  <text x="1047" y="484" text-anchor="middle" font-size="8" fill="#333">Sanctions, fraud signals</text>

  <!-- Bottom bar -->
  <rect x="30" y="525" width="1140" height="35" rx="6" fill="#29B5E8" stroke="none"/>
  <text x="600" y="547" text-anchor="middle" font-size="12" font-weight="bold" fill="#ffffff">Snowflake AI Data Cloud — One Platform, Zero Data Movement, Full Governance</text>

  <!-- Snowflake logo indicator -->
  <circle cx="1130" y="547" r="12" fill="#ffffff"/>
  <text x="1130" y="552" text-anchor="middle" font-size="10" fill="#29B5E8" font-weight="bold">SF</text>

  <!-- Arrow marker definition -->
  <defs>
    <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
      <polygon points="0 0, 10 3.5, 0 7" fill="#333"/>
    </marker>
  </defs>
</svg>

---

## Use Cases

### UC01: Batch Ingestion — High-Volume Structured File Processing

**Requirement:** ACID-compliant, exactly-once writes to Bronze Iceberg tables from fixed-width, delimited, and EBCDIC bulk file drops. Must support partial-acceptance without aborting the batch.

<svg viewBox="0 0 900 320" xmlns="http://www.w3.org/2000/svg" style="background:#ffffff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
  <text x="450" y="30" text-anchor="middle" font-size="16" font-weight="bold" fill="#1a1a2e">UC01: Batch Ingestion with Partial Acceptance</text>

  <!-- Source Files -->
  <rect x="30" y="60" width="160" height="200" rx="6" fill="#f5f5f5" stroke="#757575" stroke-width="1.5"/>
  <text x="110" y="82" text-anchor="middle" font-size="11" font-weight="bold" fill="#333">Source Files (S3)</text>
  <rect x="45" y="95" width="130" height="30" rx="3" fill="#e8f5e9" stroke="#43a047"/>
  <text x="110" y="115" text-anchor="middle" font-size="9" fill="#333">Delimited (CSV/TSV)</text>
  <rect x="45" y="135" width="130" height="30" rx="3" fill="#e3f2fd" stroke="#1e88e5"/>
  <text x="110" y="155" text-anchor="middle" font-size="9" fill="#333">Fixed-Width</text>
  <rect x="45" y="175" width="130" height="30" rx="3" fill="#fff3e0" stroke="#fb8c00"/>
  <text x="110" y="195" text-anchor="middle" font-size="9" fill="#333">EBCDIC (converted)</text>
  <rect x="45" y="215" width="130" height="30" rx="3" fill="#fce4ec" stroke="#e53935"/>
  <text x="110" y="235" text-anchor="middle" font-size="9" fill="#333">Mixed valid + invalid</text>

  <!-- Arrow -->
  <path d="M195 160 L260 160" stroke="#333" stroke-width="2" marker-end="url(#arr1)"/>
  <text x="228" y="150" text-anchor="middle" font-size="8" fill="#666">COPY INTO</text>

  <!-- Snowflake Processing -->
  <rect x="265" y="70" width="320" height="190" rx="8" fill="#e3f2fd" stroke="#29B5E8" stroke-width="2"/>
  <text x="425" y="92" text-anchor="middle" font-size="11" font-weight="bold" fill="#0277bd">Snowflake Processing</text>
  <rect x="280" y="105" width="140" height="40" rx="4" fill="#ffffff" stroke="#1565c0"/>
  <text x="350" y="122" text-anchor="middle" font-size="9" font-weight="bold" fill="#1565c0">ON_ERROR=CONTINUE</text>
  <text x="350" y="137" text-anchor="middle" font-size="8" fill="#333">Partial acceptance</text>
  <rect x="435" y="105" width="135" height="40" rx="4" fill="#ffffff" stroke="#1565c0"/>
  <text x="502" y="122" text-anchor="middle" font-size="9" font-weight="bold" fill="#1565c0">VALIDATE()</text>
  <text x="502" y="137" text-anchor="middle" font-size="8" fill="#333">Extract rejects</text>
  <rect x="280" y="160" width="290" height="40" rx="4" fill="#ffffff" stroke="#6a1b9a"/>
  <text x="425" y="177" text-anchor="middle" font-size="9" font-weight="bold" fill="#6a1b9a">Data Metric Functions (DMFs)</text>
  <text x="425" y="193" text-anchor="middle" font-size="8" fill="#333">Null rate | Format validation | Range checks</text>
  <rect x="280" y="212" width="290" height="35" rx="4" fill="#e8f5e9" stroke="#2e7d32"/>
  <text x="425" y="234" text-anchor="middle" font-size="9" fill="#2e7d32">ACID-compliant writes to Iceberg</text>

  <!-- Output -->
  <path d="M590 140 L650 110" stroke="#2e7d32" stroke-width="2" marker-end="url(#arr1)"/>
  <path d="M590 180 L650 210" stroke="#c62828" stroke-width="2" marker-end="url(#arr1)"/>

  <rect x="655" y="75" width="210" height="55" rx="6" fill="#e8f5e9" stroke="#2e7d32" stroke-width="1.5"/>
  <text x="760" y="97" text-anchor="middle" font-size="10" font-weight="bold" fill="#2e7d32">Bronze Iceberg Table</text>
  <text x="760" y="115" text-anchor="middle" font-size="9" fill="#333">Valid records loaded</text>

  <rect x="655" y="185" width="210" height="55" rx="6" fill="#fce4ec" stroke="#c62828" stroke-width="1.5"/>
  <text x="760" y="207" text-anchor="middle" font-size="10" font-weight="bold" fill="#c62828">Dead Letter Table</text>
  <text x="760" y="225" text-anchor="middle" font-size="9" fill="#333">Rejected records + reason</text>

  <!-- Advantage callout -->
  <rect x="265" y="270" width="600" height="35" rx="4" fill="#29B5E8" stroke="none"/>
  <text x="565" y="292" text-anchor="middle" font-size="10" font-weight="bold" fill="#ffffff">Snowflake Advantage: Native partial acceptance + VALIDATE() — no custom Spark error handling needed</text>

  <defs><marker id="arr1" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto"><polygon points="0 0, 10 3.5, 0 7" fill="#333"/></marker></defs>
</svg>

**Snowflake Capabilities Deployed:**
- `COPY INTO` with `ON_ERROR = CONTINUE` for partial acceptance
- `VALIDATE()` function to extract rejected records (unique to Snowflake)
- Data Metric Functions (DMFs) for post-load quality enforcement
- External Iceberg Tables with full schema support

**What competitors would need:** Custom Spark exception handling + Great Expectations + separate dead-letter infrastructure + manual orchestration.

---

### UC02: Real-Time Streaming Ingestion — Sub-Second Event Processing

**Requirement:** Exactly-once streaming ingest to Bronze Iceberg with event-time ordering. Handle duplicate bursts natively. Single canonical event path — no dual writes.

<svg viewBox="0 0 900 300" xmlns="http://www.w3.org/2000/svg" style="background:#ffffff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
  <text x="450" y="30" text-anchor="middle" font-size="16" font-weight="bold" fill="#1a1a2e">UC02: Snowpipe Streaming — No Kafka Required</text>

  <!-- Event Source -->
  <rect x="30" y="70" width="150" height="160" rx="6" fill="#f5f5f5" stroke="#757575" stroke-width="1.5"/>
  <text x="105" y="92" text-anchor="middle" font-size="10" font-weight="bold" fill="#333">Event Sources</text>
  <rect x="45" y="105" width="120" height="25" rx="3" fill="#e8eaf6" stroke="#3949ab"/>
  <text x="105" y="122" text-anchor="middle" font-size="8" fill="#333">Transaction events</text>
  <rect x="45" y="138" width="120" height="25" rx="3" fill="#e8eaf6" stroke="#3949ab"/>
  <text x="105" y="155" text-anchor="middle" font-size="8" fill="#333">Fraud alerts</text>
  <rect x="45" y="171" width="120" height="25" rx="3" fill="#e8eaf6" stroke="#3949ab"/>
  <text x="105" y="188" text-anchor="middle" font-size="8" fill="#333">Member activity</text>
  <rect x="45" y="204" width="120" height="16" rx="3" fill="#ffcdd2" stroke="#e53935"/>
  <text x="105" y="215" text-anchor="middle" font-size="7" fill="#c62828">+ duplicates + late events</text>

  <!-- Arrow to SDK -->
  <path d="M185 150 L240 150" stroke="#333" stroke-width="2" marker-end="url(#arr2)"/>

  <!-- Snowpipe Streaming SDK -->
  <rect x="245" y="80" width="200" height="140" rx="8" fill="#e8f5e9" stroke="#2e7d32" stroke-width="2"/>
  <text x="345" y="102" text-anchor="middle" font-size="10" font-weight="bold" fill="#2e7d32">Snowpipe Streaming SDK</text>
  <text x="345" y="120" text-anchor="middle" font-size="9" fill="#333">Python / Java / Node.js</text>
  <rect x="260" y="130" width="170" height="25" rx="3" fill="#ffffff" stroke="#2e7d32"/>
  <text x="345" y="147" text-anchor="middle" font-size="8" fill="#333">channel.append_row(event)</text>
  <rect x="260" y="163" width="170" height="25" rx="3" fill="#ffffff" stroke="#2e7d32"/>
  <text x="345" y="180" text-anchor="middle" font-size="8" fill="#333">Offset-based exactly-once</text>
  <rect x="260" y="196" width="170" height="16" rx="3" fill="#c8e6c9" stroke="#2e7d32"/>
  <text x="345" y="207" text-anchor="middle" font-size="7" fill="#1b5e20">~20 lines of code total</text>

  <!-- Arrow to PIPE -->
  <path d="M450 150 L505 150" stroke="#333" stroke-width="2" marker-end="url(#arr2)"/>

  <!-- PIPE Object -->
  <rect x="510" y="90" width="160" height="120" rx="8" fill="#e3f2fd" stroke="#1565c0" stroke-width="2"/>
  <text x="590" y="112" text-anchor="middle" font-size="10" font-weight="bold" fill="#1565c0">PIPE Object</text>
  <text x="590" y="130" text-anchor="middle" font-size="8" fill="#333">Schema enforcement</text>
  <text x="590" y="145" text-anchor="middle" font-size="8" fill="#333">MATCH_BY_COLUMN_NAME</text>
  <text x="590" y="160" text-anchor="middle" font-size="8" fill="#333">Server-side validation</text>
  <rect x="525" y="170" width="130" height="25" rx="3" fill="#bbdefb" stroke="#1565c0"/>
  <text x="590" y="187" text-anchor="middle" font-size="8" fill="#0d47a1">Sub-second latency</text>

  <!-- Arrow to Iceberg -->
  <path d="M675 150 L730 150" stroke="#333" stroke-width="2" marker-end="url(#arr2)"/>

  <!-- Bronze Iceberg -->
  <rect x="735" y="80" width="140" height="140" rx="8" fill="#fff3e0" stroke="#e65100" stroke-width="2"/>
  <text x="805" y="105" text-anchor="middle" font-size="10" font-weight="bold" fill="#e65100">Bronze Iceberg</text>
  <text x="805" y="125" text-anchor="middle" font-size="9" fill="#333">EWS-owned S3</text>
  <rect x="748" y="137" width="114" height="22" rx="3" fill="#ffffff" stroke="#e65100"/>
  <text x="805" y="152" text-anchor="middle" font-size="8" fill="#333">Event-time ordered</text>
  <rect x="748" y="165" width="114" height="22" rx="3" fill="#ffffff" stroke="#e65100"/>
  <text x="805" y="180" text-anchor="middle" font-size="8" fill="#333">Deduplicated</text>
  <rect x="748" y="193" width="114" height="22" rx="3" fill="#ffffff" stroke="#e65100"/>
  <text x="805" y="208" text-anchor="middle" font-size="8" fill="#333">Immediately queryable</text>

  <!-- Eliminated components -->
  <rect x="245" y="240" width="630" height="45" rx="6" fill="#ffebee" stroke="#c62828" stroke-width="1"/>
  <text x="560" y="258" text-anchor="middle" font-size="9" font-weight="bold" fill="#c62828">ELIMINATED by Snowpipe Streaming:</text>
  <text x="560" y="275" text-anchor="middle" font-size="9" fill="#c62828">Kafka brokers | Kafka Connect | Schema Registry | Consumer groups | Exactly-once config | Monitoring stack</text>

  <defs><marker id="arr2" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto"><polygon points="0 0, 10 3.5, 0 7" fill="#333"/></marker></defs>
</svg>

**Snowflake Capabilities Deployed:**
- Snowpipe Streaming SDK (high-performance architecture)
- PIPE object with server-side schema enforcement
- Offset-based exactly-once delivery semantics
- Direct landing to Iceberg — immediately queryable

**What competitors would need:** Apache Kafka + Kafka Connect + Schema Registry + Consumer Groups + exactly-once configuration + monitoring infrastructure + custom deduplication logic.

---

### UC03: Data Pipeline Framework — Zone-Based Transformation

**Requirement:** Multi-hop Medallion pipeline (Bronze to Silver to Gold) with ACID-guaranteed writes at each zone boundary and quality gate hooks before data advances.

<svg viewBox="0 0 900 350" xmlns="http://www.w3.org/2000/svg" style="background:#ffffff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
  <text x="450" y="30" text-anchor="middle" font-size="16" font-weight="bold" fill="#1a1a2e">UC03: Declarative Pipeline — Dynamic Tables</text>
  <text x="450" y="50" text-anchor="middle" font-size="11" fill="#666">No orchestrator. No DAG definition. No cron. Snowflake infers and schedules everything.</text>

  <!-- Bronze -->
  <rect x="30" y="80" width="180" height="140" rx="8" fill="#fff8e1" stroke="#f57f17" stroke-width="2"/>
  <text x="120" y="102" text-anchor="middle" font-size="12" font-weight="bold" fill="#f57f17">BRONZE</text>
  <text x="120" y="118" text-anchor="middle" font-size="9" fill="#333">Raw Iceberg Tables</text>
  <rect x="45" y="128" width="150" height="20" rx="3" fill="#ffffff" stroke="#f57f17"/>
  <text x="120" y="142" text-anchor="middle" font-size="8" fill="#333">RAW_TRANSACTIONS</text>
  <rect x="45" y="155" width="150" height="20" rx="3" fill="#ffffff" stroke="#f57f17"/>
  <text x="120" y="169" text-anchor="middle" font-size="8" fill="#333">RAW_MEMBERS</text>
  <rect x="45" y="182" width="150" height="20" rx="3" fill="#ffffff" stroke="#f57f17"/>
  <text x="120" y="196" text-anchor="middle" font-size="8" fill="#333">STREAMING_EVENTS</text>

  <!-- Arrow with quality gate -->
  <path d="M215 150 L270 150" stroke="#6a1b9a" stroke-width="2" stroke-dasharray="5,3" marker-end="url(#arr3)"/>
  <rect x="225" y="130" width="40" height="16" rx="3" fill="#f3e5f5" stroke="#6a1b9a"/>
  <text x="245" y="141" text-anchor="middle" font-size="7" fill="#6a1b9a">DMF</text>

  <!-- Silver -->
  <rect x="275" y="80" width="220" height="140" rx="8" fill="#e8eaf6" stroke="#283593" stroke-width="2"/>
  <text x="385" y="102" text-anchor="middle" font-size="12" font-weight="bold" fill="#283593">SILVER</text>
  <text x="385" y="118" text-anchor="middle" font-size="9" fill="#333">Dynamic Tables (INCREMENTAL)</text>
  <rect x="290" y="128" width="190" height="22" rx="3" fill="#ffffff" stroke="#283593"/>
  <text x="385" y="143" text-anchor="middle" font-size="8" fill="#333">DT: CLEANSED_TRANSACTIONS</text>
  <rect x="290" y="155" width="190" height="22" rx="3" fill="#ffffff" stroke="#283593"/>
  <text x="385" y="170" text-anchor="middle" font-size="8" fill="#333">DT: ENRICHED_MEMBERS</text>
  <rect x="290" y="182" width="190" height="22" rx="3" fill="#ffffff" stroke="#283593"/>
  <text x="385" y="197" text-anchor="middle" font-size="8" fill="#333">DT: DEDUP_EVENTS</text>
  <text x="385" y="215" text-anchor="middle" font-size="8" fill="#283593" font-style="italic">TARGET_LAG = DOWNSTREAM</text>

  <!-- Arrow with quality gate -->
  <path d="M500 150 L555 150" stroke="#6a1b9a" stroke-width="2" stroke-dasharray="5,3" marker-end="url(#arr3)"/>
  <rect x="510" y="130" width="40" height="16" rx="3" fill="#f3e5f5" stroke="#6a1b9a"/>
  <text x="530" y="141" text-anchor="middle" font-size="7" fill="#6a1b9a">DMF</text>

  <!-- Gold -->
  <rect x="560" y="80" width="220" height="140" rx="8" fill="#e0f2f1" stroke="#00695c" stroke-width="2"/>
  <text x="670" y="102" text-anchor="middle" font-size="12" font-weight="bold" fill="#00695c">GOLD</text>
  <text x="670" y="118" text-anchor="middle" font-size="9" fill="#333">Dynamic Tables (INCREMENTAL)</text>
  <rect x="575" y="128" width="190" height="22" rx="3" fill="#ffffff" stroke="#00695c"/>
  <text x="670" y="143" text-anchor="middle" font-size="8" fill="#333">DT: DAILY_MEMBER_SUMMARY</text>
  <rect x="575" y="155" width="190" height="22" rx="3" fill="#ffffff" stroke="#00695c"/>
  <text x="670" y="170" text-anchor="middle" font-size="8" fill="#333">DT: FRAUD_SIGNALS</text>
  <rect x="575" y="182" width="190" height="22" rx="3" fill="#ffffff" stroke="#00695c"/>
  <text x="670" y="197" text-anchor="middle" font-size="8" fill="#333">DT: MEMBER_ACTIVITY</text>
  <text x="670" y="215" text-anchor="middle" font-size="8" fill="#00695c" font-style="italic">TARGET_LAG = '10 minutes'</text>

  <!-- Arrow to consumers -->
  <path d="M785 150 L830 150" stroke="#333" stroke-width="2" marker-end="url(#arr3)"/>

  <!-- Consumers -->
  <rect x="795" y="80" width="80" height="140" rx="6" fill="#ede7f6" stroke="#4527a0" stroke-width="1.5"/>
  <text x="835" y="120" text-anchor="middle" font-size="8" font-weight="bold" fill="#4527a0">BI</text>
  <text x="835" y="150" text-anchor="middle" font-size="8" font-weight="bold" fill="#4527a0">AI</text>
  <text x="835" y="180" text-anchor="middle" font-size="8" font-weight="bold" fill="#4527a0">Share</text>

  <!-- Key differentiators -->
  <rect x="30" y="240" width="845" height="95" rx="6" fill="#f5f5f5" stroke="#757575" stroke-width="1"/>
  <text x="50" y="262" font-size="10" font-weight="bold" fill="#1565c0">Why Dynamic Tables (not dbt + Airflow):</text>
  <text x="50" y="280" font-size="9" fill="#333">1. Declarative: Define WHAT, not HOW — Snowflake handles scheduling, ordering, and incremental logic</text>
  <text x="50" y="296" font-size="9" fill="#333">2. Auto-DAG: Dependencies inferred from SQL references — no manual DAG definition or YAML configs</text>
  <text x="50" y="312" font-size="9" fill="#333">3. Snapshot-consistent: Downstream always reads a coherent point-in-time view of upstream data</text>
  <text x="50" y="328" font-size="9" fill="#333">4. Incremental by default: Only processes changed rows — no custom merge logic or partition sensing</text>

  <defs><marker id="arr3" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto"><polygon points="0 0, 10 3.5, 0 7" fill="#333"/></marker></defs>
</svg>

**Snowflake Capabilities Deployed:**
- Dynamic Tables with `REFRESH_MODE = INCREMENTAL`
- `TARGET_LAG = DOWNSTREAM` for optimal scheduling
- Data Metric Functions as quality gates between zones
- Snowflake Tasks for quarantine enforcement

**What competitors would need:** dbt + Airflow (or Dagster/Prefect) + custom incremental logic + manual DAG definitions + separate quality tooling (Great Expectations/Soda).

---

### UC04: Real-Time Online Feature Store — Sub-Second Freshness

**Requirement:** Streaming path for freshness (1.5s p99) and Gold batch path for correctness. Full feature store rebuild from Gold history without stream replay.

**Snowflake Capabilities Deployed:**
- Dynamic Table with `TARGET_LAG = '1 minute'` fed by streaming data
- `ALTER DYNAMIC TABLE ... REFRESH` for one-command rebuild from Gold
- No separate feature store system (Feast, Tecton, Redis)

**What competitors would need:** Feast or Tecton + Redis/DynamoDB for online serving + custom backfill pipelines + separate batch/streaming code paths.

---

### UC05: Offline Feature Store — Point-in-Time Correct Batch Features

**Requirement:** Bi-temporal reconstruction recovering exact feature states at prior decision dates using business time vs. system time.

**Snowflake Capabilities Deployed:**
- Iceberg Time Travel via `AT(TIMESTAMP => ...)` — up to 90-day retention
- Snowpark Python for bi-temporal joins (runs inside Snowflake, no data movement)
- No separate snapshot management system

**What competitors would need:** Manual Iceberg snapshot management + custom point-in-time join frameworks + external compute (Spark/Pandas) with data shipped out.

---

### UC09: SQL Analytics Performance — Petabyte-Scale Complex Queries

**Requirement:** Petabyte-scale query performance on Gold Iceberg under concurrent load. 90-day lookback via Iceberg time travel.

<svg viewBox="0 0 900 280" xmlns="http://www.w3.org/2000/svg" style="background:#ffffff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
  <text x="450" y="30" text-anchor="middle" font-size="16" font-weight="bold" fill="#1a1a2e">UC09: Elastic Multi-Cluster Performance</text>

  <!-- Concurrent Users -->
  <rect x="30" y="55" width="130" height="190" rx="6" fill="#f5f5f5" stroke="#757575" stroke-width="1.5"/>
  <text x="95" y="75" text-anchor="middle" font-size="9" font-weight="bold" fill="#333">Concurrent Users</text>
  <circle cx="60" cy="100" r="12" fill="#e8eaf6" stroke="#3949ab"/>
  <text x="60" y="104" text-anchor="middle" font-size="7" fill="#3949ab">BI</text>
  <circle cx="95" cy="100" r="12" fill="#e8eaf6" stroke="#3949ab"/>
  <text x="95" y="104" text-anchor="middle" font-size="7" fill="#3949ab">BI</text>
  <circle cx="130" cy="100" r="12" fill="#e8eaf6" stroke="#3949ab"/>
  <text x="130" y="104" text-anchor="middle" font-size="7" fill="#3949ab">BI</text>
  <circle cx="60" cy="135" r="12" fill="#ede7f6" stroke="#6a1b9a"/>
  <text x="60" y="139" text-anchor="middle" font-size="7" fill="#6a1b9a">DS</text>
  <circle cx="95" cy="135" r="12" fill="#ede7f6" stroke="#6a1b9a"/>
  <text x="95" y="139" text-anchor="middle" font-size="7" fill="#6a1b9a">DS</text>
  <circle cx="130" cy="135" r="12" fill="#ede7f6" stroke="#6a1b9a"/>
  <text x="130" y="139" text-anchor="middle" font-size="7" fill="#6a1b9a">DS</text>
  <circle cx="60" cy="170" r="12" fill="#fff3e0" stroke="#e65100"/>
  <text x="60" y="174" text-anchor="middle" font-size="7" fill="#e65100">App</text>
  <circle cx="95" cy="170" r="12" fill="#fff3e0" stroke="#e65100"/>
  <text x="95" y="174" text-anchor="middle" font-size="7" fill="#e65100">App</text>
  <circle cx="130" cy="170" r="12" fill="#fff3e0" stroke="#e65100"/>
  <text x="130" y="174" text-anchor="middle" font-size="7" fill="#e65100">App</text>
  <text x="95" y="210" text-anchor="middle" font-size="8" fill="#333">50+ concurrent</text>
  <text x="95" y="224" text-anchor="middle" font-size="8" fill="#333">queries</text>

  <!-- Arrow -->
  <path d="M165 150 L215 150" stroke="#333" stroke-width="2" marker-end="url(#arr4)"/>

  <!-- Multi-cluster warehouse -->
  <rect x="220" y="55" width="350" height="190" rx="8" fill="#e3f2fd" stroke="#29B5E8" stroke-width="2"/>
  <text x="395" y="77" text-anchor="middle" font-size="11" font-weight="bold" fill="#0277bd">Multi-Cluster Warehouse (Auto-Scale)</text>
  <!-- Clusters -->
  <rect x="235" y="90" width="65" height="55" rx="4" fill="#ffffff" stroke="#1565c0" stroke-width="1.5"/>
  <text x="267" y="112" text-anchor="middle" font-size="8" font-weight="bold" fill="#1565c0">Cluster 1</text>
  <text x="267" y="130" text-anchor="middle" font-size="7" fill="#333">XLARGE</text>
  <rect x="310" y="90" width="65" height="55" rx="4" fill="#ffffff" stroke="#1565c0" stroke-width="1.5"/>
  <text x="342" y="112" text-anchor="middle" font-size="8" font-weight="bold" fill="#1565c0">Cluster 2</text>
  <text x="342" y="130" text-anchor="middle" font-size="7" fill="#333">XLARGE</text>
  <rect x="385" y="90" width="65" height="55" rx="4" fill="#ffffff" stroke="#1565c0" stroke-width="1.5"/>
  <text x="417" y="112" text-anchor="middle" font-size="8" font-weight="bold" fill="#1565c0">Cluster 3</text>
  <text x="417" y="130" text-anchor="middle" font-size="7" fill="#333">XLARGE</text>
  <rect x="460" y="90" width="65" height="55" rx="4" fill="#e0e0e0" stroke="#9e9e9e" stroke-dasharray="3,3"/>
  <text x="492" y="112" text-anchor="middle" font-size="8" fill="#9e9e9e">...N</text>
  <text x="492" y="130" text-anchor="middle" font-size="7" fill="#9e9e9e">up to 10</text>
  <!-- Features -->
  <rect x="235" y="155" width="120" height="22" rx="3" fill="#bbdefb" stroke="#1565c0"/>
  <text x="295" y="170" text-anchor="middle" font-size="8" fill="#0d47a1">Query Acceleration</text>
  <rect x="365" y="155" width="120" height="22" rx="3" fill="#bbdefb" stroke="#1565c0"/>
  <text x="425" y="170" text-anchor="middle" font-size="8" fill="#0d47a1">Result Cache</text>
  <rect x="235" y="185" width="120" height="22" rx="3" fill="#c8e6c9" stroke="#2e7d32"/>
  <text x="295" y="200" text-anchor="middle" font-size="8" fill="#1b5e20">Per-second billing</text>
  <rect x="365" y="185" width="120" height="22" rx="3" fill="#c8e6c9" stroke="#2e7d32"/>
  <text x="425" y="200" text-anchor="middle" font-size="8" fill="#1b5e20">Auto-suspend 60s</text>
  <text x="395" y="235" text-anchor="middle" font-size="8" fill="#0277bd" font-style="italic">Scales from 1 to 10 clusters based on queue depth</text>

  <!-- Arrow to data -->
  <path d="M575 150 L630 150" stroke="#333" stroke-width="2" marker-end="url(#arr4)"/>

  <!-- Gold Iceberg -->
  <rect x="635" y="55" width="235" height="190" rx="8" fill="#e0f2f1" stroke="#00695c" stroke-width="2"/>
  <text x="752" y="77" text-anchor="middle" font-size="11" font-weight="bold" fill="#00695c">Gold Iceberg (100GB+)</text>
  <rect x="650" y="92" width="205" height="30" rx="4" fill="#ffffff" stroke="#00695c"/>
  <text x="752" y="112" text-anchor="middle" font-size="9" fill="#333">Standard queries (current data)</text>
  <rect x="650" y="130" width="205" height="45" rx="4" fill="#fff3e0" stroke="#e65100"/>
  <text x="752" y="148" text-anchor="middle" font-size="9" font-weight="bold" fill="#e65100">90-Day Time Travel</text>
  <text x="752" y="166" text-anchor="middle" font-size="8" fill="#333">AT(TIMESTAMP => -90 days)</text>
  <rect x="650" y="183" width="205" height="30" rx="4" fill="#f3e5f5" stroke="#6a1b9a"/>
  <text x="752" y="203" text-anchor="middle" font-size="9" fill="#6a1b9a">Latency measured via QUERY_HISTORY</text>
  <text x="752" y="235" text-anchor="middle" font-size="8" fill="#00695c" font-style="italic">Iceberg snapshots = free time travel</text>

  <defs><marker id="arr4" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto"><polygon points="0 0, 10 3.5, 0 7" fill="#333"/></marker></defs>
</svg>

**Snowflake Capabilities Deployed:**
- Multi-cluster warehouses (auto-scale 1 to 10 clusters on queue depth)
- Query Acceleration Service (automatic large-scan optimization)
- Result caching (identical queries return in milliseconds)
- Per-second billing with auto-suspend
- Iceberg Time Travel for 90-day lookback (native, no separate system)

**What competitors would need:** Manual EMR/Databricks cluster autoscaling policies + external caching layers (Redis/Alluxio) + per-hour billing waste + custom snapshot management for time travel.

---

### UC10: Self-Service Analytics and BI Consumption

**Requirement:** UI-based catalog browsability, SQL-first access for non-engineers, and BI connector query push-down with SSO pass-through and RBAC.

**Snowflake Capabilities Deployed:**
- Snowflake Horizon (unified catalog, lineage, classification)
- Row Access Policies (native row-level security, no view hacks)
- Tag-based governance and automatic masking
- SSO + Network Policies for Tableau/Power BI
- Functional role hierarchy following Snowflake best practices

**What competitors would need:** Collibra or Alation (catalog) + custom RBAC views + Apache Ranger (row-level security) + separate classification tools.

---

### UC11: Data Marketplace and Semantic Layer

**Requirement:** Data product registration and ability to ingest vendor marketplace data shares into the EWS environment.

**Snowflake Capabilities Deployed:**
- Secure Data Sharing (zero-copy, live data, no ETL)
- Snowflake Marketplace (consume vendor data with one SQL command)
- No API development, no S3 copies, no data movement

**What competitors would need:** Custom API integrations + S3 copy jobs + ETL pipelines + data reconciliation processes for each vendor feed.

---

### UC13: Conversational Analytics — Natural Language Query

**Requirement:** Natural language to SQL generation against Gold Iceberg tables with multi-table joins and conversational refinement.

<svg viewBox="0 0 900 300" xmlns="http://www.w3.org/2000/svg" style="background:#ffffff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
  <text x="450" y="30" text-anchor="middle" font-size="16" font-weight="bold" fill="#1a1a2e">UC13: Cortex Analyst — Native NL-to-SQL</text>
  <text x="450" y="50" text-anchor="middle" font-size="11" fill="#666">No external LLM infrastructure. No vector database. No RAG pipeline. All within Snowflake.</text>

  <!-- User -->
  <rect x="30" y="80" width="180" height="130" rx="6" fill="#f5f5f5" stroke="#757575" stroke-width="1.5"/>
  <text x="120" y="100" text-anchor="middle" font-size="10" font-weight="bold" fill="#333">Analyst / Business User</text>
  <rect x="42" y="110" width="156" height="25" rx="12" fill="#e3f2fd" stroke="#1565c0"/>
  <text x="120" y="127" text-anchor="middle" font-size="8" fill="#0d47a1">"Show me fraud by region"</text>
  <rect x="42" y="142" width="156" height="25" rx="12" fill="#e3f2fd" stroke="#1565c0"/>
  <text x="120" y="159" text-anchor="middle" font-size="8" fill="#0d47a1">"Filter to last 30 days"</text>
  <rect x="42" y="174" width="156" height="25" rx="12" fill="#e3f2fd" stroke="#1565c0"/>
  <text x="120" y="191" text-anchor="middle" font-size="8" fill="#0d47a1">"Compare to prior quarter"</text>

  <!-- Arrow -->
  <path d="M215 145 L265 145" stroke="#333" stroke-width="2" marker-end="url(#arr5)"/>

  <!-- Cortex Analyst -->
  <rect x="270" y="70" width="280" height="150" rx="8" fill="#ede7f6" stroke="#4527a0" stroke-width="2"/>
  <text x="410" y="92" text-anchor="middle" font-size="11" font-weight="bold" fill="#4527a0">Cortex Analyst</text>
  <rect x="285" y="103" width="250" height="30" rx="4" fill="#ffffff" stroke="#4527a0"/>
  <text x="410" y="115" text-anchor="middle" font-size="8" font-weight="bold" fill="#4527a0">Semantic YAML Model</text>
  <text x="410" y="128" text-anchor="middle" font-size="7" fill="#333">Tables, dimensions, measures, time dimensions</text>
  <rect x="285" y="140" width="120" height="25" rx="4" fill="#ffffff" stroke="#4527a0"/>
  <text x="345" y="157" text-anchor="middle" font-size="8" fill="#333">NL Understanding</text>
  <rect x="415" y="140" width="120" height="25" rx="4" fill="#ffffff" stroke="#4527a0"/>
  <text x="475" y="157" text-anchor="middle" font-size="8" fill="#333">SQL Generation</text>
  <rect x="285" y="172" width="250" height="25" rx="4" fill="#d1c4e9" stroke="#4527a0"/>
  <text x="410" y="189" text-anchor="middle" font-size="8" fill="#311b92">Multi-turn conversation context</text>
  <text x="410" y="215" text-anchor="middle" font-size="8" fill="#4527a0" font-style="italic">Runs inside Snowflake security perimeter</text>

  <!-- Arrow -->
  <path d="M555 145 L605 145" stroke="#333" stroke-width="2" marker-end="url(#arr5)"/>

  <!-- Gold Tables -->
  <rect x="610" y="70" width="260" height="150" rx="8" fill="#e0f2f1" stroke="#00695c" stroke-width="2"/>
  <text x="740" y="92" text-anchor="middle" font-size="11" font-weight="bold" fill="#00695c">Gold Iceberg Tables</text>
  <rect x="625" y="105" width="230" height="20" rx="3" fill="#ffffff" stroke="#00695c"/>
  <text x="740" y="119" text-anchor="middle" font-size="8" fill="#333">DAILY_MEMBER_SUMMARY</text>
  <rect x="625" y="130" width="230" height="20" rx="3" fill="#ffffff" stroke="#00695c"/>
  <text x="740" y="144" text-anchor="middle" font-size="8" fill="#333">FRAUD_SIGNALS</text>
  <rect x="625" y="155" width="230" height="20" rx="3" fill="#ffffff" stroke="#00695c"/>
  <text x="740" y="169" text-anchor="middle" font-size="8" fill="#333">MEMBER_ACTIVITY</text>
  <rect x="625" y="185" width="230" height="25" rx="4" fill="#c8e6c9" stroke="#2e7d32"/>
  <text x="740" y="202" text-anchor="middle" font-size="8" fill="#1b5e20">Multi-table joins executed automatically</text>

  <!-- Eliminated -->
  <rect x="270" y="240" width="600" height="45" rx="6" fill="#ffebee" stroke="#c62828" stroke-width="1"/>
  <text x="570" y="258" text-anchor="middle" font-size="9" font-weight="bold" fill="#c62828">ELIMINATED by Cortex Analyst:</text>
  <text x="570" y="275" text-anchor="middle" font-size="9" fill="#c62828">ThoughtSpot license | Custom RAG pipeline | Vector database | LLM hosting | Embedding infrastructure</text>

  <defs><marker id="arr5" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto"><polygon points="0 0, 10 3.5, 0 7" fill="#333"/></marker></defs>
</svg>

**Snowflake Capabilities Deployed:**
- Cortex Analyst with semantic YAML model
- Multi-turn conversational context
- REST API for programmatic access
- All processing within Snowflake governance boundary

**What competitors would need:** ThoughtSpot ($$$) or custom RAG pipeline (vector DB + embeddings + LLM hosting + prompt engineering + retrieval logic).

---

### UC14: Agentic AI for Data Engineering

**Requirement:** LLM-driven orchestration of data engineering tasks subject to human-in-the-loop review and CI/CD deployment gates.

**Snowflake Capabilities Deployed:**
- `SNOWFLAKE.CORTEX.COMPLETE` — call LLMs from SQL (no external API gateway)
- Cortex Agents — multi-step AI orchestration native to Snowflake
- Native Git Integration — version control without Jenkins/GitHub Actions
- All AI processing within Snowflake security perimeter (data never leaves)

**What competitors would need:** LangChain/CrewAI framework + external LLM hosting (OpenAI API) + GitHub Actions + custom CI/CD + data egress for LLM processing.

---

## Competitive Summary

| Use Case | Snowflake (This POC) | What Competitors Need |
|----------|---------------------|----------------------|
| **UC01** Batch Ingestion | `COPY INTO` + `VALIDATE()` + DMFs | Spark error handling + Great Expectations + dead-letter infra |
| **UC02** Streaming | Snowpipe Streaming SDK (20 lines) | Kafka + Connect + Schema Registry + consumer groups |
| **UC03** Pipeline | Dynamic Tables (declarative, auto-DAG) | dbt + Airflow + custom incremental logic + DAG YAML |
| **UC04** Online Features | DT with 1-min lag + ALTER REFRESH | Feast/Tecton + Redis + custom backfill pipelines |
| **UC05** Offline Features | `AT(TIMESTAMP)` on Iceberg | Manual snapshot management + custom PIT join framework |
| **UC09** Analytics Perf | Multi-cluster + Query Acceleration + Cache | Manual cluster scaling + Alluxio cache + per-hour billing |
| **UC10** Self-Service | Horizon + Row Access Policies + Tags | Collibra + Ranger + custom RBAC views |
| **UC11** Marketplace | Zero-copy Data Sharing (1 SQL command) | S3 copies + API development + ETL for each vendor |
| **UC13** NL Query | Cortex Analyst (native, secure) | ThoughtSpot or custom RAG + vector DB + LLM hosting |
| **UC14** Agentic AI | Cortex Agents + Git Integration | LangChain + OpenAI API + Jenkins + data egress |

---

## Deployment Prerequisites

| Item | Description |
|------|-------------|
| Snowflake Account | Enterprise edition or higher (for Iceberg, Cortex, Dynamic Tables) |
| AWS IAM Role | Trust policy granting Snowflake access to EWS S3 bucket |
| S3 Bucket | EWS-owned bucket with Iceberg-compatible directory structure |
| Key Pair | RSA key pair for Snowpipe Streaming SDK authentication |
| Network Policy | Allowlist for BI tools (Tableau, Power BI) IP ranges |

---

## Execution Order

```
1. Foundation (storage integration, external volume, database, roles)
2. Bronze Iceberg tables (batch + streaming targets)
3. Batch ingestion scripts (UC01)
4. Streaming pipeline (UC02)
5. Dynamic Table pipeline (UC03)
6. Feature stores (UC04-05)
7. Analytics warehouse + workloads (UC09)
8. Governance + sharing (UC10-11)
9. Cortex AI (UC13-14)
```

Each numbered directory in this project corresponds to a deployment phase. Scripts within each directory are numbered and must be executed in order.

---

## Project Structure

```
EWS POC/
├── README.md                          (this file)
├── EWS-POC-Prompt.md                  (source requirements)
├── 01_foundation/                     (storage, volumes, database, RBAC)
├── 02_batch_ingestion/                (UC01: COPY INTO, DMFs, dead letter)
├── 03_streaming/                      (UC02: Snowpipe Streaming SDK)
├── 04_pipeline/                       (UC03: Dynamic Tables + quality gates)
├── 05_feature_store/                  (UC04-05: online/offline features)
├── 06_analytics_perf/                 (UC09: multi-cluster, time travel)
├── 07_self_service/                   (UC10-11: Horizon, sharing, marketplace)
└── 08_cortex_ai/                      (UC13-14: Analyst, Agents, Git)
```

---

*Built for the Snowflake AI Data Cloud. One platform. Zero data movement. Full governance.*
