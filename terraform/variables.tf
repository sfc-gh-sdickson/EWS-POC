# =============================================================================
# Snowflake Connection
# =============================================================================

variable "snowflake_organization" {
  description = "Snowflake organization name"
  type        = string
}

variable "snowflake_account" {
  description = "Snowflake account name"
  type        = string
}

variable "snowflake_user" {
  description = "Snowflake username with ACCOUNTADMIN role"
  type        = string
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
}

# =============================================================================
# AWS / S3 Configuration
# =============================================================================

variable "aws_account_id" {
  description = "AWS Account ID that owns the S3 bucket"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for Iceberg data storage (without s3:// prefix)"
  type        = string
}

variable "aws_iam_role_arn" {
  description = "Full IAM Role ARN that Snowflake assumes for S3 access"
  type        = string
}

variable "s3_iceberg_path" {
  description = "Path within the S3 bucket for Iceberg data"
  type        = string
  default     = "ews_poc/iceberg/"
}

# =============================================================================
# Deployment Configuration
# =============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "poc"
}

variable "warehouse_size" {
  description = "Default warehouse size for POC"
  type        = string
  default     = "MEDIUM"
}

variable "analytics_max_clusters" {
  description = "Max cluster count for analytics warehouse"
  type        = number
  default     = 3
}
