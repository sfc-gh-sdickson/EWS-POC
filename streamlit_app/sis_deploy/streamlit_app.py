"""
EWS POC - Project Status Dashboard (Streamlit in Snowflake)
Deployed via: snow streamlit deploy
Data stored in: EWS_POC.ANALYTICS.PROJECT_TASKS / TEST_RESULTS
"""

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

session = get_active_session()

TEAM_MEMBERS = ["Unassigned", "Stephen Dickson", "Solutions Engineer", "Data Engineer",
                "ML Engineer", "Security Admin", "Cloud Ops", "EWS Contact"]
STATUS_OPTIONS = ["Not Started", "In Progress", "Blocked", "Complete"]

@st.cache_data(ttl=30)
def load_tasks():
    return session.sql("SELECT * FROM EWS_POC.ANALYTICS.PROJECT_TASKS ORDER BY id").to_pandas()

@st.cache_data(ttl=30)
def load_tests():
    return session.sql("SELECT * FROM EWS_POC.ANALYTICS.TEST_RESULTS ORDER BY use_case, test").to_pandas()

st.set_page_config(page_title="EWS POC Dashboard", page_icon="\U0001f4ca", layout="wide")
st.title("\U0001f4ca EWS POC \u2014 Project Status Dashboard")
st.caption("Early Warning Services | Snowflake Proof of Concept | Data: EWS_POC.ANALYTICS")

tab1, tab2, tab3, tab4, tab5, tab6 = st.tabs(["\U0001f4cb Status", "\U0001f4c5 Gantt", "\u2705 Tests", "\u2699\ufe0f Manage", "\U0001f517 Lineage", "\U0001f4b0 Cost"])

tasks_df = load_tasks()
tests_df = load_tests()

with tab1:
    total = len(tasks_df)
    complete = len(tasks_df[tasks_df["STATUS"] == "Complete"])
    in_progress = len(tasks_df[tasks_df["STATUS"] == "In Progress"])
    blocked = len(tasks_df[tasks_df["STATUS"] == "Blocked"])
    not_started = len(tasks_df[tasks_df["STATUS"] == "Not Started"])
    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("Total Tasks", total)
    c2.metric("Complete", complete, f"{complete/total*100:.0f}%" if total > 0 else "0%")
    c3.metric("In Progress", in_progress)
    c4.metric("Blocked", blocked)
    c5.metric("Not Started", not_started)
    st.divider()
    st.subheader("Progress by Phase")
    phase_groups = tasks_df.groupby("PHASE").agg(
        total_tasks=("STATUS", "count"),
        done=("STATUS", lambda x: (x == "Complete").sum())
    ).reset_index()
    phase_groups["pct"] = (phase_groups["done"] / phase_groups["total_tasks"] * 100).astype(int)
    for _, row in phase_groups.iterrows():
        col_a, col_b = st.columns([4, 1])
        with col_a:
            st.progress(row["pct"] / 100, text=row["PHASE"])
        with col_b:
            st.write(f"{row['done']}/{row['total_tasks']} ({row['pct']}%)")
    st.divider()
    st.subheader("Tasks by Owner")
    owner_counts = tasks_df.groupby(["OWNER", "STATUS"]).size().reset_index(name="count")
    st.bar_chart(owner_counts.pivot(index="OWNER", columns="STATUS", values="count").fillna(0))

with tab2:
    st.subheader("Deployment Timeline")
    gantt_df = tasks_df.copy()
    gantt_df["Start"] = pd.to_datetime(gantt_df["START_DATE"])
    gantt_df["End"] = gantt_df["Start"] + pd.to_timedelta(gantt_df["DAYS"].astype(int), unit="D")
    for phase in gantt_df["PHASE"].unique():
        st.markdown(f"**{phase}**")
        phase_tasks = gantt_df[gantt_df["PHASE"] == phase]
        for _, row in phase_tasks.iterrows():
            status_icon = {"Complete": "\u2705", "In Progress": "\U0001f504", "Blocked": "\U0001f6ab", "Not Started": "\u2b1c"}.get(row["STATUS"], "\u2b1c")
            st.write(f"{status_icon} **{row['ID']}** {row['TASK']} | {row['START_DATE']} | {row['DAYS']}d | _{row['OWNER']}_")

with tab3:
    st.subheader("Use Case Test Results")
    if len(tests_df) > 0:
        test_summary = tests_df.groupby("STATUS").size().reset_index(name="count")
        cols = st.columns(len(test_summary))
        for i, row in test_summary.iterrows():
            cols[i].metric(row["STATUS"], row["count"])
        st.divider()
        for uc in tests_df["USE_CASE"].unique():
            uc_tests = tests_df[tests_df["USE_CASE"] == uc]
            st.markdown(f"### {uc}")
            st.dataframe(uc_tests[["TEST", "CUSTOMER_METRIC", "RESULT", "STATUS", "NOTES"]], use_container_width=True)
    else:
        st.info("No test results recorded yet.")

