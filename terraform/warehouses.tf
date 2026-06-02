# =============================================================================
# EWS POC Warehouses (Workload Isolation)
# =============================================================================

resource "snowflake_warehouse" "ingest" {
  name              = "EWS_INGEST_WH"
  warehouse_size    = var.warehouse_size
  auto_suspend      = 60
  auto_resume       = true
  initially_suspended = true
  comment           = "Batch ingestion workloads (COPY INTO)"
}

resource "snowflake_warehouse" "transform" {
  name              = "EWS_TRANSFORM_WH"
  warehouse_size    = var.warehouse_size
  auto_suspend      = 60
  auto_resume       = true
  initially_suspended = true
  comment           = "Pipeline transformation (Dynamic Tables)"
}

resource "snowflake_warehouse" "analytics" {
  name                            = "EWS_ANALYTICS_WH"
  warehouse_size                  = var.warehouse_size
  min_cluster_count               = 1
  max_cluster_count               = var.analytics_max_clusters
  scaling_policy                  = "STANDARD"
  auto_suspend                    = 60
  auto_resume                     = true
  initially_suspended             = true
  enable_query_acceleration       = true
  query_acceleration_max_scale_factor = 4
  comment                         = "Analytics - multi-cluster auto-scaling with Query Acceleration"
}

resource "snowflake_warehouse" "ai" {
  name              = "EWS_AI_WH"
  warehouse_size    = var.warehouse_size
  auto_suspend      = 120
  auto_resume       = true
  initially_suspended = true
  comment           = "AI/ML workloads - Cortex functions, Analyst, Agents"
}
