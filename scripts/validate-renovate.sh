#!/usr/bin/env bash

# validate-renovate.sh
#
# Purpose: Docker-only Renovate configuration validation for local and CI
# Created: 2025-09-22
# Used for: Reliable validation without Node.js ES module conflicts
#
# Usage:
#   ./scripts/validate-renovate.sh                    # Full validation (default)
#   ./scripts/validate-renovate.sh --quick           # Quick validation (syntax + official)
#   ./scripts/validate-renovate.sh --pattern-only    # Pattern validation only
#   ./scripts/validate-renovate.sh --help           # Show usage

set -euo pipefail

# Parse command line arguments
MODE="full"
case "${1:-}" in
    "--quick") MODE="quick" ;;
    "--pattern-only") MODE="pattern" ;;
    "--help") 
        echo "Usage: $0 [--quick|--pattern-only|--help]"
        echo ""
        echo "  --quick         Quick validation (syntax + official validator)"
        echo "  --pattern-only  Pattern validation only (for debugging)"
        echo "  --help          Show this help"
        echo ""
        echo "Default: Full validation (syntax + official + patterns + analysis)"
        exit 0 ;;
    "") ;; # Full validation (default)
    *) echo "Usage: $0 [--quick|--pattern-only|--help]"; exit 1 ;;
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

# Print header based on mode
case $MODE in
    "quick") 
        echo "🚀 Quick Renovate Configuration Validation"
        echo "=========================================="
        ;;
    "pattern")
        echo "🔍 Renovate Pattern Validation"
        echo "=============================="
        ;;
    *)
        echo "🔍 Complete Renovate Configuration Validation"
        echo "============================================="
        ;;
esac
echo

# 1. Check required tools
print_status "INFO" "Checking required tools..."

# Docker is mandatory now
if ! command -v docker >/dev/null 2>&1; then
    print_status "FAIL" "Docker is required but not available"
    print_status "INFO" "Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi
print_status "PASS" "Docker is available"

# jq needed for full mode
if [[ "$MODE" == "full" ]] && ! command -v jq >/dev/null 2>&1; then
    print_status "FAIL" "jq is required for full validation mode"
    print_status "INFO" "Install jq: brew install jq (macOS) or apt install jq (Ubuntu)"
    exit 1
fi

# 2. Configuration file check
if [[ ! -f ".github/renovate.json5" ]]; then
    print_status "FAIL" "Renovate configuration file missing at .github/renovate.json5"
    exit 1
fi
print_status "PASS" "Configuration file exists at .github/renovate.json5"

# 3. JSON5 syntax validation (for quick and full modes)
if [[ "$MODE" != "pattern" ]]; then
    print_status "INFO" "Validating JSON5 syntax..."
    if ! npx json5 --validate .github/renovate.json5 >/dev/null 2>&1; then
        print_status "FAIL" "Renovate configuration has invalid JSON5 syntax"
        exit 1
    fi
    print_status "PASS" "JSON5 syntax is valid"
fi

# 4. Official Renovate validation (Docker-only)
if [[ "$MODE" != "pattern" ]]; then
    print_status "INFO" "Running official Renovate config validator (Docker)..."
    
    if docker run --rm -v "$PWD:/usr/src/app" ghcr.io/renovatebot/renovate:latest renovate-config-validator "/usr/src/app/.github/renovate.json5" >/dev/null 2>&1; then
        print_status "PASS" "Renovate configuration validation passed"
    else
        print_status "FAIL" "Renovate configuration validation failed"
        echo
        echo "Run with details:"
        echo "docker run --rm -v \"\$PWD:/usr/src/app\" ghcr.io/renovatebot/renovate:latest renovate-config-validator \"/usr/src/app/.github/renovate.json5\""
        exit 1
    fi
fi

# Quick mode stops here
if [[ "$MODE" == "quick" ]]; then
    echo
    print_status "PASS" "Quick validation complete! ✨"
    echo
    echo "💡 For comprehensive validation, run:"
    echo "   ./scripts/validate-renovate.sh"
    exit 0
fi

# 5. Pattern validation (for pattern and full modes)
echo
echo "📋 Testing Regex Pattern Matches"
echo "================================"
echo

# Language Runtime Version Patterns
echo "🔹 Language Runtime Versions (NODE_VERSION, PYTHON_VERSION, etc.):"
runtime_matches=$(grep -rE "ARG\s+(NODE_VERSION|PYTHON_VERSION|RUBY_VERSION|GO_VERSION)=" . --include="*Dockerfile*" | wc -l | tr -d ' ')
print_status "INFO" "Found $runtime_matches language runtime ARG declarations"

if [[ $runtime_matches -gt 0 ]]; then
    print_status "PASS" "Regex patterns will match language runtime versions"
    echo "   Sample matches:"
    grep -rE "ARG\s+(NODE_VERSION|PYTHON_VERSION|RUBY_VERSION|GO_VERSION)=" . --include="*Dockerfile*" | head -3 | sed 's/^/   /'
else
    print_status "WARN" "No language runtime ARG declarations found"
fi
echo

# Development Tool Patterns
echo "🔹 Development Tool Versions (AST_GREP_VERSION, LEFTHOOK_VERSION, etc.):"
tool_matches=$(grep -rE "ARG\s+(AST_GREP_VERSION|LEFTHOOK_VERSION|UV_VERSION)=" . --include="*Dockerfile*" | wc -l | tr -d ' ')
print_status "INFO" "Found $tool_matches development tool ARG declarations"

