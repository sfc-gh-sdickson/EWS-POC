# EWS POC — Terraform Deployment

## Overview

This directory contains Terraform configuration to deploy the entire EWS POC infrastructure to Snowflake. All resources match what was manually deployed via SQL in the POC.

## Files

| File | Purpose |
|------|---------|
| `main.tf` | Provider configuration and Terraform settings |
| `variables.tf` | Input variables (account, credentials, S3 config) |
| `terraform.tfvars.example` | Example variable values (copy to `terraform.tfvars`) |
| `database.tf` | Database and schemas |
| `warehouses.tf` | Workload-specific warehouses |
| `storage.tf` | Storage integration and external volume |
| `roles.tf` | RBAC role hierarchy and grants |
| `iceberg_tables.tf` | Bronze zone Iceberg tables |
| `dynamic_tables.tf` | Silver, Gold, and Feature Store Dynamic Tables |
| `governance.tf` | Tags, masking policies, data share |
| `semantic_view.tf` | Cortex Analyst semantic view |
| `outputs.tf` | Output values (integration ARNs, etc.) |

## Usage

```bash
# 1. Initialize Terraform
cd terraform
terraform init

# 2. Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Plan (review changes)
terraform plan

# 4. Apply (deploy)
terraform apply

# 5. Destroy (cleanup)
terraform destroy
```

## Prerequisites

- Terraform >= 1.5
- Snowflake Terraform Provider (`snowflake-labs/snowflake` >= 1.0)
- Snowflake account with ACCOUNTADMIN access
- AWS S3 bucket with IAM role configured for Snowflake trust
