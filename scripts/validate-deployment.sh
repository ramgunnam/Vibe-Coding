#!/bin/bash

# Salesforce Deployment Validation Script
# Validates deployment without making actual changes (dry-run mode)
#
# Usage: ./scripts/validate-deployment.sh [sandbox-alias]

set -e

SANDBOX_ALIAS="${1:-${SF_SANDBOX_ALIAS:-dodd-sandbox}}"
SOURCE_DIR="${SF_SOURCE_DIR:-force-app/main/default}"
TEST_LEVEL="${SF_TEST_LEVEL:-RunLocalTests}"
API_VERSION="${SF_API_VERSION:-66.0}"

echo "Validating deployment to: $SANDBOX_ALIAS"
echo "Source: $SOURCE_DIR"
echo "Test Level: $TEST_LEVEL"
echo ""

sf project deploy start \
    --source-dir "$SOURCE_DIR" \
    --target-org "$SANDBOX_ALIAS" \
    --dry-run \
    --test-level "$TEST_LEVEL" \
    --api-version "$API_VERSION" \
    --verbose

echo ""
echo "Validation completed successfully!"
