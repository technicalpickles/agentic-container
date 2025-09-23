#!/usr/bin/env bash

# list-pr-tags.sh
#
# Purpose: Guide for listing ephemeral PR tags in the GitHub Container Registry
# Created: 2025-09-23
# Usage: ./scripts/list-pr-tags.sh [PR_NUMBER]
#
# This script provides instructions for finding ephemeral PR tags since
# GitHub CLI requires read:packages scope which may not be available locally.

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

# Check available tools
HAS_GH=false
HAS_DOCKER=false

if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    HAS_GH=true
fi

if command -v docker &> /dev/null; then
    HAS_DOCKER=true
fi

if [ "$HAS_GH" = false ] && [ "$HAS_DOCKER" = false ]; then
    echo -e "${RED}❌ Error: Neither GitHub CLI nor Docker is available${NC}"
    echo "Install one of:"
    echo "• GitHub CLI: https://cli.github.com/"
    echo "• Docker: https://docker.com/"
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
    
    local tags=""
    local success=false
    
    # Try GitHub CLI first if available
    if [ "$HAS_GH" = true ]; then
        echo -e "${YELLOW}🔍 Trying GitHub CLI...${NC}"
        
        # First, let's try the simpler approach - get all tags and filter locally
        local all_tags
        if all_tags=$(gh api "/users/technicalpickles/packages/container/agentic-container/versions" \
            --paginate \
            --jq '.[].metadata.container.tags[]' \
            2>/dev/null); then
            
            echo -e "  ${BLUE}📋 All available tags:${NC}"
            echo "$all_tags" | head -10 | sed 's/^/    /'
            if [ $(echo "$all_tags" | wc -l) -gt 10 ]; then
                echo "    ... and $(( $(echo "$all_tags" | wc -l) - 10 )) more"
            fi
            echo
            
            # Filter for PR tags
            tags=$(echo "$all_tags" | grep -E "^$pattern" | sort || true)
            success=true
        else
            echo -e "  ${YELLOW}⚠️  GitHub CLI failed, trying alternative endpoint...${NC}"
            # Try the org endpoint instead
            if all_tags=$(gh api "/orgs/technicalpickles/packages/container/agentic-container/versions" \
                --paginate \
                --jq '.[].metadata.container.tags[]' \
                2>/dev/null); then
                
                echo -e "  ${BLUE}📋 All available tags (org endpoint):${NC}"
                echo "$all_tags" | head -10 | sed 's/^/    /'
                echo
                
                tags=$(echo "$all_tags" | grep -E "^$pattern" | sort || true)
                success=true
            fi
        fi
    fi
    
    # Try Docker if GitHub CLI failed or isn't available
    if [ "$success" = false ] && [ "$HAS_DOCKER" = true ]; then
        echo -e "${YELLOW}🔍 Trying Docker registry API...${NC}"
        # Note: This approach requires authentication to work properly
        # For now, we'll provide instructions for manual checking
        echo -e "  ${YELLOW}ℹ️  Docker-based tag listing requires additional setup${NC}"
        echo -e "  ${BLUE}💡 Try these manual approaches:${NC}"
        echo "     1. Check GitHub Packages UI: https://github.com/technicalpickles/agentic-container/pkgs/container/agentic-container"
        echo "     2. Use 'gh auth login' and try again"
        echo "     3. Use the manual cleanup workflow with dry_run=true to see what tags exist"
        return
    fi
    
    # Display results
    if [ "$success" = true ]; then
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
        echo -e "  ${RED}❌ Unable to fetch tags${NC}"
        echo -e "  ${BLUE}💡 Alternative approaches:${NC}"
        echo "     • Visit: https://github.com/technicalpickles/agentic-container/pkgs/container/agentic-container"
        echo "     • Run manual cleanup with dry_run=true to see what exists"
    fi
}

# List tags based on input
if [ -n "$PR_NUMBER" ]; then
    # List tags for specific PR
    list_tags "pr-${PR_NUMBER}-" "Tags for PR #${PR_NUMBER}"
else
    # List all PR tags (more permissive pattern)
    list_tags "pr-" "All ephemeral PR tags"
fi

echo
echo -e "${BLUE}💡 Usage Tips:${NC}"
echo "• To clean up specific PR: Use manual workflow with PR number"
echo "• To clean up all PR tags: Use manual workflow without PR number"  
echo "• To see what would be deleted: Use dry_run option in manual workflow"
echo
echo -e "${YELLOW}🔗 Manual cleanup workflow:${NC}"
echo "https://github.com/technicalpickles/agentic-container/actions/workflows/manual-cleanup-pr-images.yml"
