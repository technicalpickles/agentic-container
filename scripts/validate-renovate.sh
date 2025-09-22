#!/usr/bin/env bash

# validate-renovate.sh
#
# Purpose: Docker-only Renovate configuration validation
# Usage:
#   ./scripts/validate-renovate.sh        # Full validation
#   ./scripts/validate-renovate.sh --quick # Quick validation (no jq dependency)

set -euo pipefail

# Parse arguments
QUICK_MODE=false
if [[ "${1:-}" == "--quick" ]]; then
    QUICK_MODE=true
fi

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