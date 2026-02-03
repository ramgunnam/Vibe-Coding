#!/bin/bash

# Salesforce Deployment Script for DODD Sandbox
# This script handles deployment from GitHub to Salesforce sandbox
#
# Prerequisites:
#   - Salesforce CLI (sf) installed: https://developer.salesforce.com/tools/salesforcecli
#   - Git installed
#   - Access to the target Salesforce sandbox
#
# Usage:
#   ./scripts/deploy-to-sandbox.sh [options]
#
# Options:
#   -a, --alias       Sandbox alias (default: dodd-sandbox)
#   -v, --validate    Validate only (dry-run mode)
#   -s, --skip-tests  Skip test execution during deployment
#   -h, --help        Show this help message

set -e  # Exit on error

# =============================================================================
# Configuration (can be overridden via environment variables)
# =============================================================================
SANDBOX_ALIAS="${SF_SANDBOX_ALIAS:-dodd-sandbox}"
SOURCE_DIR="${SF_SOURCE_DIR:-force-app/main/default}"
TEST_LEVEL="${SF_TEST_LEVEL:-RunLocalTests}"
API_VERSION="${SF_API_VERSION:-66.0}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

show_help() {
    cat << EOF
Salesforce Deployment Script for DODD Sandbox

Usage: $(basename "$0") [options]

Options:
    -a, --alias ALIAS     Sandbox alias (default: $SANDBOX_ALIAS)
    -v, --validate        Validate only (dry-run mode, no actual deployment)
    -s, --skip-tests      Skip test execution (use NoTestRun)
    -t, --test-level LVL  Test level: NoTestRun, RunLocalTests, RunAllTestsInOrg
    -d, --source-dir DIR  Source directory (default: $SOURCE_DIR)
    -h, --help            Show this help message

Environment Variables:
    SF_SANDBOX_ALIAS      Override default sandbox alias
    SF_SOURCE_DIR         Override default source directory
    SF_TEST_LEVEL         Override default test level
    SF_API_VERSION        Override API version (default: $API_VERSION)

Examples:
    # Deploy with default settings
    ./scripts/deploy-to-sandbox.sh

    # Validate only (dry-run)
    ./scripts/deploy-to-sandbox.sh --validate

    # Deploy to a different sandbox
    ./scripts/deploy-to-sandbox.sh --alias my-other-sandbox

    # Deploy without running tests (use carefully)
    ./scripts/deploy-to-sandbox.sh --skip-tests
EOF
    exit 0
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check if sf CLI is installed
    if ! command -v sf &> /dev/null; then
        print_error "Salesforce CLI (sf) is not installed."
        echo "Please install it from: https://developer.salesforce.com/tools/salesforcecli"
        exit 1
    fi
    print_success "Salesforce CLI found: $(sf --version | head -1)"

    # Check if git is installed
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed."
        exit 1
    fi
    print_success "Git found: $(git --version)"

    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        print_error "Not inside a git repository."
        exit 1
    fi
    print_success "Inside git repository"
}

