#!/usr/bin/env bash

# validate-ephemeral-tags.sh
#
# Purpose: Comprehensive local validation of ephemeral PR tags strategy
# Created: 2025-09-23
# Usage: ./scripts/validate-ephemeral-tags.sh
#
# This script validates the entire ephemeral PR tags flow locally before
# pushing changes to CI. It simulates the PR workflow by building a base
# image with ephemeral tag format, then testing all cookbook extensions
# against that tag.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHORT_SHA="$(git rev-parse --short HEAD)"
EPHEMERAL_TAG="ghcr.io/technicalpickles/agentic-container:pr-test-${SHORT_SHA}"
COOKBOOK_DIR="$PROJECT_ROOT/docs/cookbooks"

# Available cookbooks
COOKBOOKS=(
    "python-cli"
    "nodejs-backend"
    "go-microservices"
    "rails-fullstack"
    "react-frontend"
    "multistage-production"
)

# Timing variables
START_TIME=$(date +%s)
BUILD_TIMES=()
TEST_TIMES=()

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

cleanup_on_exit() {
    log_step "Cleanup on Exit"

    # Remove ephemeral base image
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$EPHEMERAL_TAG"; then
        log_info "Removing ephemeral base image: $EPHEMERAL_TAG"
        docker rmi "$EPHEMERAL_TAG" || log_warning "Failed to remove $EPHEMERAL_TAG"
    fi

    # Remove cookbook test images
    for cookbook in "${COOKBOOKS[@]}"; do
        local test_image="test-extension-${cookbook}:latest"
        if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$test_image"; then
            log_info "Removing test image: $test_image"
            docker rmi "$test_image" || log_warning "Failed to remove $test_image"
        fi
    done

    log_info "Cleanup completed"
}

# Set up cleanup on script exit
trap cleanup_on_exit EXIT

validate_prerequisites() {
    log_step "Validating Prerequisites"

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi

    # Check if goss test script exists
    if [[ ! -x "$PROJECT_ROOT/scripts/test-dockerfile.sh" ]]; then
        log_error "Goss test script not found or not executable: $PROJECT_ROOT/scripts/test-dockerfile.sh"
        exit 1
    fi

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi

    # Check if all cookbook Dockerfiles exist
    for cookbook in "${COOKBOOKS[@]}"; do
        local dockerfile="$COOKBOOK_DIR/$cookbook/Dockerfile"
        if [[ ! -f "$dockerfile" ]]; then
            log_error "Cookbook Dockerfile not found: $dockerfile"
            exit 1
        fi
    done

    log_success "All prerequisites validated"
}

build_ephemeral_base_image() {
    log_step "Building Ephemeral Base Image"

    local build_start=$(date +%s)

    log_info "Building base image with ephemeral tag: $EPHEMERAL_TAG"
    log_info "Using commit SHA: $SHORT_SHA"

    # Build the standard target with ephemeral tag
    if ! docker build \
        --target standard \
        --tag "$EPHEMERAL_TAG" \
        --secret id=github_token,env=GITHUB_TOKEN \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        "$PROJECT_ROOT"; then
        log_error "Failed to build ephemeral base image"
        exit 1
    fi

    local build_end=$(date +%s)
    local build_time=$((build_end - build_start))
    BUILD_TIMES+=("base:${build_time}")

    log_success "Ephemeral base image built successfully in ${build_time}s"

    # Verify the image exists and get basic info
    local image_size=$(docker images "$EPHEMERAL_TAG" --format "table {{.Size}}" | tail -n 1)
    log_info "Image size: $image_size"
}

test_cookbook_arg_support() {
    log_step "Testing Cookbook ARG Support"

    for cookbook in "${COOKBOOKS[@]}"; do
        local dockerfile="$COOKBOOK_DIR/$cookbook/Dockerfile"

        log_info "Checking $cookbook Dockerfile for ARG BASE_IMAGE support..."

        # Check if Dockerfile has ARG BASE_IMAGE
        if grep -q "ARG BASE_IMAGE" "$dockerfile"; then
            log_success "$cookbook: ARG BASE_IMAGE found"
        else
            log_warning "$cookbook: ARG BASE_IMAGE not found - needs to be added"

            # Show the current FROM line for reference
            local from_line=$(grep "^FROM" "$dockerfile" | head -n 1)
            log_info "$cookbook current FROM: $from_line"
        fi
    done
}

