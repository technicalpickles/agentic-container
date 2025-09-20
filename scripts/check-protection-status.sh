#!/usr/bin/env bash

# check-protection-status.sh
#
# Purpose: Check and verify branch protection and CI status
# Created: 2024-01-20  
# Used for: Troubleshooting and monitoring branch protection setup
#
# This script helps verify that branch protection rules are working
# correctly and provides debugging information for CI status checks.

set -euo pipefail

# Configuration
OWNER="$(gh repo view --json owner --jq '.owner.login' 2>/dev/null || echo "unknown")"
REPO="$(gh repo view --json name --jq '.name' 2>/dev/null || echo "unknown")"
BRANCH="${1:-main}"

echo "🔍 Branch Protection Status Check"
echo "Repository: ${OWNER}/${REPO}"
echo "Branch: ${BRANCH}"
echo "$(date)"
echo ""

# Check if GitHub CLI is available
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    exit 1
fi

# Function to format JSON output nicely
format_json() {
    if command -v jq &> /dev/null; then
        jq '.'
    else
        cat
    fi
}

echo "🛡️  BRANCH PROTECTION STATUS"
echo "================================"

# Check if branch protection exists
if gh api "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" &> /dev/null; then
    echo "✅ Branch protection is ENABLED"
    
    # Get full protection details
    echo ""
    echo "📋 Protection Rules:"
    gh api "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" | format_json
    
    echo ""
    echo "🔒 Required Status Checks:"
    REQUIRED_CHECKS=$(gh api "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection/required_status_checks" 2>/dev/null || echo '{"contexts":[]}')
    if echo "$REQUIRED_CHECKS" | jq -e '.contexts | length > 0' &> /dev/null; then
        echo "$REQUIRED_CHECKS" | jq -r '.contexts[]' | while read -r check; do
            echo "  ✓ $check"
        done
        echo ""
        echo "Strict mode (up-to-date branch required): $(echo "$REQUIRED_CHECKS" | jq -r '.strict')"
    else
        echo "  ⚠️  No required status checks configured"
    fi
else
    echo "❌ Branch protection is NOT ENABLED"
fi

echo ""
echo "🔄 AUTO-MERGE STATUS"
echo "====================="

AUTO_MERGE=$(gh api "repos/${OWNER}/${REPO}" --jq '.allow_auto_merge' 2>/dev/null || echo "false")
if [[ "$AUTO_MERGE" == "true" ]]; then
    echo "✅ Auto-merge is ENABLED for this repository"
else
    echo "❌ Auto-merge is NOT ENABLED for this repository"
fi

echo ""
echo "🚦 RECENT CI STATUS"
echo "==================="

# Get recent commits and their check status
echo "Recent commits and their CI status:"
gh api "repos/${OWNER}/${REPO}/commits" --paginate=false | jq -r '.[0:5][] | "\(.sha[0:7]) \(.commit.message | split("\n")[0]) - \(.commit.author.date)"' | while read -r line; do
    commit_sha=$(echo "$line" | cut -d' ' -f1)
    echo ""
    echo "Commit: $line"
    
    # Get check runs for this commit
    CHECK_RUNS=$(gh api "repos/${OWNER}/${REPO}/commits/${commit_sha}/check-runs" 2>/dev/null || echo '{"check_runs":[]}')
    if echo "$CHECK_RUNS" | jq -e '.check_runs | length > 0' &> /dev/null; then
        echo "Check runs:"
        echo "$CHECK_RUNS" | jq -r '.check_runs[] | "  \(.name): \(.status) \(if .conclusion then "(\(.conclusion))" else "" end)"'
    else
        echo "  No check runs found"
    fi
    
    # Limit to first commit for detailed output
    break
done

echo ""
echo "📊 WORKFLOW STATUS"
echo "=================="

echo "Recent workflow runs:"
gh run list --limit 5 --json status,conclusion,name,createdAt,headBranch | jq -r '.[] | "\(.name): \(.status) \(if .conclusion then "(\(.conclusion))" else "" end) on \(.headBranch) - \(.createdAt)"'

echo ""
echo "🔧 TROUBLESHOOTING INFO"  
echo "======================="

# Check if there are any open PRs
OPEN_PRS=$(gh pr list --state open --json number,title,headRefName | jq length)
echo "Open Pull Requests: $OPEN_PRS"

if [[ $OPEN_PRS -gt 0 ]]; then
    echo ""
    echo "Open PRs and their merge status:"
    gh pr list --state open --json number,title,headRefName,mergeable,mergeStateStatus | jq -r '.[] | "#\(.number): \(.title) - Mergeable: \(.mergeable // "unknown") (\(.mergeStateStatus // "unknown"))"'
fi

echo ""
echo "Expected status check names from workflows:"
echo "  From lint-and-validate.yml:"
echo "    - Lint Dockerfiles"
echo "    - Lint YAML files" 
echo "    - Security Scan"
echo "  From build-test-publish.yml:"
echo "    - Build Standard Image"
echo "    - Cookbook Tests Summary"
echo ""
echo "Note: The parallel-validation job creates matrix-based checks like"
echo "'Parallel Validation (test-cookbooks, Test Cookbooks, python-cli)'"
echo "but we use the summary job instead for cleaner protection rules."

echo ""
echo "💡 RECOMMENDATIONS"
echo "=================="

if [[ "$AUTO_MERGE" != "true" ]]; then
    echo "• Enable auto-merge: gh api repos/${OWNER}/${REPO} --method PATCH --raw-field allow_auto_merge=true"
fi

if ! gh api "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" &> /dev/null; then
    echo "• Set up branch protection: ./scripts/setup-branch-protection.sh"
fi

echo "• To test branch protection: Create a draft PR and verify merge is blocked"
echo "• To enable auto-merge on a PR: gh pr merge --auto --squash PR_NUMBER"

echo ""
echo "📚 For detailed setup instructions, see: docs/branch-protection-setup.md"
