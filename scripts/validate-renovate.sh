#!/usr/bin/env bash

# validate-renovate.sh
#
# Purpose: Comprehensive Renovate configuration validation
# Usage:
#   ./scripts/validate-renovate.sh                 # Full validation
#   ./scripts/validate-renovate.sh --quick         # Quick validation (syntax + official validator)
#   ./scripts/validate-renovate.sh --verbose       # Show detailed debug output
#   ./scripts/validate-renovate.sh --help          # Show help message

set -euo pipefail

# Parse arguments
QUICK_MODE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --quick              Quick validation (syntax + official validator only)"
            echo "  --verbose           Show detailed output from custom manager detection"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS") echo -e "${GREEN}✅ PASS:${NC} $message" ;;
        "FAIL") echo -e "${RED}❌ FAIL:${NC} $message" ;;
        "INFO") echo -e "${BLUE}ℹ️  INFO:${NC} $message" ;;
    esac
}

# Function to validate version detection
validate_version_detection() {
    local log_file="$1"
    
    print_status "INFO" "Validating specific version detection..."
    
    # Check for expected version patterns in codebase files first
    local expected_versions=(
        "AST_GREP_VERSION=0.39.5"
        "LEFTHOOK_VERSION=1.13.0" 
        "UV_VERSION=0.8.17"
        "NODE_VERSION=24.8.0"
        "PYTHON_VERSION=3.13.7"
    )
    
    # First verify these versions exist in the codebase
    print_status "INFO" "Checking for version declarations in codebase..."
    for version_pair in "${expected_versions[@]}"; do
        dep_name="${version_pair%=*}"
        expected_version="${version_pair#*=}"
        if grep -r "ARG.*${dep_name}=${expected_version}" . --include="*Dockerfile*" >/dev/null 2>&1; then
            if [[ "$VERBOSE" == "true" ]]; then
                print_status "INFO" "Found ${dep_name}=${expected_version} in codebase"
            fi
        else
            print_status "FAIL" "Expected version ${dep_name}=${expected_version} not found in codebase"
            print_status "INFO" "Update expected_versions in validate-renovate.sh or fix version in Dockerfile"
        fi
    done
    
    # Now check if Renovate detected these versions
    detected_count=0
    for version_pair in "${expected_versions[@]}"; do
        dep_name="${version_pair%=*}"
        expected_version="${version_pair#*=}"
        if grep -q "\"currentValue\".*\"${expected_version}\"" "$log_file"; then
            ((detected_count++))
            print_status "PASS" "Detected ${dep_name}=${expected_version}"
        else
            print_status "FAIL" "Missing detection for ${dep_name}=${expected_version}"
            if [[ "$VERBOSE" == "true" ]]; then
                print_status "INFO" "Debug: Checking what was detected for $dep_name..."
                grep -A3 -B3 "\"depName\".*\"${dep_name}\"" "$log_file" | head -10 || print_status "INFO" "No matches found for $dep_name"
            fi
        fi
    done
    
    # Validate minimum detection threshold
    min_required=3
    total_expected=${#expected_versions[@]}
    if [[ $detected_count -ge $min_required ]]; then
        print_status "PASS" "Custom managers detecting expected versions ($detected_count/$total_expected)"
    else
        print_status "FAIL" "Too few versions detected by custom managers ($detected_count/$total_expected, minimum: $min_required)"
        if [[ "$VERBOSE" == "false" ]]; then
            print_status "INFO" "Run with --verbose to see detailed debug information"
        fi
        exit 1
    fi
}

# Check Docker availability
if ! command -v docker >/dev/null 2>&1; then
    print_status "FAIL" "Docker is required but not available"
    exit 1
fi

# Check jq for full mode
if [[ "$QUICK_MODE" == "false" ]] && ! command -v jq >/dev/null 2>&1; then
    print_status "FAIL" "jq is required for full validation"
    exit 1
fi

# Check config file exists
if [[ ! -f ".github/renovate.json5" ]]; then
    print_status "FAIL" "Configuration file missing at .github/renovate.json5"
    exit 1
fi

# JSON5 syntax validation
if ! npx json5 --validate .github/renovate.json5 >/dev/null 2>&1; then
    print_status "FAIL" "Invalid JSON5 syntax"
    exit 1
fi
print_status "PASS" "JSON5 syntax valid"

# Official Renovate validation (using bin wrapper)
if ./bin/renovate-config-validator >/dev/null 2>&1; then
    print_status "PASS" "Renovate configuration valid"
else
    print_status "FAIL" "Renovate configuration validation failed"
    exit 1
fi

# Quick mode stops here
if [[ "$QUICK_MODE" == "true" ]]; then
    exit 0
fi

# Additional checks for full mode
deps_count=0
dev_deps_count=0
if [[ -f "package.json" ]]; then
    deps_count=$(jq -r '(.dependencies // {}) | keys | length' package.json 2>/dev/null || echo "0")
    dev_deps_count=$(jq -r '(.devDependencies // {}) | keys | length' package.json 2>/dev/null || echo "0")
    print_status "INFO" "Dependencies: $deps_count runtime, $dev_deps_count development"
fi

dockerfile_count=$(find . -name "*Dockerfile*" -type f | wc -l | tr -d ' ')
if [[ $dockerfile_count -gt 0 ]]; then
    print_status "INFO" "Found $dockerfile_count Dockerfile(s)"
fi

# Validate custom managers are detecting dependencies
print_status "INFO" "Testing custom manager dependency detection..."

# Create log directory if it doesn't exist
mkdir -p log

# Run Renovate dry-run to check custom manager detection
validation_log="log/renovate-validation-$(date +%Y%m%d-%H%M%S).log"
print_status "INFO" "Running Renovate dry-run to test custom managers..."

if [[ "$VERBOSE" == "true" ]]; then
    print_status "INFO" "Running: LOG_LEVEL=debug bin/renovate --platform=local --dry-run=log"
    print_status "INFO" "Log file: $validation_log"
fi

if LOG_LEVEL=debug bin/renovate --platform=local --dry-run=log > "$validation_log" 2>&1; then
    # Check if custom managers (regex) are working
    if grep -q '"regex":.*"fileCount"' "$validation_log"; then
        regex_file_count=$(grep -o '"regex":.*"fileCount":[0-9]*' "$validation_log" | grep -o '[0-9]*$' | head -1)
        regex_dep_count=$(grep -o '"regex":.*"depCount":[0-9]*' "$validation_log" | grep -o '[0-9]*$' | head -1)
        print_status "PASS" "Custom managers working: $regex_file_count files, $regex_dep_count dependencies"
        
        # Show total dependency stats for comparison
        total_deps=$(grep -o '"total":.*"depCount":[0-9]*' "$validation_log" | grep -o '[0-9]*$' | head -1)
        print_status "INFO" "Total dependencies detected: $total_deps (including built-in managers)"
        
        # Validate specific version detection
        validate_version_detection "$validation_log"
    else
        print_status "FAIL" "Custom managers not working - no regex manager stats found"
        if [[ "$VERBOSE" == "true" ]]; then
            print_status "INFO" "Debug: Checking for any manager stats..."
            grep -A5 -B5 '"managers":' "$validation_log" || print_status "INFO" "No manager stats found in output"
            print_status "INFO" "Full log available at: $validation_log"
        fi
        exit 1
    fi
else
    print_status "FAIL" "Failed to run Renovate dry-run for custom manager validation"
    if [[ "$VERBOSE" == "true" ]]; then
        print_status "INFO" "Error output:"
        tail -20 "$validation_log"
    fi
    print_status "INFO" "Full log available at: $validation_log"
    exit 1
fi

print_status "INFO" "Validation log saved to: $validation_log"
