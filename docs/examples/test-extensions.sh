#!/usr/bin/env bash

# test-extensions.sh - Validate custom extension Dockerfiles
#
# This script helps test your custom extension Dockerfiles based on the
# inline examples from the main README.md. It builds and validates that
# the extension works correctly.
#
# Usage: 
#   ./test-extensions.sh <dockerfile-path> [--cleanup]
#   ./test-extensions.sh --help
#
# Arguments:
#   dockerfile-path: Path to your custom Dockerfile to test
#   --cleanup: Remove built images after testing (default: keep for inspection)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../.."
DOCKERFILE=""
CLEANUP=""
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

show_help() {
    cat << EOF
test-extensions.sh - Test custom agentic-container extensions

USAGE:
    ./test-extensions.sh <dockerfile-path> [--cleanup]
    ./test-extensions.sh --help

ARGUMENTS:
    dockerfile-path    Path to your custom Dockerfile to test
    --cleanup         Remove built test images after testing

EXAMPLES:
    # Test a Python extension Dockerfile
    ./test-extensions.sh my-python-extension.dockerfile
    
    # Test and cleanup afterwards
    ./test-extensions.sh my-extension.dockerfile --cleanup
    
    # Create and test a Python extension from main README examples
    cat > my-python-extension.dockerfile << 'EOF'
FROM ghcr.io/technicalpickles/agentic-container:latest
RUN pip install click typer rich pydantic pytest black ruff mypy && \\
    mise use -g python@3.13.7
RUN python3 --version && click --version
WORKDIR /workspace
EOF
    ./test-extensions.sh my-python-extension.dockerfile --cleanup
    rm my-python-extension.dockerfile

TECHNOLOGY STACK EXAMPLES:
    The main README.md contains inline extension examples for:
    • Python CLI Applications - CLI tools, data processing, automation
    • Backend JavaScript/Node.js Services - APIs, microservices  
    • Full-Stack Rails Applications - Complete Ruby on Rails development
    • Go Microservices - Lightweight, fast services and API backends
    • React Frontend Applications - Modern web frontends with tooling
    
    Copy examples from: ../README.md#extending-for-different-technology-stacks

EOF
}

# Parse arguments
parse_args() {
    if [[ $# -eq 0 ]] || [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    DOCKERFILE="$1"
    CLEANUP="${2:-}"
    
    if [[ ! -f "$DOCKERFILE" ]]; then
        log_error "Dockerfile not found: $DOCKERFILE"
        echo
        show_help
        exit 1
    fi
    
    if [[ -n "$CLEANUP" ]] && [[ "$CLEANUP" != "--cleanup" ]]; then
        log_error "Invalid argument: $CLEANUP. Use --cleanup or omit."
        echo  
        show_help
        exit 1
    fi
}

# Test an extension dockerfile
test_extension() {
    local dockerfile="$1"
    local image_name="test-extension-$(date +%s)"
    
    log_info "Testing extension: $(basename "$dockerfile")"
    
    # Create a temporary dockerfile with local image references for testing
    local temp_dockerfile="$SCRIPT_DIR/temp-$(basename "$dockerfile")"
    sed 's|ghcr.io/technicalpickles/agentic-container:|agentic-container:|g' "$dockerfile" > "$temp_dockerfile"
    
    # Build the image
    log_info "Building test image: $image_name"
    if docker build -f "$temp_dockerfile" -t "$image_name" "$PROJECT_ROOT"; then
        log_success "Build successful: $image_name"
        rm "$temp_dockerfile"
    else
        log_error "Build failed for: $(basename "$dockerfile")"
        rm "$temp_dockerfile" 2>/dev/null || true
        FAILED_TESTS+=("Build failed")
        return 1
    fi
    
    # Basic functionality tests
    log_info "Testing basic functionality..."
    
    # Test 1: Container starts and basic commands work
    if docker run --rm "$image_name" bash -c 'echo "Container startup test passed"'; then
        log_success "Container startup test passed"
    else
        log_error "Container startup test failed"
        FAILED_TESTS+=("Startup test")
    fi
    
    # Test 2: Mise is working
    if docker run --rm "$image_name" bash -c 'mise --version >/dev/null 2>&1 && echo "mise working"'; then
        log_success "mise version manager is working"
    else
        log_warning "mise test failed (might be expected for some extensions)"
    fi
    
    # Test 3: Working directory is accessible
    if docker run --rm "$image_name" bash -c 'cd /workspace && pwd'; then
        log_success "Working directory is accessible"
    else
        log_error "Working directory test failed"
        FAILED_TESTS+=("Working directory")
    fi
    
    # Test 4: User permissions are correct
    if docker run --rm "$image_name" bash -c 'whoami | grep -v "^root$" && echo "Running as non-root user"'; then
        log_success "Running as non-root user"
    else
        log_warning "Running as root user (might not be ideal for security)"
    fi
    
    # Cleanup test image
    if [[ "$CLEANUP" == "--cleanup" ]]; then
        if docker rmi "$image_name" >/dev/null 2>&1; then
            log_success "Cleaned up test image"
        else
            log_warning "Failed to cleanup test image: $image_name"
        fi
    else
        log_info "Test image retained: $image_name (use --cleanup to remove)"
    fi
    
    return 0
}

main() {
    parse_args "$@"
    
    log_info "Starting extension validation..."
    log_info "Testing Dockerfile: $DOCKERFILE"
    
    # Check if base image exists locally
    if ! docker image inspect agentic-container:latest >/dev/null 2>&1; then
        log_warning "Base image 'agentic-container:latest' not found locally."
        log_info "The test will use 'ghcr.io/technicalpickles/agentic-container:latest' from registry."
    fi
    
    # Test the extension
    test_extension "$DOCKERFILE"
    
    # Summary
    echo
    log_info "=== Test Summary ==="
    if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
        log_success "Extension validation passed! 🎉"
        echo
        log_info "Your extension Dockerfile appears to be working correctly."
        echo
    else
        log_error "Some tests failed:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  ❌ $test"
        done
        echo
        log_info "Review the Dockerfile and try again."
        exit 1
    fi
}

main "$@"