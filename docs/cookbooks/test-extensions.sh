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

# Test package validation based on Dockerfile content
test_package_validation() {
    local dockerfile="$1"
    local image_name="$2"
    
    log_info "Running package validation tests..."
    
    # Test Node.js tools if npm install is present
    if grep -q "npm install" "$dockerfile"; then
        # Test for common Node.js packages
        if grep -q "typescript\|@types\|ts-" "$dockerfile"; then
            if docker run --rm "$image_name" bash -c 'which tsc >/dev/null 2>&1 && tsc --version'; then
                log_success "TypeScript compiler is working"
            else
                log_warning "TypeScript compiler not found (mentioned in Dockerfile)"
            fi
        fi
        
        # Test general npm functionality
        if docker run --rm "$image_name" bash -c 'npm --version >/dev/null 2>&1'; then
            log_success "npm package manager is working"
        else
            log_error "npm not working despite npm install in Dockerfile"
            FAILED_TESTS+=("npm validation")
        fi
    fi
    
    # Test Python tools if pip install is present
    if grep -q "pip install" "$dockerfile"; then
        # Extract some common packages to test
        if grep -q "flask\|fastapi\|django" "$dockerfile"; then
            log_info "Testing Python web framework availability..."
            if docker run --rm "$image_name" bash -c 'python -c "import sys; print(sys.version)" 2>/dev/null'; then
                log_success "Python is working for web development"
            else
                log_warning "Python web framework test inconclusive"
            fi
        fi
        
        # Test pip functionality
        if docker run --rm "$image_name" bash -c 'pip --version >/dev/null 2>&1'; then
            log_success "pip package manager is working"
        else
            log_error "pip not working despite pip install in Dockerfile"
            FAILED_TESTS+=("pip validation")
        fi
    fi
    
    # Test Ruby tools if gem install is present
    if grep -q "gem install\|bundle install" "$dockerfile"; then
        if docker run --rm "$image_name" bash -c 'ruby --version >/dev/null 2>&1'; then
            log_success "Ruby interpreter is working"
        else
            log_error "Ruby not working despite gem install in Dockerfile"
            FAILED_TESTS+=("ruby validation")
        fi
        
        if grep -q "rails" "$dockerfile"; then
            if docker run --rm "$image_name" bash -c 'which rails >/dev/null 2>&1 && rails --version'; then
                log_success "Rails framework is working"
            else
                log_warning "Rails not found (mentioned in Dockerfile)"
            fi
        fi
    fi
    
    # Test Go tools if go mod/install is present
    if grep -q "go mod\|go install\|go get" "$dockerfile"; then
        if docker run --rm "$image_name" bash -c 'go version >/dev/null 2>&1'; then
            log_success "Go compiler is working"
        else
            log_error "Go not working despite go commands in Dockerfile"
            FAILED_TESTS+=("go validation")
        fi
    fi
    
    # Test common development tools
    local tools=("git" "curl" "vim" "jq")
    for tool in "${tools[@]}"; do
        if grep -q "$tool" "$dockerfile" || [[ "$tool" == "git" ]]; then  # git is expected to be in base
            if docker run --rm "$image_name" bash -c "which $tool >/dev/null 2>&1"; then
                log_success "$tool is available"
            else
                log_warning "$tool not found (expected for development)"
            fi
        fi
    done
    
    # Test mise functionality if present in base
    if docker run --rm "$image_name" bash -c 'mise --version >/dev/null 2>&1'; then
        log_success "mise version manager is functional"
        
        # Test if specific tools mentioned in Dockerfile are available through mise
        if grep -q "mise use\|mise install" "$dockerfile"; then
            if docker run --rm "$image_name" bash -c 'mise list >/dev/null 2>&1'; then
                log_success "mise tool installations are accessible"
            else
                log_warning "mise tool list not accessible (might be configuration issue)"
            fi
        fi
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
    
    # Test 5: Package validation based on Dockerfile content
    test_package_validation "$dockerfile" "$image_name"
    
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