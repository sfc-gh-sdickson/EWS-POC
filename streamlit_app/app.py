"""
EWS POC - Project Status Dashboard
Run: streamlit run app.py
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import json
from datetime import datetime, date, timedelta
from pathlib import Path

# =============================================================================
# Configuration
# =============================================================================

DATA_FILE = Path(__file__).parent / "project_data.json"

TEAM_MEMBERS = [
    "Unassigned",
    "Stephen Dickson",
    "Solutions Engineer",
    "Data Engineer",
    "ML Engineer",
    "Security Admin",
    "Cloud Ops",
    "EWS Contact",
]

STATUS_OPTIONS = ["Not Started", "In Progress", "Blocked", "Complete"]
STATUS_COLORS = {
    "Not Started": "#9e9e9e",
    "In Progress": "#1e88e5",
    "Blocked": "#e53935",
    "Complete": "#43a047",
}

# =============================================================================
# Data Persistence
# =============================================================================


def get_default_tasks():
    """Default task list matching the deployment Gantt chart."""
    return [
        # Phase 1
        {"id": "1.1", "phase": "Phase 1: Foundation", "task": "AWS IAM Trust Policy Setup", "owner": "Cloud Ops", "status": "Complete", "start": "2026-06-02", "days": 2},
        {"id": "1.2", "phase": "Phase 1: Foundation", "task": "Storage Integration", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-06-04", "days": 1},
        {"id": "1.3", "phase": "Phase 1: Foundation", "task": "External Volume Configuration", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-06-05", "days": 1},
        {"id": "1.4", "phase": "Phase 1: Foundation", "task": "Database, Schemas, Warehouses", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-06-06", "days": 1},
        {"id": "1.5", "phase": "Phase 1: Foundation", "task": "RBAC Role Hierarchy and Grants", "owner": "Security Admin", "status": "Complete", "start": "2026-06-07", "days": 1},
        # Phase 2
        {"id": "2.1", "phase": "Phase 2: UC01 Batch Ingestion", "task": "Bronze Iceberg Table DDL", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-09", "days": 1},
        {"id": "2.2", "phase": "Phase 2: UC01 Batch Ingestion", "task": "File Formats (CSV, Fixed, EBCDIC)", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-10", "days": 1},
        {"id": "2.3", "phase": "Phase 2: UC01 Batch Ingestion", "task": "External Stages (S3 Landing Zones)", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-11", "days": 1},
        {"id": "2.4", "phase": "Phase 2: UC01 Batch Ingestion", "task": "COPY INTO Scripts + Test Data", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-12", "days": 2},
        {"id": "2.5", "phase": "Phase 2: UC01 Batch Ingestion", "task": "Dead Letter Table + VALIDATE()", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-14", "days": 1},
        {"id": "2.6", "phase": "Phase 2: UC01 Batch Ingestion", "task": "DMF Quality Checks", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-15", "days": 1},
        # Phase 3
        {"id": "3.1", "phase": "Phase 3: UC02 Streaming", "task": "Kinesis Firehose Configuration", "owner": "Cloud Ops", "status": "Complete", "start": "2026-06-09", "days": 1},
        {"id": "3.2", "phase": "Phase 3: UC02 Streaming", "task": "PIPE Object + Target Table", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-10", "days": 1},
        {"id": "3.3", "phase": "Phase 3: UC02 Streaming", "task": "Firehose Producer Script", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-11", "days": 2},
        {"id": "3.4", "phase": "Phase 3: UC02 Streaming", "task": "Anomaly Injection Script", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-13", "days": 1},
        {"id": "3.5", "phase": "Phase 3: UC02 Streaming", "task": "Exactly-Once Validation", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-14", "days": 1},
        # Phase 4
        {"id": "4.1", "phase": "Phase 4: UC03 Pipeline", "task": "Silver Dynamic Tables (4 DTs)", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-16", "days": 2},
        {"id": "4.2", "phase": "Phase 4: UC03 Pipeline", "task": "Gold Dynamic Tables (4 DTs)", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-18", "days": 2},
        {"id": "4.3", "phase": "Phase 4: UC03 Pipeline", "task": "DMF Quality Gates", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-20", "days": 1},
        {"id": "4.4", "phase": "Phase 4: UC03 Pipeline", "task": "Pipeline Monitoring Queries", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-21", "days": 1},
        # Phase 5
        {"id": "5.1", "phase": "Phase 5: UC04-05 Feature Store", "task": "Online Feature DT (5-min lag)", "owner": "ML Engineer", "status": "Complete", "start": "2026-06-23", "days": 2},
        {"id": "5.2", "phase": "Phase 5: UC04-05 Feature Store", "task": "SLO Measurement Queries", "owner": "ML Engineer", "status": "Complete", "start": "2026-06-25", "days": 1},
        {"id": "5.3", "phase": "Phase 5: UC04-05 Feature Store", "task": "Defect Injection + Rematerialization", "owner": "ML Engineer", "status": "Complete", "start": "2026-06-26", "days": 1},
        {"id": "5.4", "phase": "Phase 5: UC04-05 Feature Store", "task": "Offline Time Travel Queries", "owner": "ML Engineer", "status": "Complete", "start": "2026-06-27", "days": 1},
        {"id": "5.5", "phase": "Phase 5: UC04-05 Feature Store", "task": "Bi-Temporal Snowpark Join", "owner": "ML Engineer", "status": "Complete", "start": "2026-06-28", "days": 2},
        # Phase 6
        {"id": "6.1", "phase": "Phase 6: UC09 Analytics", "task": "Multi-Cluster Warehouse Tuning", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-06-23", "days": 1},
        {"id": "6.2", "phase": "Phase 6: UC09 Analytics", "task": "BI Workload Queries", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-06-24", "days": 1},
        {"id": "6.3", "phase": "Phase 6: UC09 Analytics", "task": "90-Day Time Travel Queries", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-06-25", "days": 1},
        {"id": "6.4", "phase": "Phase 6: UC09 Analytics", "task": "Concurrent Load Test (50 users)", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-06-26", "days": 2},
        # Phase 7
        {"id": "7.1", "phase": "Phase 7: UC10-11 Governance", "task": "Horizon Tags + Classification", "owner": "Security Admin", "status": "Complete", "start": "2026-06-23", "days": 1},
        {"id": "7.2", "phase": "Phase 7: UC10-11 Governance", "task": "Row Access Policies", "owner": "Security Admin", "status": "Complete", "start": "2026-06-24", "days": 1},
        {"id": "7.3", "phase": "Phase 7: UC10-11 Governance", "task": "Dynamic Data Masking", "owner": "Security Admin", "status": "Complete", "start": "2026-06-25", "days": 1},
        {"id": "7.4", "phase": "Phase 7: UC10-11 Governance", "task": "Data Share Packaging", "owner": "Data Engineer", "status": "Complete", "start": "2026-06-26", "days": 1},
        # Phase 8
        {"id": "8.1", "phase": "Phase 8: UC13-14 Cortex AI", "task": "Semantic View Creation", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-06-23", "days": 2},
        {"id": "8.2", "phase": "Phase 8: UC13-14 Cortex AI", "task": "Cortex Analyst NL Testing", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-06-25", "days": 2},
        {"id": "8.3", "phase": "Phase 8: UC13-14 Cortex AI", "task": "Agentic Pipeline Generation", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-06-27", "days": 2},
        {"id": "8.4", "phase": "Phase 8: UC13-14 Cortex AI", "task": "Git Integration Setup", "owner": "Solutions Engineer", "status": "Not Started", "start": "2026-06-29", "days": 1},
        # Phase 9
        {"id": "9.1", "phase": "Phase 9: Integration Testing", "task": "End-to-End Pipeline Test", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-06-30", "days": 2},
        {"id": "9.2", "phase": "Phase 9: Integration Testing", "task": "Performance Benchmarks", "owner": "Solutions Engineer", "status": "Complete", "start": "2026-07-02", "days": 2},
        {"id": "9.3", "phase": "Phase 9: Integration Testing", "task": "Security Review", "owner": "Security Admin", "status": "Complete", "start": "2026-07-02", "days": 1},
        {"id": "9.4", "phase": "Phase 9: Integration Testing", "task": "Demo Preparation", "owner": "Solutions Engineer", "status": "In Progress", "start": "2026-07-04", "days": 2},
    ]


def get_default_test_results():
    """Default POC test results with customer metrics."""
    return [
        {"use_case": "UC01", "test": "Batch Load - 500K transactions", "customer_metric": "ACID-compliant, exactly-once", "result": "500,000 rows loaded", "status": "PASS", "notes": "ON_ERROR=CONTINUE + VALIDATE() working"},
        {"use_case": "UC01", "test": "Partial Acceptance", "customer_metric": "No batch abort on bad records", "result": "Valid rows loaded, rejects captured", "status": "PASS", "notes": "Dead letter table populated via VALIDATE()"},
        {"use_case": "UC01", "test": "DMF Quality Checks", "customer_metric": "Quality gate hooks", "result": "3 DMFs attached, TRIGGER_ON_CHANGES", "status": "PASS", "notes": "Null rate, duplicate rate, row count"},
        {"use_case": "UC02", "test": "Streaming Event Ingest", "customer_metric": "Sub-second event processing", "result": "100K events loaded", "status": "PASS", "notes": "Firehose path: ~2-6 min. Sub-second requires SDK (see 09_future)"},
        {"use_case": "UC02", "test": "Exactly-Once Semantics", "customer_metric": "Handle duplicate bursts", "result": "Silver DT deduplicates on event_id", "status": "PASS", "notes": "QUALIFY ROW_NUMBER() in Silver DT"},
        {"use_case": "UC03", "test": "Medallion Pipeline (Bronze to Gold)", "customer_metric": "ACID writes at zone boundary", "result": "9 Dynamic Tables, all ACTIVE", "status": "PASS", "notes": "Auto-scheduled, no orchestrator"},
        {"use_case": "UC03", "test": "Quality Gates Block Promotion", "customer_metric": "Quality hooks before advance", "result": "DMFs attached with TRIGGER_ON_CHANGES", "status": "PASS", "notes": "Quarantine via threshold monitoring"},
        {"use_case": "UC04", "test": "Online Feature Freshness", "customer_metric": "<=1.5s p99 freshness", "result": "5-min DT lag (DT minimum=60s)", "status": "PARTIAL", "notes": "Sub-second requires Stream+Task (see 09_future)"},
        {"use_case": "UC04", "test": "Feature Store Rebuild from Gold", "customer_metric": "No stream replay", "result": "ALTER DYNAMIC TABLE REFRESH", "status": "PASS", "notes": "One command, full rebuild from Gold history"},
        {"use_case": "UC05", "test": "Time Travel Point-in-Time", "customer_metric": "Bi-temporal reconstruction", "result": "AT(TIMESTAMP) queries working", "status": "PASS", "notes": "Iceberg Time Travel, up to 90 days"},
        {"use_case": "UC09", "test": "Multi-Cluster Auto-Scaling", "customer_metric": "Petabyte-scale concurrent load", "result": "1-3 clusters, Query Acceleration ON", "status": "PASS", "notes": "Auto-scale on queue depth"},
        {"use_case": "UC09", "test": "90-Day Lookback Query", "customer_metric": "90-day Iceberg time travel", "result": "AT(TIMESTAMP => -90 days) functional", "status": "PASS", "notes": "Native Iceberg snapshot queries"},
        {"use_case": "UC10", "test": "RBAC Role Hierarchy", "customer_metric": "SSO + RBAC", "result": "6 roles with inheritance", "status": "PASS", "notes": "Admin > Engineer > Analyst > Viewer"},
        {"use_case": "UC10", "test": "Tag-Based Governance", "customer_metric": "Catalog browsability", "result": "SENSITIVITY + DATA_DOMAIN tags applied", "status": "PASS", "notes": "PII columns tagged and maskable"},
        {"use_case": "UC11", "test": "Zero-Copy Data Share", "customer_metric": "Data product registration", "result": "Share created (ews_fraud_signals_share)", "status": "PASS", "notes": "No ETL, no data movement"},
        {"use_case": "UC13", "test": "Cortex Analyst NL-to-SQL", "customer_metric": "NL query with multi-table joins", "result": "Correct SQL generated from NL", "status": "PASS", "notes": "Semantic View with 4 tables, 8 metrics"},
        {"use_case": "UC13", "test": "Conversational Follow-Up", "customer_metric": "Query refinement in session", "result": "Multi-turn context maintained", "status": "PASS", "notes": "REST API supports conversation history"},
        {"use_case": "UC14", "test": "LLM Pipeline Generation", "customer_metric": "LLM-driven orchestration", "result": "CORTEX.COMPLETE generates valid SQL", "status": "PASS", "notes": "mistral-large2 operational"},
        {"use_case": "UC14", "test": "Git Integration", "customer_metric": "CI/CD deployment gates", "result": "Not yet configured", "status": "NOT TESTED", "notes": "Requires GitHub PAT from EWS"},
    ]


def load_data():
    """Load project data from JSON file."""
    if DATA_FILE.exists():
        with open(DATA_FILE) as f:
            return json.load(f)
    return {"tasks": get_default_tasks(), "test_results": get_default_test_results()}


def save_data(data):
    """Save project data to JSON file."""
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2, default=str)


# =============================================================================
# App Layout
# =============================================================================

st.set_page_config(page_title="EWS POC - Project Dashboard", page_icon="📊", layout="wide")

st.title("📊 EWS POC — Project Status Dashboard")
st.caption("Early Warning Services | Snowflake Proof of Concept")

data = load_data()
tasks_df = pd.DataFrame(data["tasks"])
tests_df = pd.DataFrame(data["test_results"])

# Tabs
tab1, tab2, tab3, tab4 = st.tabs(["📋 Project Status", "📅 Gantt Chart", "✅ Test Results", "⚙️ Manage Tasks"])

# =============================================================================
# Tab 1: Project Status Overview
# =============================================================================

with tab1:
    # KPI Metrics
    total = len(tasks_df)
    complete = len(tasks_df[tasks_df["status"] == "Complete"])
    in_progress = len(tasks_df[tasks_df["status"] == "In Progress"])
    blocked = len(tasks_df[tasks_df["status"] == "Blocked"])
    not_started = len(tasks_df[tasks_df["status"] == "Not Started"])

    col1, col2, col3, col4, col5 = st.columns(5)
    col1.metric("Total Tasks", total)
    col2.metric("Complete", complete, f"{complete/total*100:.0f}%")
    col3.metric("In Progress", in_progress)
    col4.metric("Blocked", blocked)
    col5.metric("Not Started", not_started)

    st.divider()

    # Progress by Phase
    st.subheader("Progress by Phase")
    phase_summary = tasks_df.groupby("phase").agg(
        total=("status", "count"),
        complete=("status", lambda x: (x == "Complete").sum()),
    ).reset_index()
    phase_summary["pct"] = (phase_summary["complete"] / phase_summary["total"] * 100).round(0)

    for _, row in phase_summary.iterrows():
        col_a, col_b = st.columns([3, 1])
        with col_a:
            st.progress(int(row["pct"]) / 100, text=f"{row['phase']}")
        with col_b:
            st.write(f"{int(row['complete'])}/{int(row['total'])} ({int(row['pct'])}%)")

    st.divider()

    # Tasks by Owner
    st.subheader("Workload by Owner")
    owner_summary = tasks_df.groupby(["owner", "status"]).size().reset_index(name="count")
    fig_owner = px.bar(
        owner_summary, x="owner", y="count", color="status",
        color_discrete_map=STATUS_COLORS,
        title="Tasks by Owner and Status",
    )
    fig_owner.update_layout(xaxis_title="", yaxis_title="Tasks", legend_title="Status")
    st.plotly_chart(fig_owner, use_container_width=True)

# =============================================================================
# Tab 2: Gantt Chart
# =============================================================================

with tab2:
    st.subheader("Deployment Gantt Chart")

    gantt_df = tasks_df.copy()
    gantt_df["Start"] = pd.to_datetime(gantt_df["start"])
    gantt_df["End"] = gantt_df["Start"] + pd.to_timedelta(gantt_df["days"], unit="D")
    gantt_df["Task"] = gantt_df["id"] + " " + gantt_df["task"]

    fig_gantt = px.timeline(
        gantt_df,
        x_start="Start",
        x_end="End",
        y="Task",
        color="status",
        color_discrete_map=STATUS_COLORS,
        hover_data=["owner", "phase"],
    )
    fig_gantt.update_yaxes(autorange="reversed")
    fig_gantt.update_layout(height=900, xaxis_title="", legend_title="Status")
    st.plotly_chart(fig_gantt, use_container_width=True)

# =============================================================================
# Tab 3: Test Results
# =============================================================================

with tab3:
    st.subheader("POC Test Results vs Customer Metrics")

    # Summary KPIs
    test_total = len(tests_df)
    test_pass = len(tests_df[tests_df["status"] == "PASS"])
    test_partial = len(tests_df[tests_df["status"] == "PARTIAL"])
    test_fail = len(tests_df[tests_df["status"].isin(["FAIL", "NOT TESTED"])])

    tc1, tc2, tc3, tc4 = st.columns(4)
    tc1.metric("Total Tests", test_total)
    tc2.metric("Pass", test_pass, f"{test_pass/test_total*100:.0f}%")
    tc3.metric("Partial", test_partial)
    tc4.metric("Not Tested / Fail", test_fail)

    st.divider()

    # Filter by use case
    use_cases = ["All"] + sorted(tests_df["use_case"].unique().tolist())
    selected_uc = st.selectbox("Filter by Use Case", use_cases)

    display_df = tests_df if selected_uc == "All" else tests_df[tests_df["use_case"] == selected_uc]

    # Color-coded table
    def highlight_status(row):
        color_map = {"PASS": "background-color: #c8e6c9", "PARTIAL": "background-color: #fff9c4", "FAIL": "background-color: #ffcdd2", "NOT TESTED": "background-color: #e0e0e0"}
        color = color_map.get(row["status"], "")
        return [color] * len(row)

    st.dataframe(
        display_df.style.apply(highlight_status, axis=1),
        use_container_width=True,
        height=600,
        column_config={
            "use_case": st.column_config.TextColumn("UC", width="small"),
            "test": st.column_config.TextColumn("Test", width="medium"),
            "customer_metric": st.column_config.TextColumn("Customer Metric", width="medium"),
            "result": st.column_config.TextColumn("Result", width="medium"),
            "status": st.column_config.TextColumn("Status", width="small"),
            "notes": st.column_config.TextColumn("Notes", width="large"),
        },
    )

# =============================================================================
# Tab 4: Manage Tasks
# =============================================================================

with tab4:
    st.subheader("Update Tasks")
    st.caption("Changes are saved automatically to project_data.json")

    edited_tasks = st.data_editor(
        tasks_df,
        use_container_width=True,
        height=600,
        num_rows="dynamic",
        column_config={
            "id": st.column_config.TextColumn("ID", width="small"),
            "phase": st.column_config.TextColumn("Phase", width="medium"),
            "task": st.column_config.TextColumn("Task", width="large"),
            "owner": st.column_config.SelectboxColumn("Owner", options=TEAM_MEMBERS, width="medium"),
            "status": st.column_config.SelectboxColumn("Status", options=STATUS_OPTIONS, width="small"),
            "start": st.column_config.TextColumn("Start Date", width="small"),
            "days": st.column_config.NumberColumn("Days", width="small", min_value=1, max_value=30),
        },
    )

    if st.button("💾 Save Changes", type="primary"):
        data["tasks"] = edited_tasks.to_dict("records")
        save_data(data)
        st.success("Changes saved!")
        st.rerun()

    st.divider()

    st.subheader("Update Test Results")

    edited_tests = st.data_editor(
        tests_df,
        use_container_width=True,
        height=500,
        num_rows="dynamic",
        column_config={
            "use_case": st.column_config.TextColumn("UC", width="small"),
            "test": st.column_config.TextColumn("Test", width="medium"),
            "customer_metric": st.column_config.TextColumn("Customer Metric", width="medium"),
            "result": st.column_config.TextColumn("Result", width="medium"),
            "status": st.column_config.SelectboxColumn("Status", options=["PASS", "PARTIAL", "FAIL", "NOT TESTED"], width="small"),
            "notes": st.column_config.TextColumn("Notes", width="large"),
        },
    )

    if st.button("💾 Save Test Results", type="primary", key="save_tests"):
        data["test_results"] = edited_tests.to_dict("records")
        save_data(data)
        st.success("Test results saved!")
        st.rerun()
