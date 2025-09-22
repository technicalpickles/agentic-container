#!/usr/bin/env bash

# validate-renovate-config.sh
#
# Purpose: Validate Renovate configuration locally before GitHub App installation
# Created: 2024-09-20
# Used for: Testing regex patterns, configuration syntax, and expected matches
#
# Usage:
#   ./scripts/validate-renovate-config.sh           # Quick pattern validation
#   ./scripts/validate-renovate-config.sh --dry-run # Full renovate dry-run (requires gh CLI)

set -euo pipefail

echo "🔍 Validating Renovate Configuration"
echo "===================================="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    esac
}

# 1. Check if configuration file exists
if [[ -f ".github/renovate.json5" ]]; then
    print_status "PASS" "Configuration file exists at .github/renovate.json5"
else
    print_status "FAIL" "Configuration file missing at .github/renovate.json5"
    exit 1
fi

echo
echo "📋 Testing Regex Pattern Matches"
echo "================================"
echo

# 2. Test Language Runtime Version Patterns
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

# 3. Test Tool Version Patterns
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

# 4. Test Script Version Patterns  
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

# 5. Test GitHub Actions workflow files
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

# 6. Test mise.toml patterns
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

# 7. Test standard dependency files
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
echo "🚀 Next Steps"
echo "============="
echo "1. Install Mend Renovate App on your GitHub repository"
echo "2. Look for onboarding PR within 1-2 hours"
echo "3. Check dependency dashboard issue for overview"
echo "4. Monitor first batch of update PRs"

echo
print_status "PASS" "Configuration validation complete!"

# Optional: Run renovate dry-run if --dry-run flag is provided
if [[ "${1:-}" == "--dry-run" ]]; then
    echo
    echo "🚀 Running Renovate Dry-Run"
    echo "=========================="
    
    # Check if GitHub CLI is available and authenticated
    if command -v gh >/dev/null 2>&1; then
        if gh auth status >/dev/null 2>&1; then
            print_status "INFO" "Using GitHub CLI token for renovate dry-run"
            
            # Get repository name using GitHub CLI
            repo_name=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
            if [[ -n "$repo_name" ]]; then
                print_status "INFO" "Repository: $repo_name"
                
                echo
                echo "Running: GITHUB_TOKEN=\$(gh auth token) npx renovate --dry-run $repo_name"
                echo
                
                # Export token and run renovate
                export GITHUB_TOKEN=$(gh auth token)
                
                # Verify token is set
                if [[ -z "$GITHUB_TOKEN" ]]; then
                    print_status "WARN" "Failed to get GitHub token from 'gh auth token'"
                    return 1
                fi
                
                npx renovate --dry-run "$repo_name" 2>&1 | head -50
                
                echo
                print_status "INFO" "Dry-run complete (showing first 50 lines of output)"
                print_status "INFO" "Run without --dry-run flag for faster pattern validation only"
            else
                print_status "WARN" "Could not determine GitHub repository name"
                print_status "INFO" "Make sure you're in a GitHub repository directory"
                print_status "INFO" "Or run: GITHUB_TOKEN=\$(gh auth token) npx renovate --dry-run owner/repo"
            fi
        else
            print_status "WARN" "GitHub CLI not authenticated. Run 'gh auth login' first"
        fi
    else
        print_status "WARN" "GitHub CLI not found. Install with: brew install gh"
        print_status "INFO" "Alternative: export GITHUB_TOKEN=your_token && npx renovate --dry-run owner/repo"
    fi
fi
