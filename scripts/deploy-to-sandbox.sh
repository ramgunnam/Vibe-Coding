#!/bin/bash

# Salesforce Deployment Script for DODD Sandbox
# This script handles STAGED deployment to ensure correct dependency order
#
# Deployment Order:
#   1. Custom Objects & Platform Events (metadata dependencies)
#   2. Apex Classes (depend on objects/events)
#   3. LWC Components (depend on Apex controllers)
#
# Prerequisites:
#   - Salesforce CLI (sf) installed
#   - Access to the target Salesforce sandbox

set -e  # Exit on error

# =============================================================================
# Configuration
# =============================================================================
SANDBOX_ALIAS="${SF_SANDBOX_ALIAS:-dodd-sandbox}"
SOURCE_DIR="${SF_SOURCE_DIR:-force-app/main/default}"
TEST_LEVEL="${SF_TEST_LEVEL:-RunLocalTests}"
API_VERSION="${SF_API_VERSION:-66.0}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

show_help() {
    cat << EOF
Salesforce Staged Deployment Script for DODD Sandbox

This script deploys in stages to handle dependencies correctly:
  Stage 1: Objects & Platform Events
  Stage 2: Apex Classes
  Stage 3: LWC Components

Usage: $(basename "$0") [options]

Options:
    -a, --alias ALIAS     Sandbox alias (default: $SANDBOX_ALIAS)
    -v, --validate        Validate only (dry-run)
    -s, --skip-tests      Skip test execution
    --single              Deploy all at once (not staged)
    -h, --help            Show this help message

Examples:
    ./scripts/deploy-to-sandbox.sh
    ./scripts/deploy-to-sandbox.sh --alias my-sandbox
    ./scripts/deploy-to-sandbox.sh --validate
EOF
    exit 0
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    if ! command -v sf &> /dev/null; then
        print_error "Salesforce CLI (sf) is not installed."
        echo "Install from: https://developer.salesforce.com/tools/salesforcecli"
        exit 1
    fi
    print_success "Salesforce CLI found"

    if [ ! -f "sfdx-project.json" ]; then
        print_error "sfdx-project.json not found!"
        exit 1
    fi
    print_success "Project structure valid"
}

check_authentication() {
    print_header "Checking Authentication"

    if sf org list --json 2>/dev/null | grep -q "\"alias\": \"$SANDBOX_ALIAS\""; then
        print_success "Authenticated to '$SANDBOX_ALIAS'"
    else
        print_warning "Not authenticated to '$SANDBOX_ALIAS'"
        read -p "Authenticate now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sf org login web --alias "$SANDBOX_ALIAS" --instance-url https://test.salesforce.com
        else
            exit 1
        fi
    fi
}

# =============================================================================
# Staged Deployment Functions
# =============================================================================

deploy_stage_1_objects() {
    print_header "Stage 1: Deploying Objects & Platform Events"

    if [ ! -d "$SOURCE_DIR/objects" ]; then
        print_warning "No objects directory found, skipping Stage 1"
        return 0
    fi

    print_info "Deploying custom objects and platform events..."

    local cmd="sf project deploy start \
        --source-dir $SOURCE_DIR/objects \
        --target-org $SANDBOX_ALIAS \
        --api-version $API_VERSION \
        --wait 30"

    if [ "$VALIDATE_ONLY" == "true" ]; then
        cmd="$cmd --dry-run"
    fi

    if [ "$TEST_LEVEL" == "NoTestRun" ]; then
        cmd="$cmd --test-level NoTestRun"
    fi

    eval $cmd

    print_success "Stage 1 completed: Objects & Platform Events deployed"
}

deploy_stage_2_apex() {
    print_header "Stage 2: Deploying Apex Classes"

    if [ ! -d "$SOURCE_DIR/classes" ]; then
        print_warning "No classes directory found, skipping Stage 2"
        return 0
    fi

    print_info "Deploying Apex classes..."

    local cmd="sf project deploy start \
        --source-dir $SOURCE_DIR/classes \
        --target-org $SANDBOX_ALIAS \
        --api-version $API_VERSION \
        --wait 30"

    if [ "$VALIDATE_ONLY" == "true" ]; then
        cmd="$cmd --dry-run"
    fi

    # Run tests only in Stage 2 (Apex)
    if [ "$TEST_LEVEL" != "NoTestRun" ]; then
        cmd="$cmd --test-level $TEST_LEVEL"
    else
        cmd="$cmd --test-level NoTestRun"
    fi

    eval $cmd

    print_success "Stage 2 completed: Apex Classes deployed"
}

deploy_stage_3_lwc() {
    print_header "Stage 3: Deploying LWC Components"

    if [ ! -d "$SOURCE_DIR/lwc" ]; then
        print_warning "No lwc directory found, skipping Stage 3"
        return 0
    fi

    print_info "Deploying Lightning Web Components..."

    local cmd="sf project deploy start \
        --source-dir $SOURCE_DIR/lwc \
        --target-org $SANDBOX_ALIAS \
        --api-version $API_VERSION \
        --wait 30"

    if [ "$VALIDATE_ONLY" == "true" ]; then
        cmd="$cmd --dry-run"
    fi

    cmd="$cmd --test-level NoTestRun"

    eval $cmd

    print_success "Stage 3 completed: LWC Components deployed"
}

deploy_single() {
    print_header "Deploying All Components (Single Stage)"

    local cmd="sf project deploy start \
        --source-dir $SOURCE_DIR \
        --target-org $SANDBOX_ALIAS \
        --api-version $API_VERSION \
        --test-level $TEST_LEVEL \
        --wait 60 \
        --verbose"

    if [ "$VALIDATE_ONLY" == "true" ]; then
        cmd="$cmd --dry-run"
    fi

    eval $cmd

    print_success "Deployment completed"
}

# =============================================================================
# Main Script
# =============================================================================

VALIDATE_ONLY="false"
SINGLE_DEPLOY="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--alias) SANDBOX_ALIAS="$2"; shift 2 ;;
        -v|--validate) VALIDATE_ONLY="true"; shift ;;
        -s|--skip-tests) TEST_LEVEL="NoTestRun"; shift ;;
        --single) SINGLE_DEPLOY="true"; shift ;;
        -h|--help) show_help ;;
        *) print_error "Unknown option: $1"; exit 1 ;;
    esac
done

print_header "Salesforce Deployment Script"
echo "Target: $SANDBOX_ALIAS"
echo "Mode: $([ "$VALIDATE_ONLY" == "true" ] && echo "Validation Only" || echo "Full Deployment")"
echo "Started at: $(date)"

check_prerequisites
check_authentication

if [ "$SINGLE_DEPLOY" == "true" ]; then
    deploy_single
else
    print_info "Using STAGED deployment for dependency resolution"
    echo ""
    echo "Deployment will proceed in 3 stages:"
    echo "  1. Objects & Platform Events"
    echo "  2. Apex Classes"
    echo "  3. LWC Components"
    echo ""

    if [ "$VALIDATE_ONLY" != "true" ]; then
        read -p "Proceed with staged deployment? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Deployment cancelled."
            exit 0
        fi
    fi

    deploy_stage_1_objects
    deploy_stage_2_apex
    deploy_stage_3_lwc
fi

print_header "Deployment Complete!"
echo "Completed at: $(date)"

# Show summary
sf project deploy report --target-org "$SANDBOX_ALIAS" 2>/dev/null || true
