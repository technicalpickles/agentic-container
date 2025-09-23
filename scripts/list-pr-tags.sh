#!/usr/bin/env bash

# list-pr-tags.sh
#
# Purpose: List all ephemeral PR tags in the GitHub Container Registry
# Created: 2025-09-23
# Usage: ./scripts/list-pr-tags.sh [PR_NUMBER]
#
# This script helps identify which ephemeral PR tags exist in the registry,
# useful for manual cleanup or verification that cleanup worked properly.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="ghcr.io"
IMAGE_NAME="technicalpickles/agentic-container"
PR_NUMBER="${1:-}"

echo -e "${BLUE}🔍 Listing ephemeral PR tags from ${REGISTRY}/${IMAGE_NAME}${NC}"
echo

# Check if GitHub CLI is available
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ Error: GitHub CLI (gh) is required but not installed${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Error: Not authenticated with GitHub CLI${NC}"
    echo "Run: gh auth login"
    exit 1
fi

echo -e "${YELLOW}📋 Fetching package versions...${NC}"

# Function to list tags with a specific pattern
list_tags() {
    local pattern="$1"
    local description="$2"
    
    echo -e "\n${BLUE}🏷️  ${description}${NC}"
    echo "Pattern: ${pattern}"
    echo
    
    # Get package versions (tags) using GitHub CLI
    local tags
    if tags=$(gh api "/orgs/technicalpickles/packages/container/agentic-container/versions" \
        --paginate \
        --jq '.[] | select(.metadata.container.tags[] | test("^'"$pattern"'")) | .metadata.container.tags[]' \
        2>/dev/null | sort); then
        
        if [ -n "$tags" ]; then
            echo "$tags" | while read -r tag; do
                echo -e "  ${GREEN}✓${NC} $tag"
            done
            
            local count
            count=$(echo "$tags" | wc -l | tr -d ' ')
            echo
            echo -e "${YELLOW}📊 Found ${count} matching tags${NC}"
        else
            echo -e "  ${YELLOW}ℹ️  No tags found matching pattern${NC}"
        fi
    else
        echo -e "  ${RED}❌ Error fetching tags (check permissions)${NC}"
    fi
}

# List tags based on input
if [ -n "$PR_NUMBER" ]; then
    # List tags for specific PR
    list_tags "pr-${PR_NUMBER}-" "Tags for PR #${PR_NUMBER}"
else
    # List all PR tags
    list_tags "pr-[0-9]" "All ephemeral PR tags"
fi

echo
echo -e "${BLUE}💡 Usage Tips:${NC}"
echo "• To clean up specific PR: Use manual workflow with PR number"
echo "• To clean up all PR tags: Use manual workflow without PR number"  
echo "• To see what would be deleted: Use dry_run option in manual workflow"
echo
echo -e "${YELLOW}🔗 Manual cleanup workflow:${NC}"
echo "https://github.com/technicalpickles/agentic-container/actions/workflows/manual-cleanup-pr-images.yml"
