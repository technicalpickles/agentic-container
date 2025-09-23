#!/usr/bin/env bash

test_base_target() {
    local target="$1" # standard | dev
    local image_name=""

    if [[ "$CI_MODE" == true ]]; then
        image_name="$TEST_IMAGE"
        log_info "Testing pre-built base image: $image_name"
        if ! docker image inspect "$image_name" >/dev/null 2>&1; then
            log_error "Pre-built image not found: $image_name"
            FAILED_TESTS+=("Image not found")
            return 1
        fi
    else
        image_name="test-${target}:latest"
        log_info "Building base target '$target' as $image_name"
        # Use gh token if available
        if [[ -n "${GITHUB_TOKEN:-}" ]] || (command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1); then
            token_file=$(mktemp)
            if [[ -n "${GITHUB_TOKEN:-}" ]]; then
                printf '%s' "$GITHUB_TOKEN" > "$token_file"
            else
                gh auth token > "$token_file"
            fi
            docker build --target "$target" -t "$image_name" --secret id=github_token,src="$token_file" "$PROJECT_ROOT" || {
                rm -f "$token_file"; log_error "Failed to build $target image"; return 1; }
            rm -f "$token_file"
        else
            docker build --target "$target" -t "$image_name" "$PROJECT_ROOT" || {
                log_error "Failed to build $target image"; return 1; }
        fi
        log_success "Build successful: $image_name"
    fi

    # Prepare goss files
    local base_common_file="$PROJECT_ROOT/goss/base-common.yaml"
    local base_standard_file="$PROJECT_ROOT/goss/standard.yaml"
    local base_dev_file="$PROJECT_ROOT/goss/dev.yaml"

    local docker_cmd="docker run --rm --user root"
    if [[ -f "$base_common_file" ]]; then
        docker_cmd="$docker_cmd -v \"$base_common_file:/tmp/goss-base-common.yaml:ro\""
    fi
    if [[ "$target" == "dev" ]]; then
        if [[ -f "$base_standard_file" ]]; then
            docker_cmd="$docker_cmd -v \"$base_standard_file:/tmp/goss-base-standard.yaml:ro\""
        fi
        if [[ -f "$base_dev_file" ]]; then
            docker_cmd="$docker_cmd -v \"$base_dev_file:/tmp/goss-base-dev.yaml:ro\""
        fi
    else
        if [[ -f "$base_standard_file" ]]; then
            docker_cmd="$docker_cmd -v \"$base_standard_file:/tmp/goss-base.yaml:ro\""
        fi
    fi

    # Add GITHUB_TOKEN if available
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        docker_cmd="$docker_cmd -e GITHUB_TOKEN"
    fi

    docker_cmd="$docker_cmd \"$image_name\" bash -c '"
    docker_cmd="$docker_cmd set -euo pipefail; "
    docker_cmd="$docker_cmd if ! command -v goss >/dev/null 2>&1; then mise use -g goss@latest || mise use -g goss@0.4.9; fi; "
    docker_cmd="$docker_cmd echo \"📋 Running goss tests for base target...\"; "
    if [[ "$target" == "dev" ]]; then
        docker_cmd="$docker_cmd goss -g /tmp/goss-base-common.yaml -g /tmp/goss-base-standard.yaml -g /tmp/goss-base-dev.yaml validate --format documentation --color"
    else
        docker_cmd="$docker_cmd goss -g /tmp/goss-base-common.yaml -g /tmp/goss-base.yaml validate --format documentation --color"
    fi
    docker_cmd="$docker_cmd '"

    if eval "$docker_cmd"; then
        log_success "Base goss tests passed for $target!"
    else
        log_error "Base goss tests failed for $target"
        FAILED_TESTS+=("goss validation ($target)")
        return 1
    fi
}

# test-dockerfile.sh - Build and validate Dockerfiles with comprehensive testing
#
# This script builds and validates any Dockerfile using comprehensive goss test 
# suites. All Dockerfiles must have a goss.yaml file in the same directory -
# the script will error if one is not found.
#
# Usage: 
#   ./test-dockerfile.sh <dockerfile-path> [--cleanup]
#   ./test-dockerfile.sh --help
#
# Arguments:
#   dockerfile-path: Path to your Dockerfile to test
#   --cleanup: Remove built images after testing (default: keep for inspection)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKERFILE=""
CLEANUP=""
FAILED_TESTS=()
MODE="cookbook" # cookbook | base
BASE_TARGET=""   # standard | dev

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    printf "%b\n" "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    printf "%b\n" "${GREEN}✅ $1${NC}"
}

