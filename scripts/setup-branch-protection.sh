#!/usr/bin/env bash

# setup-branch-protection.sh
#
# Purpose: Automate GitHub branch protection rule configuration
# Created: 2024-01-20
# Used for: Setting up branch protection and auto-merge for agentic-container
#
# This script configures branch protection rules to require all CI checks
# to pass before allowing merges, and enables auto-merge functionality.

set -euo pipefail

# Configuration
OWNER="$(gh repo view --json owner --jq '.owner.login')"
REPO="$(gh repo view --json name --jq '.name')"
BRANCH="main"

echo "🔒 Setting up branch protection for ${OWNER}/${REPO}:${BRANCH}"

# Required status checks based on our CI workflows
REQUIRED_CHECKS=(
    "Lint Dockerfiles"
    "Lint YAML files"
    "Security Scan"
    "Build Standard Image"
    "Cookbook Tests Summary"
)

# Function to create JSON array from bash array
create_json_array() {
    local items=("$@")
    local json="["
    for i in "${!items[@]}"; do
        if [[ $i -gt 0 ]]; then
            json+=","
        fi
        json+="\"${items[$i]}\""
    done
    json+="]"
    echo "$json"
}

# Check if GitHub CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo "Install it with: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI is ready"

# Show current branch protection status
echo ""
echo "📋 Current branch protection status:"
if gh api "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" &> /dev/null; then
    echo "✅ Branch protection is currently enabled"
    echo "Current required status checks:"
    gh api "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection/required_status_checks" --jq '.contexts[]?' 2>/dev/null || echo "  (none configured)"
else
    echo "⚠️  No branch protection currently configured"
fi

echo ""
echo "🔧 Configuring branch protection with the following settings:"
echo "  - Require pull request reviews (1 approval)"
echo "  - Dismiss stale reviews when new commits are pushed"
echo "  - Require status checks to pass before merging"
echo "  - Require branches to be up to date before merging"
echo "  - Require conversation resolution before merging"
echo "  - Include administrators in restrictions"
echo ""
echo "Required status checks:"
for check in "${REQUIRED_CHECKS[@]}"; do
    echo "  - $check"
done

echo ""
read -p "Do you want to apply these settings? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled by user"
    exit 1
fi

# Create the required status checks JSON
CONTEXTS_JSON=$(create_json_array "${REQUIRED_CHECKS[@]}")

# Apply branch protection rules
echo "🚀 Applying branch protection rules..."

# Note: We need to construct the JSON payload carefully
cat > /tmp/branch_protection.json << EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": $CONTEXTS_JSON
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

# Apply the branch protection rule
if gh api "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" \
    --method PUT \
    --input /tmp/branch_protection.json > /dev/null; then
    echo "✅ Branch protection rules applied successfully"
else
    echo "❌ Failed to apply branch protection rules"
    rm -f /tmp/branch_protection.json
    exit 1
fi

# Clean up temp file
rm -f /tmp/branch_protection.json

# Check if auto-merge is enabled at repository level
echo ""
echo "🔄 Checking auto-merge settings..."

AUTO_MERGE_ENABLED=$(gh api "repos/${OWNER}/${REPO}" --jq '.allow_auto_merge')
if [[ "$AUTO_MERGE_ENABLED" == "true" ]]; then
    echo "✅ Auto-merge is already enabled for this repository"
else
    echo "⚠️  Auto-merge is not enabled for this repository"
    echo ""
    read -p "Do you want to enable auto-merge? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if gh api "repos/${OWNER}/${REPO}" \
            --method PATCH \
            --raw-field allow_auto_merge=true > /dev/null; then
            echo "✅ Auto-merge enabled successfully"
        else
            echo "❌ Failed to enable auto-merge"
        fi
    fi
fi

echo ""
echo "🎉 Branch protection setup complete!"
echo ""
echo "📋 Summary:"
echo "  - Branch protection rules are active for '${BRANCH}' branch"
echo "  - All 5 essential CI status checks are required"
echo "  - Pull request reviews are required (1 approval)"
echo "  - Auto-merge is $([ "$AUTO_MERGE_ENABLED" == "true" ] && echo "enabled" || echo "available")"
echo ""
echo "💡 Next steps:"
echo "  1. Test the configuration with a draft PR"
echo "  2. Use 'Enable auto-merge' on PRs to automatically merge when ready"
echo "  3. Monitor CI reliability and adjust required checks as needed"
echo ""
echo "🔍 To view current settings:"
echo "  gh api repos/${OWNER}/${REPO}/branches/${BRANCH}/protection"
echo ""
echo "📚 See docs/branch-protection-setup.md for detailed usage guide"
