#!/usr/bin/env bash

# test-extensions.sh - Validate that all extension examples work correctly
#
# This script builds and tests all the extension examples to ensure they work.
# It serves as both documentation validation and regression testing.
#
# Usage: ./test-extensions.sh [--cleanup]
#   --cleanup: Remove built images after testing (default: keep for inspection)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP=${1:-""}
FAILED_TESTS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to test an extension
test_extension() {
    local dockerfile=$1
    local image_name=$2
    local test_command=$3
    local description=$4
    
    log_info "Testing $description..."
    
    # Create a temporary dockerfile with local image references for testing
    local temp_dockerfile="$SCRIPT_DIR/temp-$(basename $dockerfile)"
    sed 's|ghcr.io/technicalpickles/agentic-container:|agentic-container:|g' "$dockerfile" > "$temp_dockerfile"
    
    # Build the image
    log_info "Building $image_name from $dockerfile (using local images)"
    if docker build -f "$temp_dockerfile" -t "$image_name" "$SCRIPT_DIR/../.."; then
        log_success "Build successful: $image_name"
        rm "$temp_dockerfile"
    else
        log_error "Build failed: $image_name"
        rm "$temp_dockerfile" 2>/dev/null || true
        FAILED_TESTS+=("$description - Build")
        return 1
    fi
    
    # Test the image
    log_info "Testing functionality: $image_name"
    if docker run --rm "$image_name" bash -c "$test_command"; then
        log_success "Test successful: $description"
    else
        log_error "Test failed: $description"
        FAILED_TESTS+=("$description - Runtime")
        return 1
    fi
    
    return 0
}

# Function to cleanup images
cleanup_images() {
    local images=("test-python-minimal" "test-nodejs-minimal" "test-fullstack-minimal" "test-multistage-app")
    
    if [[ "$CLEANUP" == "--cleanup" ]]; then
        log_info "Cleaning up test images..."
        for image in "${images[@]}"; do
            if docker image inspect "$image" >/dev/null 2>&1; then
                docker rmi "$image" >/dev/null 2>&1 && log_success "Removed $image" || log_warning "Failed to remove $image"
            fi
        done
    else
        log_info "Test images retained for inspection. Use --cleanup to remove them."
        docker images | grep -E "test-(python|nodejs|fullstack|multistage)" || true
    fi
}

main() {
    log_info "Starting extension example validation..."
    log_info "Working directory: $SCRIPT_DIR"
    
    # Ensure we're in the right directory
    cd "$SCRIPT_DIR"
    
    # Test 1: Python Extension
    test_extension \
        "extend-minimal-python.dockerfile" \
        "test-python-minimal" \
        'eval "$(mise activate bash)" && python3 --version && python3 -c "import sys; print(f\"Python {sys.version_info.major}.{sys.version_info.minor} working!\")"' \
        "Python Extension"
    
    # Test 2: Node.js Extension  
    test_extension \
        "extend-minimal-nodejs.dockerfile" \
        "test-nodejs-minimal" \
        'eval "$(mise activate bash)" && node --version && npm --version && node -e "console.log(\"Node.js working!\")"' \
        "Node.js Extension"
    
    # Test 3: Full-Stack Extension
    test_extension \
        "extend-minimal-fullstack.dockerfile" \
        "test-fullstack-minimal" \
        'eval "$(mise activate bash)" && cd /workspace/examples && python3 hello.py && node hello.js && go run hello.go' \
        "Full-Stack Extension"
    
    # Test 4: Multi-Stage Build (runtime test only)
    test_extension \
        "multistage-minimal-app.dockerfile" \
        "test-multistage-app" \
        'eval "$(mise activate bash)" && cd /app && python3 -c "import app; print(\"FastAPI app module loaded successfully\")"' \
        "Multi-Stage Build"
    
    # Cleanup
    cleanup_images
    
    # Summary
    echo
    log_info "=== Test Summary ==="
    if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
        log_success "All extension examples passed! 🎉"
        echo
        log_info "The following examples are ready for use:"
        echo "  • extend-minimal-python.dockerfile - Python development"  
        echo "  • extend-minimal-nodejs.dockerfile - Node.js development"
        echo "  • extend-minimal-fullstack.dockerfile - Multi-language development"
        echo "  • multistage-minimal-app.dockerfile - Production app deployment"
        echo
        exit 0
    else
        log_error "Some tests failed:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  ❌ $test"
        done
        echo
        exit 1
    fi
}

# Handle Ctrl+C
trap cleanup_images EXIT

main "$@"