build_and_test_cookbooks() {
    log_step "Building and Testing Cookbook Extensions"

    local total_cookbooks=${#COOKBOOKS[@]}
    local successful_builds=0
    local successful_tests=0

    for cookbook in "${COOKBOOKS[@]}"; do
        log_info "Processing cookbook: $cookbook"

        local dockerfile="$COOKBOOK_DIR/$cookbook/Dockerfile"
        local test_image="test-extension-${cookbook}:latest"

        # Build cookbook with ephemeral base image
        local build_start=$(date +%s)

        log_info "Building $cookbook with ephemeral base image..."
        if docker build \
            -f "$dockerfile" \
            --build-arg "BASE_IMAGE=$EPHEMERAL_TAG" \
            -t "$test_image" \
            "$PROJECT_ROOT"; then

            local build_end=$(date +%s)
            local build_time=$((build_end - build_start))
            BUILD_TIMES+=("${cookbook}:${build_time}")

            log_success "$cookbook built successfully in ${build_time}s"
            ((successful_builds++))

            # Run goss tests
            local test_start=$(date +%s)

            log_info "Running goss tests for $cookbook..."
            if GITHUB_TOKEN="${GITHUB_TOKEN:-}" "$PROJECT_ROOT/scripts/test-dockerfile.sh" "$cookbook" "$test_image"; then
                local test_end=$(date +%s)
                local test_time=$((test_end - test_start))
                TEST_TIMES+=("${cookbook}:${test_time}")

                log_success "$cookbook tests passed in ${test_time}s"
                ((successful_tests++))
            else
                log_error "$cookbook tests failed"
            fi
        else
            log_error "Failed to build $cookbook"
        fi

        echo # Add spacing between cookbooks
    done

    # Summary
    log_step "Cookbook Testing Summary"
    log_info "Total cookbooks: $total_cookbooks"
    log_info "Successful builds: $successful_builds"
    log_info "Successful tests: $successful_tests"

    if [[ $successful_builds -eq $total_cookbooks ]] && [[ $successful_tests -eq $total_cookbooks ]]; then
        log_success "All cookbooks built and tested successfully!"
        return 0
    else
        log_error "Some cookbooks failed to build or test"
        return 1
    fi
}

test_default_behavior() {
    log_step "Testing Default Behavior (Backward Compatibility)"

    # Test that cookbooks still build without ARG override (using default)
    local test_cookbook="python-cli"  # Use python-cli as representative test
    local dockerfile="$COOKBOOK_DIR/$test_cookbook/Dockerfile"
    local test_image="test-default-${test_cookbook}:latest"

    log_info "Testing default behavior with $test_cookbook (no ARG override)..."

    if docker build \
        -f "$dockerfile" \
        -t "$test_image" \
        "$PROJECT_ROOT"; then
        log_success "Default behavior works - $test_cookbook built without ARG override"

        # Clean up test image
        docker rmi "$test_image" || log_warning "Failed to remove $test_image"
    else
        log_error "Default behavior failed - $test_cookbook could not build without ARG override"
        return 1
    fi
}

generate_performance_report() {
    log_step "Performance Report"

    local end_time=$(date +%s)
    local total_time=$((end_time - START_TIME))

    echo "Total validation time: ${total_time}s"
    echo
    echo "Build times:"
    for time_entry in "${BUILD_TIMES[@]}"; do
        echo "  $time_entry"
    done

    echo
    echo "Test times:"
    for time_entry in "${TEST_TIMES[@]}"; do
        echo "  $time_entry"
    done

    # Calculate totals
    local total_build_time=0
    local total_test_time=0

    for time_entry in "${BUILD_TIMES[@]}"; do
        local time_value="${time_entry#*:}"
        total_build_time=$((total_build_time + time_value))
    done

    for time_entry in "${TEST_TIMES[@]}"; do
        local time_value="${time_entry#*:}"
        total_test_time=$((total_test_time + time_value))
    done

    echo
    echo "Summary:"
    echo "  Total build time: ${total_build_time}s"
    echo "  Total test time: ${total_test_time}s"
    echo "  Overhead time: $((total_time - total_build_time - total_test_time))s"
}

main() {
    log_step "Ephemeral PR Tags Local Validation"
    log_info "Commit SHA: $SHORT_SHA"
    log_info "Ephemeral tag: $EPHEMERAL_TAG"
    log_info "Testing ${#COOKBOOKS[@]} cookbooks: ${COOKBOOKS[*]}"

    # Run validation steps
    validate_prerequisites
    build_ephemeral_base_image
    test_cookbook_arg_support
    test_default_behavior

    if build_and_test_cookbooks; then
        generate_performance_report

        log_step "Validation Complete"
        log_success "✅ All validation steps passed!"
        log_success "✅ Ephemeral PR tags strategy is ready for implementation"

        echo
        log_info "Next steps:"
        log_info "1. Update cookbook Dockerfiles with ARG BASE_IMAGE (if not already done)"
        log_info "2. Update workflow with ephemeral tag logic"
        log_info "3. Test on actual PR"

        return 0
    else
        log_step "Validation Failed"
        log_error "❌ Some validation steps failed"
        log_error "❌ Review errors above before proceeding with implementation"
        return 1
    fi
}

# Run main function
main "$@"