validate_project_structure() {
    print_header "Validating Project Structure"

    # Check for sfdx-project.json
    if [ ! -f "sfdx-project.json" ]; then
        print_error "sfdx-project.json not found in current directory!"
        print_info "Please run this script from the project root directory."
        exit 1
    fi
    print_success "sfdx-project.json found"

    # Check for source directory
    if [ ! -d "$SOURCE_DIR" ]; then
        print_error "Source directory '$SOURCE_DIR' not found!"
        exit 1
    fi
    print_success "Source directory '$SOURCE_DIR' found"

    # List what will be deployed
    print_info "Components to deploy:"
    if [ -d "$SOURCE_DIR/classes" ]; then
        local class_count=$(find "$SOURCE_DIR/classes" -name "*.cls" 2>/dev/null | wc -l)
        echo "  - Apex Classes: $class_count"
    fi
    if [ -d "$SOURCE_DIR/lwc" ]; then
        local lwc_count=$(find "$SOURCE_DIR/lwc" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        echo "  - Lightning Web Components: $lwc_count"
    fi
    if [ -d "$SOURCE_DIR/objects" ]; then
        local obj_count=$(find "$SOURCE_DIR/objects" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        echo "  - Custom Objects: $obj_count"
    fi
    if [ -d "$SOURCE_DIR/triggers" ]; then
        local trigger_count=$(find "$SOURCE_DIR/triggers" -name "*.trigger" 2>/dev/null | wc -l)
        echo "  - Triggers: $trigger_count"
    fi
    if [ -d "$SOURCE_DIR/platformEvents" ]; then
        local event_count=$(find "$SOURCE_DIR/platformEvents" -name "*.platformEvent-meta.xml" 2>/dev/null | wc -l)
        echo "  - Platform Events: $event_count"
    fi
    if [ -d "$SOURCE_DIR/permissionsets" ]; then
        local perm_count=$(find "$SOURCE_DIR/permissionsets" -name "*.permissionset-meta.xml" 2>/dev/null | wc -l)
        echo "  - Permission Sets: $perm_count"
    fi
}

check_authentication() {
    print_header "Checking Salesforce Authentication"

    # Check if the org is already authenticated
    if sf org list --json 2>/dev/null | grep -q "\"alias\": \"$SANDBOX_ALIAS\""; then
        print_success "Already authenticated to '$SANDBOX_ALIAS'"

        # Show org details
        print_info "Org details:"
        sf org display --target-org "$SANDBOX_ALIAS" 2>/dev/null | grep -E "^(Username|Instance Url|Org Id)" || true
    else
        print_warning "Not authenticated to '$SANDBOX_ALIAS'"
        echo ""
        read -p "Would you like to authenticate now? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Opening browser for authentication..."
            sf org login web --alias "$SANDBOX_ALIAS" --instance-url https://test.salesforce.com
            print_success "Authentication successful!"
        else
            print_error "Authentication required to continue."
            exit 1
        fi
    fi
}

run_validation() {
    print_header "Running Deployment Validation (Dry Run)"

    print_info "This will check if the deployment would succeed without making changes."
    print_info "Test Level: $TEST_LEVEL"
    echo ""

    sf project deploy start \
        --source-dir "$SOURCE_DIR" \
        --target-org "$SANDBOX_ALIAS" \
        --dry-run \
        --test-level "$TEST_LEVEL" \
        --api-version "$API_VERSION" \
        --verbose

    print_success "Validation completed successfully!"
}

run_deployment() {
    print_header "Deploying to Sandbox"

    print_info "Target Org: $SANDBOX_ALIAS"
    print_info "Source Directory: $SOURCE_DIR"
    print_info "Test Level: $TEST_LEVEL"
    print_info "API Version: $API_VERSION"
    echo ""

    # Confirm before deployment
    if [ "$VALIDATE_ONLY" != "true" ]; then
        read -p "Proceed with deployment? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Deployment cancelled."
            exit 0
        fi
    fi

    # Run the deployment
    sf project deploy start \
        --source-dir "$SOURCE_DIR" \
        --target-org "$SANDBOX_ALIAS" \
        --test-level "$TEST_LEVEL" \
        --api-version "$API_VERSION" \
        --verbose \
        --wait 60

    print_success "Deployment completed successfully!"
}

show_deployment_report() {
    print_header "Deployment Summary"

    sf project deploy report --target-org "$SANDBOX_ALIAS" 2>/dev/null || true
}

show_git_status() {
    print_header "Git Status"

    local current_branch=$(git branch --show-current)
    local last_commit=$(git log -1 --pretty=format:"%h - %s (%ci)")

    echo "Branch: $current_branch"
    echo "Last Commit: $last_commit"
    echo ""

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "There are uncommitted changes in your working directory."
        echo "Consider committing your changes before deployment."
    else
        print_success "Working directory is clean."
    fi
}

# =============================================================================
# Main Script
# =============================================================================

# Parse command line arguments
VALIDATE_ONLY="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--alias)
            SANDBOX_ALIAS="$2"
            shift 2
            ;;
        -v|--validate)
            VALIDATE_ONLY="true"
            shift
            ;;
        -s|--skip-tests)
            TEST_LEVEL="NoTestRun"
            shift
            ;;
        -t|--test-level)
            TEST_LEVEL="$2"
            shift 2
            ;;
        -d|--source-dir)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Main execution
print_header "Salesforce Deployment Script for DODD Sandbox"
echo "Started at: $(date)"

# Run all checks
check_prerequisites
validate_project_structure
show_git_status
check_authentication

# Execute deployment or validation
if [ "$VALIDATE_ONLY" == "true" ]; then
    run_validation
else
    # Run validation first
    echo ""
    read -p "Would you like to run a validation (dry-run) first? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_validation
        echo ""
        read -p "Validation successful! Proceed with actual deployment? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Deployment cancelled after validation."
            exit 0
        fi
    fi

    run_deployment
    show_deployment_report
fi

print_header "All Done!"
echo "Completed at: $(date)"
