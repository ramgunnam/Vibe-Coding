#!/bin/bash

# Salesforce Sandbox Authentication Script
# Authenticates to a Salesforce sandbox using web login
#
# Usage: ./scripts/authenticate-sandbox.sh [sandbox-alias] [instance-url]

set -e

SANDBOX_ALIAS="${1:-${SF_SANDBOX_ALIAS:-dodd-sandbox}}"
INSTANCE_URL="${2:-${SF_INSTANCE_URL:-https://test.salesforce.com}}"

echo "========================================"
echo "Salesforce Sandbox Authentication"
echo "========================================"
echo "Alias: $SANDBOX_ALIAS"
echo "Instance URL: $INSTANCE_URL"
echo ""

# Check if already authenticated
if sf org list --json 2>/dev/null | grep -q "\"alias\": \"$SANDBOX_ALIAS\""; then
    echo "Already authenticated to '$SANDBOX_ALIAS'"
    echo ""
    echo "Current org details:"
    sf org display --target-org "$SANDBOX_ALIAS" 2>/dev/null | grep -E "^(Username|Instance Url|Org Id|Status)" || true
    echo ""
    read -p "Re-authenticate? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Using existing authentication."
        exit 0
    fi
fi

echo "Opening browser for authentication..."
sf org login web --alias "$SANDBOX_ALIAS" --instance-url "$INSTANCE_URL"

echo ""
echo "========================================"
echo "Authentication successful!"
echo "========================================"
echo ""
echo "Org details:"
sf org display --target-org "$SANDBOX_ALIAS" 2>/dev/null | grep -E "^(Username|Instance Url|Org Id)" || true