with tab4:
    st.subheader("Update Task Status")
    if len(tasks_df) > 0:
        task_options = tasks_df["ID"] + " - " + tasks_df["TASK"]
        selected = st.selectbox("Select Task", task_options)
        selected_id = selected.split(" - ")[0]
        col1, col2 = st.columns(2)
        with col1:
            new_status = st.selectbox("New Status", STATUS_OPTIONS)
        with col2:
            new_owner = st.selectbox("New Owner", TEAM_MEMBERS)
        if st.button("Update Task", type="primary"):
            session.sql(f"""UPDATE EWS_POC.ANALYTICS.PROJECT_TASKS SET STATUS = '{new_status}', OWNER = '{new_owner}', UPDATED_AT = CURRENT_TIMESTAMP() WHERE ID = '{selected_id}'""").collect()
            st.success(f"Task {selected_id} updated!")
            st.cache_data.clear()
            st.rerun()
    st.divider()
    st.subheader("Full Task List")
    st.dataframe(tasks_df, use_container_width=True)

with tab5:
    st.subheader("Data Pipeline Lineage")
    st.caption("Bronze (Iceberg) -> Silver (Dynamic Tables) -> Gold (Dynamic Tables) -> Feature Store")
    lineage_data = {
        "BRONZE.RAW_TRANSACTIONS": ["SILVER.CLEANSED_TRANSACTIONS"],
        "BRONZE.RAW_MEMBERS": ["SILVER.ENRICHED_MEMBERS"],
        "BRONZE.RAW_ALERTS": ["SILVER.ENRICHED_ALERTS"],
        "BRONZE.STREAMING_EVENTS": ["SILVER.DEDUP_EVENTS"],
        "SILVER.CLEANSED_TRANSACTIONS": ["GOLD.DAILY_MEMBER_SUMMARY", "GOLD.MEMBER_ACTIVITY"],
        "SILVER.ENRICHED_MEMBERS": ["SILVER.ENRICHED_ALERTS", "GOLD.MEMBER_ACTIVITY"],
        "SILVER.ENRICHED_ALERTS": ["GOLD.FRAUD_SIGNALS"],
        "SILVER.DEDUP_EVENTS": ["GOLD.FRAUD_SIGNALS", "FEATURE_STORE.ONLINE_MEMBER_FEATURES"],
        "BRONZE.RAW_INSTITUTIONS": ["GOLD.INSTITUTION_SUMMARY"],
    }
    st.markdown("### Pipeline Flow")
    for source, targets in lineage_data.items():
        for target in targets:
            st.write(f"  {source} **-->** {target}")
    st.divider()
    st.markdown("### Object Dependencies (from ACCOUNT_USAGE)")
    st.caption("Note: ACCOUNT_USAGE views have up to 3-hour latency for new objects.")
    try:
        deps_df = session.sql("""
            SELECT REFERENCING_OBJECT_NAME AS downstream,
                   REFERENCED_OBJECT_NAME AS upstream,
                   REFERENCING_OBJECT_DOMAIN AS type
            FROM SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES
            WHERE REFERENCING_DATABASE = 'EWS_POC'
              AND REFERENCED_DATABASE = 'EWS_POC'
            ORDER BY upstream, downstream
            LIMIT 50
        """).to_pandas()
        if len(deps_df) > 0:
            st.dataframe(deps_df, use_container_width=True)
        else:
            st.info("No dependency data available yet (may take up to 3 hours to populate).")
    except Exception as e:
        st.warning(f"Could not load dependencies: {e}")

with tab6:
    st.subheader("Warehouse Credit Consumption")
    st.caption("Source: SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY (up to 3-hour latency)")
    try:
        cost_df = session.sql("""
            SELECT WAREHOUSE_NAME,
                   START_TIME::DATE AS usage_date,
                   SUM(CREDITS_USED) AS credits_used
            FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
            WHERE WAREHOUSE_NAME LIKE 'EWS_%'
              AND START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
            GROUP BY WAREHOUSE_NAME, usage_date
            ORDER BY usage_date, WAREHOUSE_NAME
        """).to_pandas()
        if len(cost_df) > 0:
            total_by_wh = cost_df.groupby("WAREHOUSE_NAME")["CREDITS_USED"].sum().reset_index()
            cols = st.columns(len(total_by_wh))
            for i, row in total_by_wh.iterrows():
                cols[i].metric(row["WAREHOUSE_NAME"], f"{row['CREDITS_USED']:.2f} credits")
            st.divider()
            st.subheader("Daily Credit Usage by Warehouse")
            pivot_df = cost_df.pivot(index="USAGE_DATE", columns="WAREHOUSE_NAME", values="CREDITS_USED").fillna(0)
            st.bar_chart(pivot_df)
            st.divider()
            st.dataframe(cost_df, use_container_width=True)
        else:
            st.info("No warehouse metering data available yet for EWS warehouses.")
    except Exception as e:
        st.warning(f"Could not load cost data: {e}")
