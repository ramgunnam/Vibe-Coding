#!/bin/bash

# Salesforce Deployment Validation Script
# STAGED validation (dry-run mode) - validates each stage separately
#
# Usage: ./scripts/validate-deployment.sh [sandbox-alias]

set -e

SANDBOX_ALIAS="${1:-${SF_SANDBOX_ALIAS:-dodd-sandbox}}"
SOURCE_DIR="${SF_SOURCE_DIR:-force-app/main/default}"
TEST_LEVEL="${SF_TEST_LEVEL:-RunLocalTests}"
API_VERSION="${SF_API_VERSION:-66.0}"

echo "========================================"
echo "Salesforce Staged Validation (Dry Run)"
echo "========================================"
echo "Target: $SANDBOX_ALIAS"
echo "Source: $SOURCE_DIR"
echo "Test Level: $TEST_LEVEL"
echo ""

# Stage 1: Validate Objects & Platform Events
echo "[Validate Stage 1/3] Objects & Platform Events..."
if [ -d "$SOURCE_DIR/objects" ]; then
    sf project deploy start \
        --source-dir "$SOURCE_DIR/objects" \
        --target-org "$SANDBOX_ALIAS" \
        --dry-run \
        --test-level NoTestRun \
        --api-version "$API_VERSION" \
        --verbose
    echo "[Validate Stage 1/3] PASSED"
else
    echo "[Validate Stage 1/3] SKIPPED - no objects directory"
fi

echo ""

# Stage 2: Validate Apex Classes
echo "[Validate Stage 2/3] Apex Classes..."
if [ -d "$SOURCE_DIR/classes" ]; then
    sf project deploy start \
        --source-dir "$SOURCE_DIR/classes" \
        --target-org "$SANDBOX_ALIAS" \
        --dry-run \
        --test-level "$TEST_LEVEL" \
        --api-version "$API_VERSION" \
        --verbose
    echo "[Validate Stage 2/3] PASSED"
else
    echo "[Validate Stage 2/3] SKIPPED - no classes directory"
fi

echo ""

# Stage 3: Validate LWC Components
echo "[Validate Stage 3/3] LWC Components..."
if [ -d "$SOURCE_DIR/lwc" ]; then
    sf project deploy start \
        --source-dir "$SOURCE_DIR/lwc" \
        --target-org "$SANDBOX_ALIAS" \
        --dry-run \
        --test-level NoTestRun \
        --api-version "$API_VERSION" \
        --verbose
    echo "[Validate Stage 3/3] PASSED"
else
    echo "[Validate Stage 3/3] SKIPPED - no lwc directory"
fi

echo ""
echo "========================================"
echo "All validations passed!"
echo "Run ./scripts/deploy-to-sandbox.sh to deploy"
echo "========================================"
