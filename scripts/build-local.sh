#!/usr/bin/env bash

# build-local.sh
# Secure local build script that uses gh auth token without storing it on disk
#
# Usage: ./scripts/build-local.sh [target] [tag]
# Example: ./scripts/build-local.sh standard agentic-container:local

set -euo pipefail

# Check for help first
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [target] [tag]"
    echo ""
    echo "Arguments:"
    echo "  target    Docker build target (default: standard)"
    echo "  tag       Image tag (default: agentic-container:local)"
    echo ""
    echo "Available targets:"
    echo "  Base stages:"
    echo "    builder           Base Ubuntu build stage with common tools"
    echo "  Language stages:"
    echo "    ruby-stage        Ruby development environment"
    echo "    go-stage          Go development environment"
    echo "    node-stage        Node.js development environment"
    echo "    python-stage      Python development environment"
    echo "  Tool stages:"
    echo "    lefthook-stage    Git hooks manager"
    echo "    npm-globals-stage npm global packages (claude-code, codex)"
    echo "    starship-stage    Starship prompt"
    echo "    ast-grep-stage    AST search tool"
    echo "    goose-stage       Database migration tool"
    echo "  Complete images:"
    echo "    standard          Production-ready container (default)"
    echo "    dev               Development container with all languages"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Build standard target with default tag"
    echo "  $0 dev my-dev-image:latest           # Build dev target with custom tag"
    echo "  $0 node-stage node-only:latest       # Build just Node.js stage"
    echo "  $0 python-stage python-dev:v1.0.0    # Build Python stage with version tag"
    echo ""
    echo "This script uses GitHub token from 'gh auth' securely via secret mounting."
    exit 0
fi

# Default values
TARGET="${1:-standard}"
TAG="${2:-agentic-container:local}"

# Function to validate that the target stage exists in Dockerfile
validate_target() {
    local target="$1"
    local dockerfile="Dockerfile"

    if [[ ! -f "$dockerfile" ]]; then
        echo "❌ Error: Dockerfile not found in current directory"
        exit 1
    fi

    # Check if the target exists as a stage in the Dockerfile
    if ! grep -q "^FROM .* AS $target$" "$dockerfile"; then
        echo "❌ Error: Target '$target' not found in Dockerfile"
        echo ""
        echo "Available targets:"
        grep "^FROM .* AS " "$dockerfile" | sed 's/^FROM .* AS /  /' | sort
        echo ""
        echo "Use '$0 --help' for more information."
        exit 1
    fi
}

# Validate the target exists
validate_target "$TARGET"

echo "🔐 Using GitHub token from gh auth (no disk storage)"
echo "🏗️  Building target: $TARGET"
echo "🏷️  Tagging as: $TAG"

# Check if gh is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Error: GitHub CLI not authenticated. Run 'gh auth login' first."
    exit 1
fi

# Build with secret mounting using process substitution
# This creates a temporary file descriptor that gets cleaned up automatically
docker build \
    --target "$TARGET" \
    --secret id=github_token,src=<(gh auth token) \
    -t "$TAG" \
    .

echo "✅ Build completed successfully!"
echo "📦 Image tagged as: $TAG"
