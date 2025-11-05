#!/bin/bash

# Environment setup for Nebius AI Cloud Terraform
# This script sets up user account authentication (not service account)
# Make sure Nebius CLI is installed and configured: https://docs.nebius.ai/cli/install/

# Set the following environment variables before sourcing this script:
# NEBIUS_TENANT_ID='tenant-...'
# NEBIUS_PROJECT_ID='project-...'
# NEBIUS_REGION='eu-north1'

if [ -z "${NEBIUS_TENANT_ID}" ]; then
  echo "Error: NEBIUS_TENANT_ID is not set"
  echo "Please set it before sourcing this script:"
  echo "  export NEBIUS_TENANT_ID='tenant-...'"
  return 1 2>/dev/null || exit 1
fi

if [ -z "${NEBIUS_PROJECT_ID}" ]; then
  echo "Error: NEBIUS_PROJECT_ID is not set"
  echo "Please set it before sourcing this script:"
  echo "  export NEBIUS_PROJECT_ID='project-...'"
  return 1 2>/dev/null || exit 1
fi

if [ -z "${NEBIUS_REGION}" ]; then
  echo "Error: NEBIUS_REGION is not set"
  echo "Please set it before sourcing this script:"
  echo "  export NEBIUS_REGION='eu-north1'  # or eu-west1, eu-north2, us-central1, me-west1"
  return 1 2>/dev/null || exit 1
fi

# Get IAM token for user account authentication
# Token lifetime is 12 hours
echo "Getting IAM access token..."
unset NEBIUS_IAM_TOKEN
export NEBIUS_IAM_TOKEN=$(nebius iam get-access-token)

if [ -z "${NEBIUS_IAM_TOKEN}" ]; then
  echo "Error: Failed to get IAM access token"
  echo "Make sure Nebius CLI is installed and configured:"
  echo "  curl -sSL https://storage.eu-north1.nebius.cloud/cli/install.sh | bash"
  echo "  nebius config profile activate"
  return 1 2>/dev/null || exit 1
fi

echo "✓ IAM token obtained (valid for 12 hours)"

# Get or set subnet ID (leave empty to use Terraform-created subnet)
if [ -z "${NEBIUS_VPC_SUBNET_ID}" ]; then
  echo "No subnet ID provided - Terraform will create a dedicated subnet for the demo"
  echo "  (This avoids /16 allocation issues)"
  # Set to empty string to use created subnet
  export TF_VAR_subnet_id=""
else
  echo "✓ Using provided subnet: ${NEBIUS_VPC_SUBNET_ID}"
  export TF_VAR_subnet_id="${NEBIUS_VPC_SUBNET_ID}"
fi

# Export Terraform variables
export TF_VAR_iam_token="${NEBIUS_IAM_TOKEN}"
export TF_VAR_parent_id="${NEBIUS_PROJECT_ID}"
export TF_VAR_region="${NEBIUS_REGION}"
export TF_VAR_tenant_id="${NEBIUS_TENANT_ID}"

# Also export NEBIUS_IAM_TOKEN for provider (recommended method)
# The provider will use this environment variable if token is not set in provider config

# Summary
echo ""
echo "========================================="
echo "Environment variables set:"
echo "========================================="
echo "NEBIUS_TENANT_ID: ${NEBIUS_TENANT_ID}"
echo "NEBIUS_PROJECT_ID: ${NEBIUS_PROJECT_ID}"
echo "NEBIUS_REGION: ${NEBIUS_REGION}"
if [ -n "${NEBIUS_VPC_SUBNET_ID}" ]; then
  echo "NEBIUS_VPC_SUBNET_ID: ${NEBIUS_VPC_SUBNET_ID}"
else
  echo "NEBIUS_VPC_SUBNET_ID: <will be created by Terraform>"
fi
echo "NEBIUS_IAM_TOKEN: <set>"
echo ""
echo "Terraform variables (TF_VAR_*):"
echo "TF_VAR_tenant_id: ${TF_VAR_tenant_id}"
echo "TF_VAR_parent_id: ${TF_VAR_parent_id}"
echo "TF_VAR_region: ${TF_VAR_region}"
echo "TF_VAR_subnet_id: ${TF_VAR_subnet_id:-<will create dedicated subnet>}"
echo "TF_VAR_iam_token: <set>"
echo ""
echo "✓ Environment ready! You can now run:"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
echo "========================================="

