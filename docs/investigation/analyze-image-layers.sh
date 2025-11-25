#!/usr/bin/env bash
#
# analyze-image-layers.sh
#
# Purpose: Quick analysis of Docker image layers using dive
# Usage: ./analyze-image-layers.sh <image-name>
# Example: ./analyze-image-layers.sh agentic-container:standard
#
# This script generates a JSON analysis and extracts key metrics
# for identifying optimization opportunities.

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 <image-name>"
    echo "Example: $0 agentic-container:standard"
    exit 1
fi

IMAGE_NAME="$1"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
JSON_FILE="dive-analysis-${TIMESTAMP}.json"

echo "🔍 Analyzing image: $IMAGE_NAME"
echo "📄 Output file: $JSON_FILE"

# Generate dive analysis
dive --json "$JSON_FILE" "$IMAGE_NAME"

echo ""
echo "📊 === IMAGE ANALYSIS SUMMARY ==="
echo ""

# Total image size
echo "🏗️  Total Image Size:"
jq -r '.image.sizeBytes | . / 1024 / 1024 | floor | tostring + " MB"' "$JSON_FILE"

echo ""
echo "📦 Top 10 Largest Layers:"
echo "Size (MB) | Layer | Command"
echo "----------|-------|--------"
jq -r '.layer[] | "\(.sizeBytes),\(.index),\(.command)"' "$JSON_FILE" | \
    sort -nr | head -10 | \
    while IFS=, read -r size index command; do
        size_mb=$((size / 1024 / 1024))
        echo "${size_mb} MB | ${index} | ${command:0:60}..."
    done

echo ""
echo "🔍 Layers > 50MB File Analysis:"
jq '.layer[] | select(.sizeBytes > 50000000) | {index: .index, sizeBytes: .sizeBytes, command: .command, fileCount: (.fileList | length)}' "$JSON_FILE"

echo ""
echo "💾 Largest Files in Top Layers:"
for layer in 1 4 5; do
    echo ""
    echo "Layer $layer top files:"
    jq ".layer[$layer].fileList[] | select(.size > 1000000) | {path: .path, size: .size}" "$JSON_FILE" | \
        jq -s 'sort_by(.size) | reverse | .[0:5]' 2>/dev/null || echo "No large files or layer not found"
done

echo ""
echo "✨ Analysis complete! Check $JSON_FILE for full details"
echo "📋 Consider running: jq '.layer[N].fileList[] | select(.size > 1000000)' $JSON_FILE"
echo "   to explore specific layers in detail."