log_warning() {
    printf "%b\n" "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    printf "%b\n" "${RED}❌ $1${NC}"
}

show_help() {
    cat << EOF
test-dockerfile.sh - Build and validate Dockerfiles with comprehensive testing

USAGE:
    ./test-dockerfile.sh <dockerfile-path> [--cleanup]
    ./test-dockerfile.sh standard [--cleanup]
    ./test-dockerfile.sh dev [--cleanup]
    ./test-dockerfile.sh standard test-standard:latest
    ./test-dockerfile.sh dev test-dev:latest
    ./test-dockerfile.sh --help

ARGUMENTS:
    dockerfile-path    Path to your Dockerfile to test
    standard|dev       Test base target (builds target image locally)
    test-*:latest      CI mode: use pre-built image name for base targets
    --cleanup          Remove built test images after testing

DESCRIPTION:
    This script builds and validates any Dockerfile using comprehensive goss 
    test suites. All Dockerfiles must have a goss.yaml file in the same 
    directory - the script will error if one is not found.

EXAMPLES:
    # Test a cookbook Dockerfile
    ./test-dockerfile.sh docs/cookbooks/python-cli/Dockerfile
    
    # Test custom Dockerfile and cleanup afterwards
    ./test-dockerfile.sh path/to/my-custom.dockerfile --cleanup
    
    # Create and test a Python Dockerfile
    cat > my-python-app.dockerfile << 'DOCKERFILE_EOF'
FROM ghcr.io/technicalpickles/agentic-container:latest
RUN pip install click typer rich pydantic pytest black ruff mypy && \\
    mise use -g python@3.13.7
RUN python3 --version && click --version
WORKDIR /workspace
DOCKERFILE_EOF
    ./test-dockerfile.sh my-python-app.dockerfile --cleanup
    rm my-python-app.dockerfile

TESTING APPROACH:
    • Builds the Docker image from your Dockerfile
    • Tests container startup and basic functionality
    • Requires goss.yaml file in same directory as Dockerfile
    • Runs comprehensive goss tests using pre-installed goss
    • Errors if no goss.yaml is found (no fallback validation)
    • Reports all test results with clear success/failure indicators

COOKBOOK EXAMPLES:
    The docs/cookbooks/ directory contains tested Dockerfile examples for:
    • Python CLI Applications - CLI tools, data processing, automation
    • Backend JavaScript/Node.js Services - APIs, microservices  
    • Full-Stack Rails Applications - Complete Ruby on Rails development
    • Go Microservices - Lightweight, fast services and API backends
    • React Frontend Applications - Modern web frontends with tooling
    
    Each cookbook includes both Dockerfile and goss.yaml for complete testing.

BASE TARGET EXAMPLES:
    # Local base target tests
    ./test-dockerfile.sh standard
    ./test-dockerfile.sh dev

    # CI mode with pre-built images
    ./test-dockerfile.sh standard test-standard:latest
    ./test-dockerfile.sh dev test-dev:latest

EOF
}

