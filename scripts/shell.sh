#!/usr/bin/env bash

# build-and-shell.sh
# Build and run a container with an interactive shell
# Supports both Dockerfile targets and cookbook examples
#
# Usage: ./scripts/build-and-shell.sh [target|cookbook] [tag] [-- command...]
# Example: ./scripts/build-and-shell.sh standard
# Example: ./scripts/build-and-shell.sh python-cli
# Example: ./scripts/build-and-shell.sh standard -- python --version
# Example: ./scripts/build-and-shell.sh dev latest -- mise list

set -euo pipefail

# Check for help first
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [target|cookbook] [tag] [-- command...]"
    echo ""
    echo "Arguments:"
    echo "  target|cookbook  Docker build target OR cookbook name (default: standard)"
    echo "  tag             Image tag (default: auto-generated)"
    echo "  --              Separator before command arguments"
    echo "  command...      Optional command to run (if omitted, starts interactive shell)"
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
    echo "    claude-code-stage Claude Code editor tools"
    echo "    codex-stage       GitHub Codex tools"
    echo "    starship-stage    Starship prompt"
    echo "    ast-grep-stage    AST search tool"
    echo "    goose-stage       Database migration tool"
    echo "  Complete images:"
    echo "    standard          Production-ready container (default)"
    echo "    dev               Development container with all languages"
    echo ""
    echo "Available cookbooks:"
    echo "  go-microservices     Go microservices example"
    echo "  multistage-production Production multistage example"
    echo "  nodejs-backend       Node.js backend example"
    echo "  python-cli           Python CLI example"
    echo "  rails-fullstack      Rails fullstack example"
    echo "  react-frontend       React frontend example"
    echo ""
    echo "Examples:"
    echo "  $0                           # Build and shell into standard target"
    echo "  $0 dev                       # Build and shell into dev target"
    echo "  $0 python-stage              # Build and shell into Python stage only"
    echo "  $0 node-stage                # Build and shell into Node.js stage only"
    echo "  $0 python-cli                # Build and shell into python-cli cookbook"
    echo "  $0 standard my-test:latest   # Build standard with custom tag"
    echo "  $0 dev -- python --version   # Run a command in dev target"
    echo "  $0 python-cli -- mise list   # Run mise list in python-cli cookbook"
    echo "  $0 -- echo 'Hello World'     # Run command in default (standard) target"
    echo ""
    echo "This script:"
    echo "  1. Builds the specified target/cookbook"
    echo "  2. Runs the container with an interactive shell OR executes a command"
    echo "  3. Automatically cleans up the container on exit"
    exit 0
fi

# Parse arguments with -- separator support
TARGET_OR_COOKBOOK="standard"
TAG=""
COMMAND_ARGS=()

