#!/usr/bin/env bash

# list-pr-tags.sh
#
# Purpose: Guide for listing ephemeral PR tags in the GitHub Container Registry
# Created: 2025-09-23
# Usage: ./scripts/list-pr-tags.sh [PR_NUMBER]
#
# This script provides instructions for finding ephemeral PR tags since
# GitHub CLI requires read:packages scope which may not be available locally.

set -eo pipefail  # Remove 'u' flag to handle empty arrays

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

# Function to analyze PR status and recommend cleanup
analyze_pr_status() {
    local tags="$1"

    echo
    echo -e "${BLUE}🔍 Analyzing PR status for cleanup recommendations...${NC}"

    # Extract unique PR numbers from tags
    local pr_numbers
    pr_numbers=$(echo "$tags" | grep -oE 'pr-[0-9]+' | sed 's/pr-//' | sort -n | uniq)

    if [ -z "$pr_numbers" ]; then
        echo -e "  ${YELLOW}ℹ️  No PR numbers found in tags${NC}"
        return
    fi

    local open_prs=()
    local closed_prs=()
    local merged_prs=()
    local error_prs=()

    echo -e "${YELLOW}📋 Checking PR status...${NC}"

    # Check each PR's status
    while read -r pr_num; do
        if [ -n "$pr_num" ]; then
            local pr_info
            if pr_info=$(gh api "/repos/technicalpickles/agentic-container/pulls/$pr_num" --jq '{state: .state, merged: .merged, title: .title}' 2>/dev/null); then
                local state=$(echo "$pr_info" | jq -r '.state')
                local merged=$(echo "$pr_info" | jq -r '.merged')
                local title=$(echo "$pr_info" | jq -r '.title' | cut -c1-50)

                if [ "$state" = "open" ]; then
                    open_prs+=("$pr_num")
                    echo -e "  ${GREEN}🟢${NC} PR #$pr_num: Open - \"$title\""
                elif [ "$merged" = "true" ]; then
                    merged_prs+=("$pr_num")
                    echo -e "  ${BLUE}🔵${NC} PR #$pr_num: Merged - \"$title\""
                else
                    closed_prs+=("$pr_num")
                    echo -e "  ${RED}🔴${NC} PR #$pr_num: Closed - \"$title\""
                fi
            else
                error_prs+=("$pr_num")
                echo -e "  ${YELLOW}❓${NC} PR #$pr_num: Unable to fetch status"
            fi
        fi
    done <<< "$pr_numbers"

    echo
    echo -e "${BLUE}📊 Summary:${NC}"
    echo -e "  Open PRs: ${GREEN}${#open_prs[@]}${NC}"
    echo -e "  Merged PRs: ${BLUE}${#merged_prs[@]}${NC}"
    echo -e "  Closed PRs: ${RED}${#closed_prs[@]}${NC}"
    if [ ${#error_prs[@]} -gt 0 ]; then
        echo -e "  Error PRs: ${YELLOW}${#error_prs[@]}${NC}"
    fi

    # Recommendations
    echo
    echo -e "${BLUE}💡 Cleanup Recommendations:${NC}"

    if [ ${#merged_prs[@]} -gt 0 ] || [ ${#closed_prs[@]} -gt 0 ]; then
        echo -e "${YELLOW}🧹 Tags ready for cleanup:${NC}"

        for pr in "${merged_prs[@]}"; do
            local pr_tag_count
            pr_tag_count=$(echo "$tags" | grep -c "pr-$pr-" || echo "0")
            echo -e "  • PR #$pr (merged) - $pr_tag_count tags"
        done

        for pr in "${closed_prs[@]}"; do
            local pr_tag_count
            pr_tag_count=$(echo "$tags" | grep -c "pr-$pr-" || echo "0")
            echo -e "  • PR #$pr (closed) - $pr_tag_count tags"
        done

        echo
        echo -e "${GREEN}🚀 Recommended actions:${NC}"

        # Specific cleanup commands
        if [ ${#merged_prs[@]} -eq 1 ] && [ ${#closed_prs[@]} -eq 0 ]; then
            echo "  1. Clean up merged PR #${merged_prs[0]}:"
            echo "     Manual workflow → pr_number: ${merged_prs[0]} → dry_run: false"
        elif [ ${#closed_prs[@]} -eq 1 ] && [ ${#merged_prs[@]} -eq 0 ]; then
            echo "  1. Clean up closed PR #${closed_prs[0]}:"
            echo "     Manual workflow → pr_number: ${closed_prs[0]} → dry_run: false"
        elif [ $((${#merged_prs[@]} + ${#closed_prs[@]})) -le 3 ]; then
            echo "  1. Clean up individual PRs using manual workflow with pr_number"
            echo "  2. Or bulk cleanup: Manual workflow → pr_number: (empty) → dry_run: false"
        else
            echo "  1. Bulk cleanup recommended: Manual workflow → pr_number: (empty) → dry_run: false"
        fi

    else
        echo -e "${GREEN}✅ All PR tags are for open PRs - no cleanup needed${NC}"
    fi

    if [ ${#open_prs[@]} -gt 0 ]; then
        echo
        echo -e "${YELLOW}⚠️  Keep these tags (open PRs):${NC}"
        for pr in "${open_prs[@]}"; do
            local pr_tag_count
            pr_tag_count=$(echo "$tags" | grep -c "pr-$pr-" || echo "0")
            echo -e "  • PR #$pr - $pr_tag_count tags"
        done
    fi
}

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

    # Display results and analyze PR status
    if [ "$success" = true ]; then
        if [ -n "$tags" ]; then
            echo "$tags" | while read -r tag; do
                echo -e "  ${GREEN}✓${NC} $tag"
            done

            local count
            count=$(echo "$tags" | wc -l | tr -d ' ')
            echo
            echo -e "${YELLOW}📊 Found ${count} matching tags${NC}"

            # Analyze PR status if we found PR tags
            if [ "$pattern" = "pr-" ]; then
                analyze_pr_status "$tags"
            fi
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