# Check if base image needs rebuilding and rebuild if necessary
ensure_base_image() {
    local base_dockerfile="$PROJECT_ROOT/Dockerfile"
    local base_image="agentic-container:latest"
    
    # Skip base image building in CI environment
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        log_info "Running in CI environment, skipping base image build"
        return 0
    fi
    
    # Check for GitHub token access (local development or CI)
    local has_gh_token=false
    local github_token_source=""
    
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        # GitHub Actions environment
        has_gh_token=true
        github_token_source="GITHUB_TOKEN environment variable"
    elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        # Local development with gh CLI
        has_gh_token=true
        github_token_source="gh auth token"
    fi
    
    # Check if base image exists
    if ! docker image inspect "$base_image" >/dev/null 2>&1; then
        log_info "Base image '$base_image' not found, building..."
        if [[ "$has_gh_token" == true ]]; then
            log_info "Using GitHub token via secret mounting to avoid API rate limits ($github_token_source)"
            token_file=$(mktemp)
            if [[ -n "${GITHUB_TOKEN:-}" ]]; then
                printf '%s' "$GITHUB_TOKEN" > "$token_file"
            else
                gh auth token > "$token_file"
            fi
            if docker build -f "$base_dockerfile" -t "$base_image" --secret id=github_token,src="$token_file" "$PROJECT_ROOT"; then
                rm -f "$token_file"
                log_success "Base image built successfully"
                # Tag as :main for local cookbook testing compatibility
                docker tag "$base_image" agentic-container:main >/dev/null 2>&1 || true
            else
                rm -f "$token_file"
                log_error "Failed to build base image"
                exit 1
            fi
        else
            log_warning "No GitHub token available, may hit API rate limits"
            if docker build -f "$base_dockerfile" -t "$base_image" "$PROJECT_ROOT"; then
                log_success "Base image built successfully"
                docker tag "$base_image" agentic-container:main >/dev/null 2>&1 || true
            else
                log_error "Failed to build base image"
                exit 1
            fi
        fi
        return
    fi
    
    # Check if Dockerfile is newer than the image
    local dockerfile_time=$(stat -c %Y "$base_dockerfile" 2>/dev/null || stat -f %m "$base_dockerfile" 2>/dev/null || echo 0)
    local image_time=$(docker image inspect "$base_image" --format '{{.Created}}' | xargs -I {} date -d {} +%s 2>/dev/null || docker image inspect "$base_image" --format '{{.Created}}' | xargs -I {} date -j -f '%Y-%m-%dT%H:%M:%S' {} +%s 2>/dev/null || echo 0)
    
    if [[ "$dockerfile_time" -gt "$image_time" ]]; then
        log_info "Base Dockerfile is newer than image, rebuilding..."
        if [[ "$has_gh_token" == true ]]; then
            log_info "Using GitHub token via secret mounting to avoid API rate limits ($github_token_source)"
            token_file=$(mktemp)
            if [[ -n "${GITHUB_TOKEN:-}" ]]; then
                printf '%s' "$GITHUB_TOKEN" > "$token_file"
            else
                gh auth token > "$token_file"
            fi
            if docker build -f "$base_dockerfile" -t "$base_image" --secret id=github_token,src="$token_file" "$PROJECT_ROOT"; then
                rm -f "$token_file"
                log_success "Base image rebuilt successfully"
                docker tag "$base_image" agentic-container:main >/dev/null 2>&1 || true
            else
                rm -f "$token_file"
                log_error "Failed to rebuild base image"
                exit 1
            fi
        else
            log_warning "No GitHub token available, may hit API rate limits"
            if docker build -f "$base_dockerfile" -t "$base_image" "$PROJECT_ROOT"; then
                log_success "Base image rebuilt successfully"
                docker tag "$base_image" agentic-container:main >/dev/null 2>&1 || true
            else
                log_error "Failed to rebuild base image"
                exit 1
            fi
        fi
    else
        log_info "Base image is up to date"
        # Ensure local alias tag for cookbook testing compatibility
        if ! docker image inspect agentic-container:main >/dev/null 2>&1; then
            docker tag "$base_image" agentic-container:main >/dev/null 2>&1 || true
        fi
    fi
}

