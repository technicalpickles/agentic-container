#!/bin/bash
set -euo pipefail

# test-goss.sh - Run goss tests for any cookbook example
#
# Usage:
#   ./test-goss.sh <cookbook-name> [image-name]
#   ./test-goss.sh python-cli                    # Auto-detect latest test image
#   ./test-goss.sh nodejs-backend my-image:tag   # Use specific image

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COOKBOOKS_DIR="$PROJECT_ROOT/docs/cookbooks"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

show_help() {
    cat << EOF
test-goss.sh - Run goss tests for cookbook examples

USAGE:
    ./test-goss.sh <cookbook-name> [image-name]

ARGUMENTS:
    cookbook-name    Name of cookbook to test (e.g., python-cli, nodejs-backend)
    image-name       Optional: specific image to test (auto-detects latest if omitted)

EXAMPLES:
    ./test-goss.sh python-cli                    # Auto-detect latest image
    ./test-goss.sh nodejs-backend                # Auto-detect latest image  
    ./test-goss.sh python-cli my-image:tag       # Test specific image

AVAILABLE COOKBOOKS:
EOF
    if [[ -d "$COOKBOOKS_DIR" ]]; then
        find "$COOKBOOKS_DIR" -maxdepth 1 -type d -not -name "_templates" -not -name "." \
            | grep -v "^$COOKBOOKS_DIR$" \
            | sed "s|$COOKBOOKS_DIR/||" \
            | sort \
            | sed 's/^/    - /'
    fi
    echo ""
}

# Function to find the most recent test image
find_latest_test_image() {
    local images
    images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^test-extension-" | head -1)
    if [[ -z "$images" ]]; then
        return 1
    fi
    echo "$images"
}

# Parse arguments
COOKBOOK_NAME="${1:-}"
IMAGE_NAME="${2:-}"

if [[ -z "$COOKBOOK_NAME" || "$COOKBOOK_NAME" == "--help" || "$COOKBOOK_NAME" == "-h" ]]; then
    show_help
    exit 0
fi

# Validate cookbook exists
COOKBOOK_DIR="$COOKBOOKS_DIR/$COOKBOOK_NAME"
GOSS_FILE="$COOKBOOK_DIR/goss.yaml"

if [[ ! -d "$COOKBOOK_DIR" ]]; then
    log_error "Cookbook '$COOKBOOK_NAME' not found in $COOKBOOKS_DIR"
    echo ""
    show_help
    exit 1
fi

if [[ ! -f "$GOSS_FILE" ]]; then
    log_error "No goss.yaml found at $GOSS_FILE"
    echo ""
    echo "💡 Create goss tests for this cookbook:"
    echo "   cp docs/cookbooks/_templates/goss-template.yaml $GOSS_FILE"
    echo "   # Edit $GOSS_FILE to match your cookbook's requirements"
    exit 1
fi

# Auto-detect image if not provided
if [[ -z "$IMAGE_NAME" ]]; then
    log_info "Auto-detecting latest test image..."
    if IMAGE_NAME=$(find_latest_test_image); then
        log_info "Found: $IMAGE_NAME"
    else
        log_error "No test images found matching pattern 'test-extension-*'"
        echo ""
        echo "💡 Build an image first:"
        echo "   ./docs/cookbooks/test-extensions.sh docs/cookbooks/$COOKBOOK_NAME/Dockerfile"
        exit 1
    fi
fi

# Verify image exists
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    log_error "Image '$IMAGE_NAME' not found"
    echo ""
    echo "💡 Build it first:"
    echo "   ./docs/cookbooks/test-extensions.sh docs/cookbooks/$COOKBOOK_NAME/Dockerfile"
    exit 1
fi

echo "🧪 Testing cookbook: $COOKBOOK_NAME"
echo "📦 Container image: $IMAGE_NAME"
echo "📝 Using goss config: $GOSS_FILE"
echo ""

# Run goss tests with container self-installation
log_info "Installing goss in container and running tests..."
if docker run --rm \
    --user root \
    -v "$GOSS_FILE:/tmp/goss.yaml:ro" \
    "$IMAGE_NAME" \
    bash -c '
        set -euo pipefail
        echo "📦 Installing goss using mise..."
        mise install goss@latest
        
        echo "🔧 Activating goss..."
        mise use -g goss@latest
        
        echo "📋 Running goss tests..."
        goss -g /tmp/goss.yaml validate --format documentation --color
    '; then
    
    echo ""
    log_success "All goss tests passed!"
    echo "🎉 Container validation successful for $COOKBOOK_NAME cookbook!"
else
    echo ""
    log_error "Goss tests failed for $COOKBOOK_NAME cookbook"
    echo ""
    echo "💡 Debug tips:"
    echo "   - Check goss.yaml syntax in $GOSS_FILE"
    echo "   - Verify expected packages are installed in the image"
    echo "   - Review test output above for specific failures"
    exit 1
fi

echo ""
echo "✨ Test completed for $COOKBOOK_NAME cookbook"
echo "📊 Image: $IMAGE_NAME"
echo "📋 Config: $GOSS_FILE"
