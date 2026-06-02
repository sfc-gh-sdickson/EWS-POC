"""
EWS POC - Project Status Dashboard (Streamlit in Snowflake)
Deployed via: snow streamlit deploy
Data stored in: EWS_POC.ANALYTICS.PROJECT_TASKS / TEST_RESULTS
"""

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

# =============================================================================
# Snowflake Connection
# =============================================================================

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


# =============================================================================
# App Layout
# =============================================================================

st.set_page_config(page_title="EWS POC Dashboard", page_icon="📊", layout="wide")
st.title("📊 EWS POC — Project Status Dashboard")
st.caption("Early Warning Services | Snowflake Proof of Concept | Data: EWS_POC.ANALYTICS")

tab1, tab2, tab3, tab4 = st.tabs(["📋 Status", "📅 Gantt", "✅ Tests", "⚙️ Manage"])

tasks_df = load_tasks()
tests_df = load_tests()

# =============================================================================
# Tab 1: Status Overview
# =============================================================================

with tab1:
    total = len(tasks_df)
    complete = len(tasks_df[tasks_df["STATUS"] == "Complete"])
    in_progress = len(tasks_df[tasks_df["STATUS"] == "In Progress"])
    blocked = len(tasks_df[tasks_df["STATUS"] == "Blocked"])
    not_started = len(tasks_df[tasks_df["STATUS"] == "Not Started"])

    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("Total Tasks", total)
    c2.metric("Complete", complete, f"{complete/total*100:.0f}%")
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

# =============================================================================
# Tab 2: Gantt Chart
# =============================================================================

with tab2:
    st.subheader("Deployment Timeline")

    gantt_df = tasks_df.copy()
    gantt_df["Start"] = pd.to_datetime(gantt_df["START_DATE"])
    gantt_df["End"] = gantt_df["Start"] + pd.to_timedelta(gantt_df["DAYS"].astype(int), unit="D")
    gantt_df["Label"] = gantt_df["ID"] + " " + gantt_df["TASK"]

    # Simple Gantt using native Streamlit (no plotly needed in SiS)
    for phase in gantt_df["PHASE"].unique():
        st.markdown(f"**{phase}**")
        phase_tasks = gantt_df[gantt_df["PHASE"] == phase]
        for _, row in phase_tasks.iterrows():
            status_icon = {"Complete": "✅", "In Progress": "🔄", "Blocked": "🚫", "Not Started": "⬜"}.get(row["STATUS"], "⬜")
            st.write(f"{status_icon} `{row['ID']}` **{row['TASK']}** — {row['OWNER']} ({row['START_DATE']}, {int(row['DAYS'])}d)")

# =============================================================================
# Tab 3: Test Results
# =============================================================================

with tab3:
    st.subheader("POC Test Results vs Customer Metrics")

    test_total = len(tests_df)
    test_pass = len(tests_df[tests_df["STATUS"] == "PASS"])
    test_partial = len(tests_df[tests_df["STATUS"] == "PARTIAL"])

    tc1, tc2, tc3 = st.columns(3)
    tc1.metric("Total Tests", test_total)
    tc2.metric("Pass", test_pass, f"{test_pass/test_total*100:.0f}%")
    tc3.metric("Partial / Not Tested", test_total - test_pass)

    st.divider()

    uc_filter = st.selectbox("Filter by Use Case", ["All"] + sorted(tests_df["USE_CASE"].unique().tolist()))
    display = tests_df if uc_filter == "All" else tests_df[tests_df["USE_CASE"] == uc_filter]

    for _, row in display.iterrows():
        icon = {"PASS": "✅", "PARTIAL": "⚠️", "FAIL": "❌", "NOT TESTED": "⬜"}.get(row["STATUS"], "⬜")
        with st.expander(f"{icon} [{row['USE_CASE']}] {row['TEST']} — {row['STATUS']}"):
            st.markdown(f"**Customer Metric:** {row['CUSTOMER_METRIC']}")
            st.markdown(f"**Result:** {row['RESULT']}")
            st.markdown(f"**Notes:** {row['NOTES']}")

# =============================================================================
# Tab 4: Manage (Update Tasks)
# =============================================================================

with tab4:
    st.subheader("Update Task Status and Owner")

    task_id = st.selectbox("Select Task", tasks_df["ID"] + " - " + tasks_df["TASK"])
    selected_id = task_id.split(" - ")[0]
    current = tasks_df[tasks_df["ID"] == selected_id].iloc[0]

    col_s, col_o = st.columns(2)
    with col_s:
        new_status = st.selectbox("Status", STATUS_OPTIONS, index=STATUS_OPTIONS.index(current["STATUS"]))
    with col_o:
        current_owner_idx = TEAM_MEMBERS.index(current["OWNER"]) if current["OWNER"] in TEAM_MEMBERS else 0
        new_owner = st.selectbox("Owner", TEAM_MEMBERS, index=current_owner_idx)

    if st.button("💾 Save Changes", type="primary"):
        session.sql(f"""
            UPDATE EWS_POC.ANALYTICS.PROJECT_TASKS
            SET status = '{new_status}', owner = '{new_owner}', updated_at = CURRENT_TIMESTAMP()
            WHERE id = '{selected_id}'
        """).collect()
        st.success(f"Task {selected_id} updated: {new_status} / {new_owner}")
        st.cache_data.clear()
        st.rerun()

    st.divider()
    st.subheader("Update Test Result")

    test_select = st.selectbox("Select Test", tests_df["USE_CASE"] + " - " + tests_df["TEST"])
    selected_test = test_select.split(" - ", 1)[1]
    current_test = tests_df[tests_df["TEST"] == selected_test].iloc[0]

    new_test_status = st.selectbox("Test Status", ["PASS", "PARTIAL", "FAIL", "NOT TESTED"],
                                   index=["PASS", "PARTIAL", "FAIL", "NOT TESTED"].index(current_test["STATUS"]),
                                   key="test_status")
    new_result = st.text_input("Result", value=current_test["RESULT"])
    new_notes = st.text_input("Notes", value=current_test["NOTES"])

    if st.button("💾 Save Test Update", type="primary", key="save_test"):
        session.sql(f"""
            UPDATE EWS_POC.ANALYTICS.TEST_RESULTS
            SET status = '{new_test_status}', result = '{new_result}', notes = '{new_notes}', updated_at = CURRENT_TIMESTAMP()
            WHERE test = '{selected_test}'
        """).collect()
        st.success(f"Test '{selected_test}' updated")
        st.cache_data.clear()
        st.rerun()
