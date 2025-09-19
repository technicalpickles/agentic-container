#!/bin/bash
set -euo pipefail

# test-goss.sh - Run goss tests for cookbook examples
#
# This script demonstrates the self-contained approach where the container
# installs its own goss binary using mise, avoiding architecture compatibility issues.
#
# Usage:
#   ./test-goss.sh [IMAGE_NAME] [GOSS_FILE]
#   ./test-goss.sh                           # Auto-detect latest test image
#   ./test-goss.sh my-image                  # Use specific image
#   ./test-goss.sh my-image custom.yaml      # Use custom goss file

COOKBOOK_NAME="$(basename "$(pwd)")"
DEFAULT_GOSS_FILE="goss.yaml"

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
IMAGE_NAME="${1:-}"
GOSS_FILE="${2:-$DEFAULT_GOSS_FILE}"

# Auto-detect image if not provided
if [[ -z "$IMAGE_NAME" ]]; then
    echo "🔍 Auto-detecting latest test image..."
    if IMAGE_NAME=$(find_latest_test_image); then
        echo "📦 Found: $IMAGE_NAME"
    else
        echo "❌ No test images found matching pattern 'test-extension-*'"
        echo ""
        echo "💡 Build an image first:"
        echo "   cd /project/root"
        echo "   ./docs/cookbooks/test-extensions.sh docs/cookbooks/$COOKBOOK_NAME/Dockerfile"
        echo ""
        echo "   Then run: ./test-goss.sh"
        exit 1
    fi
fi

echo "🧪 Testing cookbook: $COOKBOOK_NAME"
echo "📦 Container image: $IMAGE_NAME"
echo "📝 Using goss config: $GOSS_FILE"

# Check if image exists
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "❌ Image '$IMAGE_NAME' not found."
    echo ""
    echo "💡 Build it first:"
    echo "   cd /project/root" 
    echo "   ./docs/cookbooks/test-extensions.sh docs/cookbooks/$COOKBOOK_NAME/Dockerfile"
    exit 1
fi

# Check if goss config exists
if [[ ! -f "$GOSS_FILE" ]]; then
    echo "❌ Goss config '$GOSS_FILE' not found in $(pwd)"
    echo ""
    echo "💡 Create one using the template:"
    echo "   cp ../templates/goss-template.yaml $GOSS_FILE"
    echo "   # Edit $GOSS_FILE to match your cookbook's requirements"
    exit 1
fi

echo ""
echo "⬇️  Installing goss in container and running tests..."

# Run the test in the container with embedded script
echo "🚀 Executing tests in container..."
if docker run --rm \
    --user root \
    -v "$(pwd)/$GOSS_FILE:/tmp/goss.yaml:ro" \
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
    echo "✅ All goss tests passed!"
    echo "🎉 Container validation successful for $COOKBOOK_NAME cookbook!"
else
    echo ""
    echo "❌ Goss tests failed for $COOKBOOK_NAME cookbook"
    echo ""
    echo "💡 Debug tips:"
    echo "   - Check goss.yaml syntax"
    echo "   - Verify expected packages are installed"
    echo "   - Review test output above for specific failures"
    exit 1
fi

echo ""
echo "✨ Test completed for $COOKBOOK_NAME cookbook"
echo "📊 Image: $IMAGE_NAME"
echo "📋 Config: $GOSS_FILE"