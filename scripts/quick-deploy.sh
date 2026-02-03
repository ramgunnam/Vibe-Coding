#!/bin/bash

# Salesforce Quick Deploy Script (Non-Interactive)
# Deploys to sandbox without prompts - useful for CI/CD pipelines
#
# Usage: ./scripts/quick-deploy.sh [sandbox-alias]
#
# WARNING: This script deploys without confirmation prompts.
# Ensure you have validated your deployment first!

set -e

SANDBOX_ALIAS="${1:-${SF_SANDBOX_ALIAS:-dodd-sandbox}}"
SOURCE_DIR="${SF_SOURCE_DIR:-force-app/main/default}"
TEST_LEVEL="${SF_TEST_LEVEL:-RunLocalTests}"
API_VERSION="${SF_API_VERSION:-66.0}"

echo "========================================"
echo "Salesforce Quick Deploy"
echo "========================================"
echo "Target Org: $SANDBOX_ALIAS"
echo "Source: $SOURCE_DIR"
echo "Test Level: $TEST_LEVEL"
echo "API Version: $API_VERSION"
echo "Started at: $(date)"
echo ""

# Verify authentication
if ! sf org list --json 2>/dev/null | grep -q "\"alias\": \"$SANDBOX_ALIAS\""; then
    echo "ERROR: Not authenticated to '$SANDBOX_ALIAS'"
    echo "Please run: sf org login web --alias $SANDBOX_ALIAS --instance-url https://test.salesforce.com"
    exit 1
fi

# Deploy
sf project deploy start \
    --source-dir "$SOURCE_DIR" \
    --target-org "$SANDBOX_ALIAS" \
    --test-level "$TEST_LEVEL" \
    --api-version "$API_VERSION" \
    --verbose \
    --wait 60

echo ""
echo "========================================"
echo "Deployment completed successfully!"
echo "Completed at: $(date)"
echo "========================================"

# Show deployment report
sf project deploy report --target-org "$SANDBOX_ALIAS" 2>/dev/null || true
