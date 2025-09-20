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
    echo "Examples:"
    echo "  $0                                    # Build standard target with default tag"
    echo "  $0 dev my-dev-image:latest           # Build dev target with custom tag"
    echo "  $0 standard my-local-build:v1.0.0    # Build standard with version tag"
    echo ""
    echo "This script uses GitHub token from 'gh auth' securely via secret mounting."
    exit 0
fi

# Default values
TARGET="${1:-standard}"
TAG="${2:-agentic-container:local}"

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
