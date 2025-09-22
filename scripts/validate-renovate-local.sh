#!/usr/bin/env bash

# validate-renovate-local.sh
#
# Purpose: Quick local validation of Renovate configuration before committing
# Created: 2025-09-22
# Usage: ./scripts/validate-renovate-local.sh

set -euo pipefail

echo "🔍 Quick Renovate Configuration Validation"
echo "=========================================="
echo

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS") echo -e "${GREEN}✅ PASS:${NC} $message" ;;
        "FAIL") echo -e "${RED}❌ FAIL:${NC} $message" ;;
        "INFO") echo -e "${YELLOW}ℹ️  INFO:${NC} $message" ;;
    esac
}

# 1. Check if config file exists
if [[ ! -f ".github/renovate.json5" ]]; then
    print_status "FAIL" "Configuration file missing at .github/renovate.json5"
    exit 1
fi
print_status "PASS" "Configuration file found"

# 2. JSON5 syntax validation
print_status "INFO" "Checking JSON5 syntax..."
if ! npx json5 --validate .github/renovate.json5 >/dev/null 2>&1; then
    print_status "FAIL" "Invalid JSON5 syntax"
    exit 1
fi
print_status "PASS" "JSON5 syntax is valid"

# 3. Official Renovate validation  
print_status "INFO" "Running official Renovate validator..."

# Try Docker first (avoids ES module conflicts), fallback to npx
if command -v docker >/dev/null 2>&1; then
    print_status "INFO" "Using Docker-based validator (recommended)"
    if docker run --rm -v "$PWD:/usr/src/app" ghcr.io/renovatebot/renovate:latest renovate-config-validator "/usr/src/app/.github/renovate.json5" >/dev/null 2>&1; then
        print_status "PASS" "Renovate configuration is valid"
    else
        print_status "FAIL" "Renovate configuration validation failed"
        echo
        echo "Run with details:"
        echo "docker run --rm -v \"\$PWD:/usr/src/app\" ghcr.io/renovatebot/renovate:latest renovate-config-validator \"/usr/src/app/.github/renovate.json5\""
        exit 1
    fi
else
    print_status "INFO" "Docker not available, trying npx (may have ES module issues)"
    if npx --yes --package renovate -- renovate-config-validator .github/renovate.json5 >/dev/null 2>&1; then
        print_status "PASS" "Renovate configuration is valid"
    else
        print_status "FAIL" "Renovate configuration validation failed (likely ES module conflicts)"
        echo
        echo "Install Docker for reliable validation, or run with details:"
        echo "npx --yes --package renovate -- renovate-config-validator .github/renovate.json5"
        exit 1
    fi
fi

echo
print_status "PASS" "All validations passed! ✨"
echo
echo "💡 For comprehensive validation, run:"
echo "   ./scripts/validate-renovate-ci.sh"
