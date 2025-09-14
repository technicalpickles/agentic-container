#!/usr/bin/env bash

# test-container.sh
#
# Purpose: Test the agentic container setup for devcontainer compatibility
# Created: 2025-01-14
# Usage: ./test-container.sh
#
# This script verifies that all development tools and environment setup
# work correctly in both interactive and non-interactive modes.

set -euo pipefail

# Ensure mise is activated
eval "$(mise activate bash)"

echo "=== Testing Agentic Container Setup ==="

# Test 1: Basic environment
echo "✓ Testing basic environment..."
echo "User: $(whoami)"
echo "Home: $HOME"
echo "Working directory: $(pwd)"
echo "Shell: $SHELL"

# Test 2: mise activation
echo "✓ Testing mise activation..."
if command -v mise >/dev/null 2>&1; then
    echo "mise version: $(mise --version)"
    echo "mise list:"
    mise list
else
    echo "❌ mise not found in PATH"
    exit 1
fi

# Test 3: Language tools
echo "✓ Testing language tools..."

# Python
if command -v python3 >/dev/null 2>&1; then
    echo "Python: $(python3 --version)"
else
    echo "❌ Python not found"
fi

# Node.js
if command -v node >/dev/null 2>&1; then
    echo "Node.js: $(node --version)"
    echo "npm: $(npm --version)"
else
    echo "❌ Node.js not found"
fi

# Ruby
if command -v ruby >/dev/null 2>&1; then
    echo "Ruby: $(ruby --version)"
else
    echo "❌ Ruby not found"
fi

# Go
if command -v go >/dev/null 2>&1; then
    echo "Go: $(go version)"
else
    echo "❌ Go not found"
fi

# Test 4: Docker availability
echo "✓ Testing Docker..."
if command -v docker >/dev/null 2>&1; then
    echo "Docker: $(docker --version)"
    # Test docker socket access
    if docker ps >/dev/null 2>&1; then
        echo "Docker daemon accessible"
    else
        echo "⚠️  Docker daemon not accessible (expected if not running Docker-in-Docker)"
    fi
else
    echo "❌ Docker not found"
fi

# Test 5: Git configuration
echo "✓ Testing Git configuration..."
echo "Git version: $(git --version)"
echo "Git user.name: $(git config --global user.name || echo 'Not set')"
echo "Git user.email: $(git config --global user.email || echo 'Not set')"
echo "Git safe directories: $(git config --global --get-all safe.directory || echo 'None configured')"

# Test 6: Common tools
echo "✓ Testing common tools..."
tools=(curl jq tree vim nano less htop)
for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "$tool: ✓"
    else
        echo "$tool: ❌"
    fi
done

# Test 7: Environment variables
echo "✓ Testing environment variables..."
echo "TERM: ${TERM:-not set}"
echo "LANG: ${LANG:-not set}"
echo "LC_ALL: ${LC_ALL:-not set}"

# Test 8: Non-interactive shell test
echo "✓ Testing non-interactive shell..."
if bash -c 'mise --version' >/dev/null 2>&1; then
    echo "mise works in non-interactive shell: ✓"
else
    echo "mise works in non-interactive shell: ❌"
fi

echo "=== Container test complete ==="
