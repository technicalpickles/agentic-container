#!/bin/bash
set -euo pipefail

# test-goss.sh - Run goss tests for cookbook examples
#
# This script demonstrates the self-contained approach where the container
# installs its own goss binary using mise, avoiding architecture compatibility issues.

IMAGE_NAME="${1:-test-extension-1758044393}"
GOSS_FILE="${2:-goss.yaml}"

echo "🧪 Testing container: $IMAGE_NAME"
echo "📝 Using goss config: $GOSS_FILE"

# Check if image exists
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "❌ Image '$IMAGE_NAME' not found. Build it first with test-extensions.sh"
    exit 1
fi

# Check if goss config exists
if [[ ! -f "$GOSS_FILE" ]]; then
    echo "❌ Goss config '$GOSS_FILE' not found"
    exit 1
fi

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
    
    echo "✅ All goss tests passed!"
    echo ""
    echo "🎉 Container validation successful!"
else
    echo "❌ Goss tests failed"
    exit 1
fi

echo ""
echo "✨ Test completed for $IMAGE_NAME"
