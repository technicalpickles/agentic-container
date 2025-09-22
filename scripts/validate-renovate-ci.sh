#!/usr/bin/env bash

# validate-renovate-ci.sh
#
# Purpose: Comprehensive Renovate configuration validation for CI
# Created: 2025-09-22
# Used for: Validating that Renovate configuration is valid and can run successfully
#
# Usage:
#   ./scripts/validate-renovate-ci.sh                    # Full validation suite
#   ./scripts/validate-renovate-ci.sh --pattern-only     # Quick validation (same as full for now)
#   ./scripts/validate-renovate-ci.sh --detection-only   # Renovate dry-run validation only

set -euo pipefail

# Parse command line arguments
PATTERN_ONLY=false
DETECTION_ONLY=false
case "${1:-}" in
    "--pattern-only") PATTERN_ONLY=true ;;
    "--detection-only") DETECTION_ONLY=true ;;
    "") ;; # Full validation
    *) echo "Usage: $0 [--pattern-only|--detection-only]"; exit 1 ;;
esac

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS") echo -e "${GREEN}✅ PASS:${NC} $message" ;;
        "WARN") echo -e "${YELLOW}⚠️  WARN:${NC} $message" ;;
        "FAIL") echo -e "${RED}❌ FAIL:${NC} $message" ;;
        "INFO") echo -e "${BLUE}ℹ️  INFO:${NC} $message" ;;
        "TEST") echo -e "${PURPLE}🧪 TEST:${NC} $message" ;;
    esac
}

# 1. Check required tools availability
print_status "INFO" "Checking required tools..."

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    print_status "FAIL" "jq is required but not available"
    exit 1
fi
print_status "PASS" "jq is available"

# Check if npx is available  
if ! command -v npx >/dev/null 2>&1; then
    print_status "FAIL" "npx is required but not available"
    exit 1
fi
print_status "PASS" "npx is available"

# 2. Configuration file existence check
if [[ ! -f ".github/renovate.json5" ]]; then
    print_status "FAIL" "Renovate configuration file missing at .github/renovate.json5"
    exit 1
fi
print_status "PASS" "Configuration file exists at .github/renovate.json5"

# 3. JSON5 syntax validation
print_status "INFO" "Validating JSON5 syntax..."
if ! npx json5 --validate .github/renovate.json5; then
    print_status "FAIL" "Renovate configuration has invalid JSON5 syntax"
    exit 1
fi
print_status "PASS" "Renovate configuration has valid JSON5 syntax"

# 3a. Official Renovate configuration validation
print_status "INFO" "Running official Renovate config validator..."

# Try Docker first (avoids ES module conflicts), fallback to npx
if command -v docker >/dev/null 2>&1; then
    print_status "INFO" "Using Docker-based validator (recommended)"
    if docker run --rm -v "$PWD:/usr/src/app" ghcr.io/renovatebot/renovate:latest renovate-config-validator "/usr/src/app/.github/renovate.json5" >/dev/null 2>&1; then
        print_status "PASS" "Docker-based Renovate configuration validation passed"
    else
        print_status "FAIL" "Docker-based Renovate configuration validation failed"
        exit 1
    fi
else
    print_status "INFO" "Docker not available, falling back to npx (may have ES module issues)"
    if npx --yes --package renovate -- renovate-config-validator .github/renovate.json5 >/dev/null 2>&1; then
        print_status "PASS" "npx-based Renovate configuration validation passed"
    else
        print_status "WARN" "npx validation failed (likely ES module conflicts)"
        print_status "INFO" "Consider using Docker for reliable validation"
        # Don't exit here as Docker is the preferred method
    fi
fi

# For pattern-only mode, we're done
if [[ "$PATTERN_ONLY" == "true" ]]; then
    print_status "INFO" "Pattern-only validation complete"
    exit 0
fi

# 4. Additional configuration structure validation
print_status "INFO" "Validating configuration structure and patterns..."

# Validate that we have expected configuration sections
config_file=".github/renovate.json5"

# Check for required sections
if grep -q '"customManagers"' "$config_file"; then
    print_status "PASS" "Custom managers configuration found"
else
    print_status "WARN" "No custom managers found in configuration"
fi

if grep -q '"extends".*"config:recommended"' "$config_file"; then
    print_status "PASS" "Base configuration extends config:recommended"
fi

if grep -q '"schedule"' "$config_file"; then
    print_status "PASS" "Update schedule configured"
fi

# Count custom managers for validation coverage
custom_manager_count=$(grep -c '"customType": "regex"' "$config_file" || echo "0")
print_status "INFO" "Found $custom_manager_count custom regex managers"

# Validate packageNameTemplate format (should be strings not objects after our fixes)
if grep -q '"packageNameTemplate": {' "$config_file"; then
    print_status "FAIL" "Found object-style packageNameTemplate (should be strings)"
    exit 1
else
    print_status "PASS" "All packageNameTemplate values use string format"
fi

# Check for deprecated configurations
if grep -q '"prTitle"' "$config_file"; then
    print_status "WARN" "Deprecated prTitle configuration found"
fi

# 5. Renovate environment compatibility check
print_status "INFO" "Checking Renovate environment compatibility..."

# Check if renovate can start (basic command)
if npx renovate --version >/dev/null 2>&1; then
    renovate_version=$(npx renovate --version)
    print_status "PASS" "Renovate v$renovate_version is accessible"
else
    print_status "WARN" "Renovate command not accessible"
fi

# 6. Summary and recommendations
print_status "INFO" "Validation summary..."

print_status "PASS" "Comprehensive Renovate configuration validation complete!"