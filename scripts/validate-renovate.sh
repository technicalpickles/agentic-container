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

if [[ -n "${CI:-}" ]]; then
    set -x
fi

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
    
    print_status "INFO" "Validating version detection..."
    
    # Get all _VERSION variables from codebase
    local codebase_versions=()
    while IFS= read -r version_var; do
        [[ -n "$version_var" ]] && codebase_versions+=("$version_var")
    done < <(grep -r "ARG.*_VERSION=" . --include="*Dockerfile*" --exclude-dir=node_modules --exclude-dir=log | grep -o "[A-Z_]*_VERSION" | sort -u || true)
    
    # Check what Renovate detected for each version variable
    detected_count=0
    total_expected=${#codebase_versions[@]}
    
    if [[ $total_expected -eq 0 ]]; then
        print_status "INFO" "No _VERSION variables found in codebase"
        return 0
    fi
    
    print_status "INFO" "Checking version detection for ${total_expected} _VERSION variables..."
    
    for version_var in "${codebase_versions[@]}"; do
        # Look for this version variable in Renovate output
        if grep -q "\"depName\".*\"${version_var}\"" "$log_file"; then
            # Extract the detected version
            detected_version=$(grep -A5 "\"depName\".*\"${version_var}\"" "$log_file" | grep -o "\"currentValue\".*\"[^\"]*\"" | head -1 | grep -o '"[^"]*"$' | tr -d '"' || true)
            if [[ -n "$detected_version" ]]; then
                detected_count=$((detected_count + 1))
                print_status "PASS" "Detected ${version_var}=${detected_version}"
            else
                print_status "FAIL" "Found ${version_var} in Renovate output but no version extracted"
                if [[ "$VERBOSE" == "true" ]]; then
                    print_status "INFO" "Debug: Checking what was detected for $version_var..."
                    grep -A5 -B3 "\"depName\".*\"${version_var}\"" "$log_file" | head -10
                fi
            fi
        else
            print_status "FAIL" "Missing detection for ${version_var}"
            if [[ "$VERBOSE" == "true" ]]; then
                print_status "INFO" "Debug: No matches found for $version_var in Renovate output"
            fi
        fi
    done
    
    # Validate detection threshold
    min_required=3
    if [[ $detected_count -ge $min_required ]]; then
        print_status "PASS" "Custom managers detecting versions ($detected_count/$total_expected)"
    else
        print_status "FAIL" "Too few versions detected by custom managers ($detected_count/$total_expected, minimum: $min_required)"
        if [[ "$VERBOSE" == "false" ]]; then
            print_status "INFO" "Run with --verbose to see detailed debug information"
        fi
        exit 1
    fi
}

# Function to validate version coverage - ensure all _VERSION variables have Renovate rules
validate_version_coverage() {
    print_status "INFO" "Validating version coverage..."
    
    # Find all _VERSION variables in codebase
    local found_versions=()
    while IFS= read -r version_var; do
        [[ -n "$version_var" ]] && found_versions+=("$version_var")
    done < <(grep -r "ARG.*_VERSION=" . --include="*Dockerfile*" --exclude-dir=node_modules --exclude-dir=log | grep -o "[A-Z_]*_VERSION" | sort -u || true)
    
    # Find all _VERSION variables configured in Renovate
    local configured_versions=()
    while IFS= read -r version_var; do
        [[ -n "$version_var" ]] && configured_versions+=("$version_var")
    done < <(grep -o "depName>[A-Z_]*_VERSION" .github/renovate.json5 | grep -o "[A-Z_]*_VERSION" | sort -u || true)
    
    # Find ignored dependencies
    local ignored_versions=()
    if grep -A10 '"ignoreDeps"' .github/renovate.json5 | grep -q '"[A-Z_]*_VERSION"'; then
        while IFS= read -r version_var; do
            [[ -n "$version_var" ]] && ignored_versions+=("$version_var")
        done < <(grep -A10 '"ignoreDeps"' .github/renovate.json5 | grep -o '"[A-Z_]*_VERSION"' | tr -d '"' | sort -u || true)
    fi
    
    # Check for missing coverage
    local missing_coverage=()
    local total_found=${#found_versions[@]}
    local covered_count=0
    
    if [[ $total_found -eq 0 ]]; then
        print_status "INFO" "No _VERSION variables found in codebase for coverage validation"
        return 0
    fi
    
    for version_var in "${found_versions[@]}"; do
        local is_configured=false
        local is_ignored=false
        
        # Check if configured
        for configured in "${configured_versions[@]}"; do
            if [[ "$version_var" == "$configured" ]]; then
                is_configured=true
                break
            fi
        done
        
        # Check if ignored (only if array has elements)
        if [[ ${#ignored_versions[@]} -gt 0 ]]; then
            for ignored in "${ignored_versions[@]}"; do
                if [[ "$version_var" == "$ignored" ]]; then
                    is_ignored=true
                    break
                fi
            done
        fi
        
        if [[ "$is_configured" == "true" ]]; then
            covered_count=$((covered_count + 1))
            if [[ "$VERBOSE" == "true" ]]; then
                print_status "PASS" "$version_var has Renovate rule"
            fi
        elif [[ "$is_ignored" == "true" ]]; then
            covered_count=$((covered_count + 1))
            if [[ "$VERBOSE" == "true" ]]; then
                print_status "INFO" "$version_var is explicitly ignored"
            fi
        else
            missing_coverage+=("$version_var")
            print_status "FAIL" "$version_var found in codebase but missing from Renovate rules"
        fi
    done
    
    # Report results
    if [[ ${#missing_coverage[@]} -eq 0 ]]; then
        print_status "PASS" "Version coverage complete: $covered_count/$total_found variables covered"
    else
        print_status "FAIL" "Version coverage incomplete: ${#missing_coverage[@]} variables missing Renovate rules"
        print_status "INFO" "Missing coverage for: ${missing_coverage[*]}"
        print_status "INFO" "Add custom managers or add to ignoreDeps in .github/renovate.json5"
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

# Validate version coverage - ensure all _VERSION variables have Renovate rules
validate_version_coverage