# Parse arguments
parse_args() {
    if [[ $# -eq 0 ]] || [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    # Handle base target usage
    if [[ $# -ge 1 ]] && [[ "$1" == "standard" || "$1" == "dev" ]]; then
        MODE="base"
        BASE_TARGET="$1"
        if [[ $# -eq 2 ]] && [[ "$2" =~ ^test-(standard|dev):latest$ ]]; then
            TEST_IMAGE="$2"
            CI_MODE=true
            log_info "CI mode detected: testing base target '$BASE_TARGET' with image '$TEST_IMAGE'"
        else
            CLEANUP="${2:-}"
            CI_MODE=false
        fi
        return
    fi

    # Handle cookbook CI usage: ./test-dockerfile.sh cookbook-name test-extension-*:latest
    if [[ $# -eq 2 ]] && [[ ! -f "$1" ]] && [[ "$2" =~ ^test-extension-.*:latest$ ]]; then
        local cookbook_name="$1"
        local image_name="$2"
        DOCKERFILE="docs/cookbooks/$cookbook_name/Dockerfile"
        TEST_IMAGE="$image_name"
        CI_MODE=true
        log_info "CI mode detected: testing cookbook '$cookbook_name' with image '$image_name'"
        return
    fi

    # Local cookbook usage: ./test-dockerfile.sh dockerfile-path [--cleanup]
    DOCKERFILE="$1"
    CLEANUP="${2:-}"
    CI_MODE=false
    
    if [[ "$MODE" == "cookbook" && ! -f "$DOCKERFILE" ]]; then
        log_error "Dockerfile not found: $DOCKERFILE"
        echo
        show_help
        exit 1
    fi
    
    if [[ "$CI_MODE" == false ]] && [[ -n "$CLEANUP" ]] && [[ "$CLEANUP" != "--cleanup" ]]; then
        log_error "Invalid argument: $CLEANUP. Use --cleanup or omit."
        echo  
        show_help
        exit 1
    fi
}

# Run goss tests (required for all extensions)
test_comprehensive_validation() {
    local dockerfile="$1"
    local image_name="$2"
    
    # Determine cookbook name from dockerfile path
    local cookbook_name=""
    local dockerfile_dir=$(dirname "$dockerfile")
    local goss_file=""
    local base_target="standard"
    local base_common_file="$PROJECT_ROOT/goss/base-common.yaml"
    local base_standard_file="$PROJECT_ROOT/goss/standard.yaml"
    local base_dev_file="$PROJECT_ROOT/goss/dev.yaml"
    
    # Try to find corresponding goss.yaml file
    if [[ "$dockerfile" == *"/cookbooks/"* ]]; then
        cookbook_name=$(basename "$dockerfile_dir")
        goss_file="$dockerfile_dir/goss.yaml"
        # Best-effort detect base target from FROM reference
        if grep -Eiq 'agentic-container:.*dev' "$dockerfile"; then
            base_target="dev"
        fi
    fi
    
    # Use goss tests (required for all extensions)
    if [[ -n "$goss_file" && -f "$goss_file" ]]; then
        log_info "Running comprehensive goss tests for $cookbook_name..."
        local absolute_goss_file="$(cd "$(dirname "$goss_file")" && pwd)/$(basename "$goss_file")"
        # Prepare docker run command with GITHUB_TOKEN if available
        local docker_cmd="docker run --rm --user root -v \"$absolute_goss_file:/tmp/goss.yaml:ro\""

        # Mount base goss files if present
        if [[ -f "$base_common_file" ]]; then
            docker_cmd="$docker_cmd -v \"$base_common_file:/tmp/goss-base-common.yaml:ro\""
        fi
        if [[ "$base_target" == "dev" && -f "$base_dev_file" ]]; then
            # Mount both standard and dev to ensure dev inherits standard
            if [[ -f "$base_standard_file" ]]; then
                docker_cmd="$docker_cmd -v \"$base_standard_file:/tmp/goss-base-standard.yaml:ro\""
            fi
            docker_cmd="$docker_cmd -v \"$base_dev_file:/tmp/goss-base-dev.yaml:ro\""
            log_info "Including base tests: goss/base-common.yaml, goss/standard.yaml and goss/dev.yaml"
        elif [[ -f "$base_standard_file" ]]; then
            docker_cmd="$docker_cmd -v \"$base_standard_file:/tmp/goss-base.yaml:ro\""
            log_info "Including base tests: goss/base-common.yaml and goss/standard.yaml"
        else
            log_warning "Base goss files not found; running cookbook tests only"
        fi
        
        # Add GITHUB_TOKEN if available (for GitHub Actions or local development)
        if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            docker_cmd="$docker_cmd -e GITHUB_TOKEN"
        fi
        
        docker_cmd="$docker_cmd \"$image_name\" bash -c '"
        docker_cmd="$docker_cmd set -euo pipefail; "
        docker_cmd="$docker_cmd echo \"📦 Ensuring goss is available...\"; "
        docker_cmd="$docker_cmd if ! command -v goss >/dev/null 2>&1; then "
        docker_cmd="$docker_cmd mise use -g goss@latest || mise use -g goss@0.4.9; "
        docker_cmd="$docker_cmd fi; "
        docker_cmd="$docker_cmd echo \"📋 Running goss tests with pre-installed goss...\"; "
        # Run validation with multiple goss files if mounted
        docker_cmd="$docker_cmd if [ -f /tmp/goss-base-common.yaml ] && [ -f /tmp/goss-base-dev.yaml ] && [ -f /tmp/goss-base-standard.yaml ]; then "
        docker_cmd="$docker_cmd goss -g /tmp/goss-base-common.yaml -g /tmp/goss-base-standard.yaml -g /tmp/goss-base-dev.yaml -g /tmp/goss.yaml validate --format documentation --color; "
        docker_cmd="$docker_cmd elif [ -f /tmp/goss-base-common.yaml ] && [ -f /tmp/goss-base-dev.yaml ]; then "
        docker_cmd="$docker_cmd goss -g /tmp/goss-base-common.yaml -g /tmp/goss-base-dev.yaml -g /tmp/goss.yaml validate --format documentation --color; "
        docker_cmd="$docker_cmd elif [ -f /tmp/goss-base-common.yaml ] && [ -f /tmp/goss-base.yaml ]; then "
        docker_cmd="$docker_cmd goss -g /tmp/goss-base-common.yaml -g /tmp/goss-base.yaml -g /tmp/goss.yaml validate --format documentation --color; "
        docker_cmd="$docker_cmd elif [ -f /tmp/goss-base-common.yaml ]; then "
        docker_cmd="$docker_cmd goss -g /tmp/goss-base-common.yaml -g /tmp/goss.yaml validate --format documentation --color; "
        docker_cmd="$docker_cmd else "
        docker_cmd="$docker_cmd goss -g /tmp/goss.yaml validate --format documentation --color; "
        docker_cmd="$docker_cmd fi"
        docker_cmd="$docker_cmd '"
        
        if eval "$docker_cmd"; then
            log_success "All goss tests passed for $cookbook_name!"
        else
            log_error "Goss tests failed for $cookbook_name"
            FAILED_TESTS+=("goss validation")
        fi
    else
        # Error if no goss test is available
        log_error "No goss.yaml file found for comprehensive testing"
        echo ""
        echo "💡 All Dockerfiles must have goss.yaml tests. Options:"
        if [[ "$dockerfile" == *"/cookbooks/"* ]]; then
            echo "   - Add goss.yaml to the cookbook directory: $cookbook_name/"
            echo "   - Use template: cp docs/cookbooks/_templates/goss-template.yaml $dockerfile_dir/goss.yaml"
        else
            echo "   - Create goss.yaml in the same directory as your Dockerfile"
            echo "   - Use template: cp docs/cookbooks/_templates/goss-template.yaml \$(dirname \"$dockerfile\")/goss.yaml"
        fi
        echo "   - Edit the goss.yaml to match your Dockerfile's requirements"
        FAILED_TESTS+=("missing goss.yaml")
    fi
}

# Test a dockerfile
test_dockerfile() {
    local dockerfile="$1"
    local image_name=""
    
    if [[ "$CI_MODE" == true ]]; then
        # In CI mode, use the pre-built image
        image_name="$TEST_IMAGE"
        log_info "Testing pre-built image: $image_name"
        
        # Verify the image exists
        if ! docker image inspect "$image_name" >/dev/null 2>&1; then
            log_error "Pre-built image not found: $image_name"
            FAILED_TESTS+=("Image not found")
            return 1
        fi
    else
        # In local mode, build the image
        image_name="test-dockerfile-$(date +%s)"
        log_info "Testing dockerfile: $(basename "$dockerfile")"
        
        # Create a temporary dockerfile with local image references for testing
        local temp_dockerfile="$SCRIPT_DIR/temp-$(basename "$dockerfile")"
        sed 's|ghcr.io/technicalpickles/agentic-container:|agentic-container:|g' "$dockerfile" > "$temp_dockerfile"
        
        # Ensure local alias for base image used by cookbooks
        if ! docker image inspect agentic-container:main >/dev/null 2>&1; then
            docker tag agentic-container:latest agentic-container:main >/dev/null 2>&1 || true
        fi

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
    fi
    
    # Basic startup test
    log_info "Testing basic functionality..."
    
    # Test 1: Container starts and basic commands work
    if docker run --rm "$image_name" bash -c 'echo "Container startup test passed"'; then
        log_success "Container startup test passed"
    else
        log_error "Container startup test failed"
        FAILED_TESTS+=("Startup test")
    fi
    
    # Test 2: Working directory is accessible
    if docker run --rm "$image_name" bash -c 'cd /workspace && pwd'; then
        log_success "Working directory is accessible"
    else
        log_error "Working directory test failed"
        FAILED_TESTS+=("Working directory")
    fi
    
    # Test 3: Comprehensive validation (goss tests required)
    test_comprehensive_validation "$dockerfile" "$image_name"
    
    # Cleanup test image (only in local mode)
    if [[ "$CI_MODE" == false ]]; then
        if [[ "$CLEANUP" == "--cleanup" ]]; then
            if docker rmi "$image_name" >/dev/null 2>&1; then
                log_success "Cleaned up test image"
            else
                log_warning "Failed to cleanup test image: $image_name"
            fi
        else
            log_info "Test image retained: $image_name (use --cleanup to remove)"
        fi
    else
        log_info "CI mode: test image cleanup handled by CI workflow"
    fi
    
    return 0
}

main() {
    parse_args "$@"
    
    log_info "Starting dockerfile validation..."
    if [[ "$MODE" == "base" ]]; then
        log_info "Testing base target: $BASE_TARGET"
        test_base_target "$BASE_TARGET"
    else
        log_info "Testing Dockerfile: $DOCKERFILE"
        # Ensure base image is up to date
        ensure_base_image
        # Test the dockerfile
        test_dockerfile "$DOCKERFILE"
    fi
    
    # Summary
    echo
    log_info "=== Test Summary ==="
    if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
        log_success "Dockerfile validation passed! 🎉"
        echo
        log_info "Your Dockerfile appears to be working correctly."
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