#!/bin/bash

# Salesforce Quick Deploy Script (Non-Interactive)
# STAGED deployment for CI/CD pipelines - handles dependencies correctly
#
# Usage: ./scripts/quick-deploy.sh [sandbox-alias]
#
# Deployment Order:
#   1. Objects & Platform Events
#   2. Apex Classes
#   3. LWC Components

set -e

SANDBOX_ALIAS="${1:-${SF_SANDBOX_ALIAS:-dodd-sandbox}}"
SOURCE_DIR="${SF_SOURCE_DIR:-force-app/main/default}"
TEST_LEVEL="${SF_TEST_LEVEL:-RunLocalTests}"
API_VERSION="${SF_API_VERSION:-66.0}"

echo "========================================"
echo "Salesforce Staged Quick Deploy"
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

echo "Using STAGED deployment for dependency resolution..."
echo ""

# Stage 1: Objects & Platform Events (MUST deploy first)
echo "[Stage 1/3] Deploying Objects & Platform Events..."
if [ -d "$SOURCE_DIR/objects" ]; then
    sf project deploy start \
        --source-dir "$SOURCE_DIR/objects" \
        --target-org "$SANDBOX_ALIAS" \
        --api-version "$API_VERSION" \
        --test-level NoTestRun \
        --wait 30 \
        --verbose
    echo "[Stage 1/3] COMPLETE"
else
    echo "[Stage 1/3] SKIPPED - no objects directory"
fi

echo ""

# Stage 2: Apex Classes (depend on objects/events)
echo "[Stage 2/3] Deploying Apex Classes..."
if [ -d "$SOURCE_DIR/classes" ]; then
    sf project deploy start \
        --source-dir "$SOURCE_DIR/classes" \
        --target-org "$SANDBOX_ALIAS" \
        --api-version "$API_VERSION" \
        --test-level "$TEST_LEVEL" \
        --wait 30 \
        --verbose
    echo "[Stage 2/3] COMPLETE"
else
    echo "[Stage 2/3] SKIPPED - no classes directory"
fi

echo ""

# Stage 3: LWC Components (depend on Apex controllers)
echo "[Stage 3/3] Deploying LWC Components..."
if [ -d "$SOURCE_DIR/lwc" ]; then
    sf project deploy start \
        --source-dir "$SOURCE_DIR/lwc" \
        --target-org "$SANDBOX_ALIAS" \
        --api-version "$API_VERSION" \
        --test-level NoTestRun \
        --wait 30 \
        --verbose
    echo "[Stage 3/3] COMPLETE"
else
    echo "[Stage 3/3] SKIPPED - no lwc directory"
fi

echo ""
echo "========================================"
echo "All stages completed successfully!"
echo "Completed at: $(date)"
echo "========================================"

# Show deployment report
sf project deploy report --target-org "$SANDBOX_ALIAS" 2>/dev/null || true