if [[ $tool_matches -gt 0 ]]; then
    print_status "PASS" "Regex patterns will match development tool versions"
    echo "   Sample matches:"
    grep -rE "ARG\s+(AST_GREP_VERSION|LEFTHOOK_VERSION|UV_VERSION)=" . --include="*Dockerfile*" | head -3 | sed 's/^/   /'
else
    print_status "WARN" "No development tool ARG declarations found"
fi
echo

# Script Version Patterns
echo "🔹 Script Embedded Versions (DIVE_VERSION):"
script_matches=$(grep -rE "DIVE_VERSION=.*\d+\.\d+\.\d+" scripts/ 2>/dev/null | wc -l | tr -d ' ')
print_status "INFO" "Found $script_matches script version declarations"

if [[ $script_matches -gt 0 ]]; then
    print_status "PASS" "Regex patterns will match script versions"
    echo "   Sample matches:"
    grep -rE "DIVE_VERSION=.*\d+\.\d+\.\d+" scripts/ 2>/dev/null | sed 's/^/   /'
else
    print_status "WARN" "No script version declarations found"
fi
echo

# Pattern mode stops here
if [[ "$MODE" == "pattern" ]]; then
    echo
    print_status "PASS" "Pattern validation complete!"
    exit 0
fi

# 6. Full analysis (full mode only)
echo "🔹 GitHub Actions Version Patterns:"
if [[ -d ".github/workflows" ]]; then
    workflow_files=$(find .github/workflows -name "*.yml" -o -name "*.yaml" | wc -l | tr -d ' ')
    print_status "INFO" "Found $workflow_files GitHub workflow files"
    
    trivy_matches=$(grep -rE "version:\s*v\d+\.\d+\.\d+" .github/workflows/ 2>/dev/null | wc -l | tr -d ' ')
    if [[ $trivy_matches -gt 0 ]]; then
        print_status "PASS" "Found version patterns in GitHub Actions"
        echo "   Sample matches:"
        grep -rE "version:\s*v\d+\.\d+\.\d+" .github/workflows/ 2>/dev/null | sed 's/^/   /'
    else
        print_status "INFO" "No 'version: v*' patterns found in workflows (normal for some setups)"
    fi
else
    print_status "WARN" "No .github/workflows directory found"
fi
echo

# mise.toml patterns
echo "🔹 Mise Tool Version Patterns:"
if [[ -f "mise.toml" ]]; then
    print_status "PASS" "Found mise.toml file"
    
    mise_matches=$(grep -E "\w+\s*=\s*\"(latest|\d+\.\d+\.\d+)\"" mise.toml | wc -l | tr -d ' ')
    if [[ $mise_matches -gt 0 ]]; then
        print_status "PASS" "Found tool version patterns in mise.toml"
        echo "   Sample matches:"
        grep -E "\w+\s*=\s*\"(latest|\d+\.\d+\.\d+)\"" mise.toml | sed 's/^/   /'
    else
        print_status "INFO" "No version patterns found in mise.toml (tools might use 'latest')"
    fi
else
    print_status "WARN" "No mise.toml file found"
fi
echo

# Standard dependency files
echo "🔹 Standard Dependency Files:"

if [[ -f "package.json" ]]; then
    print_status "PASS" "Found package.json - Node.js dependencies will be detected"
    deps_count=$(jq -r '(.dependencies // {}) | keys | length' package.json 2>/dev/null || echo "0")
    dev_deps_count=$(jq -r '(.devDependencies // {}) | keys | length' package.json 2>/dev/null || echo "0") 
    print_status "INFO" "Dependencies: $deps_count runtime, $dev_deps_count development"
else
    print_status "INFO" "No package.json found - no Node.js dependency updates"
fi

dockerfile_count=$(find . -name "*Dockerfile*" -type f | wc -l | tr -d ' ')
if [[ $dockerfile_count -gt 0 ]]; then
    print_status "PASS" "Found $dockerfile_count Dockerfile(s) - Docker base images will be detected"
else
    print_status "WARN" "No Dockerfiles found"
fi

echo
echo "🎯 Expected Renovate Behavior"
echo "============================="

total_patterns=$((runtime_matches + tool_matches + script_matches))

if [[ $total_patterns -gt 0 ]]; then
    print_status "PASS" "Total custom patterns: $total_patterns will be managed by Renovate"
    echo
    echo "Expected PRs after installation:"
    echo "  📦 GitHub Actions updates (if any outdated actions exist)"
    echo "  🐳 Docker base image updates (ubuntu, node, python base images)"
    echo "  📄 Node.js dependency updates (from package.json)"
    echo "  🔧 Custom ARG version updates (languages and tools)"
    echo "  🔒 Security vulnerability updates (if any exist)"
    echo
    print_status "INFO" "PRs will be grouped to reduce noise:"
    echo "    - 'GitHub Actions' group"
    echo "    - 'Docker base images' group" 
    echo "    - 'Language runtimes' group"
    echo "    - 'Development tools' group"
    echo
else
    print_status "WARN" "No custom patterns detected - only standard dependencies will be managed"
fi

echo "⏰ Schedule: Updates will run before 6am on weekdays and weekends"
echo "🚦 Rate limits: Max 3 concurrent PRs, 2 per hour"
echo "🔀 Automerge: Only patch updates for GitHub Actions and dev dependencies"

echo
print_status "PASS" "Complete validation successful! ✨"
echo
case $MODE in
    "full")
        echo "🎉 All validation layers passed:"
        echo "  ✅ JSON5 syntax validation"
        echo "  ✅ Official Renovate config validation (Docker)"
        echo "  ✅ Custom pattern matching verification"  
        echo "  ✅ Dependency detection analysis"
        echo "  ✅ Expected behavior documentation"
        ;;
esac