# Find the -- separator if it exists
DASH_DASH_INDEX=-1
for ((i=1; i<=$#; i++)); do
    if [[ "${!i}" == "--" ]]; then
        DASH_DASH_INDEX=$i
        break
    fi
done

if [[ $DASH_DASH_INDEX -gt 0 ]]; then
    # We found --, so everything before it are script args, everything after are command args
    if [[ $DASH_DASH_INDEX -gt 1 ]]; then
        TARGET_OR_COOKBOOK="${1:-standard}"
    fi
    if [[ $DASH_DASH_INDEX -gt 2 ]]; then
        TAG="${2:-}"
    fi
    
    # Capture command arguments (everything after --)
    shift $DASH_DASH_INDEX
    COMMAND_ARGS=("$@")
else
    # No -- found, use old behavior for backward compatibility
    TARGET_OR_COOKBOOK="${1:-standard}"
    TAG="${2:-}"
    
    # Capture command arguments (everything after the second argument)
    if [[ $# -gt 2 ]]; then
        shift 2
        COMMAND_ARGS=("$@")
    fi
fi

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

# Determine if this is a cookbook or a target
COOKBOOK_DIR="docs/cookbooks/$TARGET_OR_COOKBOOK"
IS_COOKBOOK=false

if [[ -d "$COOKBOOK_DIR" ]]; then
    IS_COOKBOOK=true
    # Auto-generate tag for cookbook if not provided
    if [[ -z "$TAG" ]]; then
        TAG="agentic-cookbook-${TARGET_OR_COOKBOOK}:local"
    fi
    DOCKERFILE_PATH="$COOKBOOK_DIR/Dockerfile"
    BUILD_CONTEXT="$COOKBOOK_DIR"
    echo "📚 Building cookbook: $TARGET_OR_COOKBOOK"
else
    # It's a target - validate it exists
    validate_target "$TARGET_OR_COOKBOOK"
    
    if [[ -z "$TAG" ]]; then
        TAG="agentic-container-${TARGET_OR_COOKBOOK}:local"
    fi
    DOCKERFILE_PATH="Dockerfile"
    BUILD_CONTEXT="."
    echo "🎯 Building target: $TARGET_OR_COOKBOOK"
fi

echo "🏷️  Tagging as: $TAG"
echo "📁 Build context: $BUILD_CONTEXT"
echo "🐳 Dockerfile: $DOCKERFILE_PATH"

# Check if gh is authenticated (needed for GitHub token)
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Error: GitHub CLI not authenticated. Run 'gh auth login' first."
    exit 1
fi

echo "🔐 Using GitHub token from gh auth (no disk storage)"

# Build the image
echo "🏗️  Building image..."
if [[ "$IS_COOKBOOK" == "true" ]]; then
    # For cookbooks, build from their directory
    docker build \
        --secret id=github_token,src=<(gh auth token) \
        -f "$DOCKERFILE_PATH" \
        -t "$TAG" \
        "$BUILD_CONTEXT"
else
    # For targets, build from root with target specification
    docker build \
        --target "$TARGET_OR_COOKBOOK" \
        --secret id=github_token,src=<(gh auth token) \
        -t "$TAG" \
        "$BUILD_CONTEXT"
fi

echo "✅ Build completed successfully!"

# Determine if we're running a command or starting an interactive shell
if [[ ${#COMMAND_ARGS[@]} -gt 0 ]]; then
    # Command mode
    echo "🚀 Running command in container..."
    echo "💡 Container will be automatically removed when command completes"
    echo "📦 Image: $TAG"
    if [[ "$IS_COOKBOOK" == "true" ]]; then
        echo "📚 Cookbook: $TARGET_OR_COOKBOOK"
    else
        echo "🎯 Target: $TARGET_OR_COOKBOOK"
    fi
    echo "⚡ Command: ${COMMAND_ARGS[*]}"
    echo ""
    
    docker run --rm \
        --name "agentic-command-$(date +%s)" \
        "$TAG" \
        /bin/bash -c "${COMMAND_ARGS[*]}"
else
    # Interactive mode
    echo "🚀 Starting container with interactive shell..."
    echo "💡 Container will be automatically removed when you exit the shell"
    echo ""

    # Use different shells based on what's likely available
    # Try fish first (since user prefers it), then bash, then sh
    docker run --rm -it \
        --name "agentic-shell-$(date +%s)" \
        "$TAG" \
        /bin/bash -c '
            echo "🎉 Welcome to your agentic container!"
            echo "📦 Image: '"$TAG"'"
            if [[ "'"$IS_COOKBOOK"'" == "true" ]]; then
                echo "📚 Cookbook: '"$TARGET_OR_COOKBOOK"'"
            else
                echo "🎯 Target: '"$TARGET_OR_COOKBOOK"'"
            fi
            echo ""
            echo "Available shells:"
            echo "  bash  - Default shell"
            if command -v fish >/dev/null 2>&1; then
                echo "  fish  - Friendly interactive shell (type '\''fish'\'' to switch)"
            fi
            if command -v zsh >/dev/null 2>&1; then
                echo "  zsh   - Z shell (type '\''zsh'\'' to switch)"
            fi
            echo ""
            echo "🔧 Useful commands:"
            echo "  mise list        - Show installed tools"
            echo "  mise current     - Show active tool versions"
            echo "  exit             - Leave container (will be auto-removed)"
            echo ""
            
            # Start interactive bash session
            exec /bin/bash
        '
fi

echo ""
echo "👋 Container session ended and cleaned up!"
