#!/usr/bin/env bash

# analyze-image-size.sh - Analyze Docker image size and efficiency using dive
# This script provides comprehensive image analysis for CI/CD pipelines

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default thresholds
DEFAULT_MIN_EFFICIENCY="0.85"
DEFAULT_MAX_WASTE_PERCENT="15"
DEFAULT_MAX_WASTE_MB="200"
DEFAULT_MAX_SIZE_INCREASE_PERCENT="10"
DEFAULT_MAX_SIZE_INCREASE_MB="100"

show_help() {
    cat << EOF
analyze-image-size.sh - Docker image size analysis with dive

USAGE:
    analyze-image-size.sh [OPTIONS] IMAGE [BASELINE_IMAGE]

DESCRIPTION:
    Analyzes Docker image size and efficiency using dive. Can compare against
    a baseline image to detect size regressions.

ARGUMENTS:
    IMAGE                   Docker image to analyze
    BASELINE_IMAGE          Optional baseline image for comparison

OPTIONS:
    --min-efficiency FLOAT      Minimum efficiency score (default: $DEFAULT_MIN_EFFICIENCY)
    --max-waste-percent INT     Maximum waste percentage (default: $DEFAULT_MAX_WASTE_PERCENT)
    --max-waste-mb INT          Maximum waste in MB (default: $DEFAULT_MAX_WASTE_MB)
    --max-increase-percent INT  Maximum size increase % (default: $DEFAULT_MAX_SIZE_INCREASE_PERCENT)
    --max-increase-mb INT       Maximum size increase MB (default: $DEFAULT_MAX_SIZE_INCREASE_MB)
    --output-dir DIR            Output directory for reports (default: ./reports)
    --format FORMAT             Output format: json, text, github (default: text)
    --ci                        Run in CI mode with strict thresholds
    --install-dive              Install dive if not available
    -h, --help                  Show this help message

EXAMPLES:
    # Analyze single image
    analyze-image-size.sh my-image:latest

    # Compare against baseline
    analyze-image-size.sh my-image:latest my-image:main

    # CI mode with strict thresholds
    analyze-image-size.sh --ci --format github my-image:latest baseline:latest

    # Custom thresholds
    analyze-image-size.sh \
        --min-efficiency 0.9 \
        --max-waste-percent 10 \
        my-image:latest

ENVIRONMENT VARIABLES:
    DIVE_VERSION               Version of dive to install (default: 0.12.0)

EOF
}

# Parse command line arguments
MIN_EFFICIENCY="$DEFAULT_MIN_EFFICIENCY"
MAX_WASTE_PERCENT="$DEFAULT_MAX_WASTE_PERCENT"
MAX_WASTE_MB="$DEFAULT_MAX_WASTE_MB"
MAX_SIZE_INCREASE_PERCENT="$DEFAULT_MAX_SIZE_INCREASE_PERCENT"
MAX_SIZE_INCREASE_MB="$DEFAULT_MAX_SIZE_INCREASE_MB"
OUTPUT_DIR="./reports"
FORMAT="text"
CI_MODE=false
INSTALL_DIVE=false
DIVE_VERSION="${DIVE_VERSION:-0.12.0}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --min-efficiency)
            MIN_EFFICIENCY="$2"
            shift 2
            ;;
        --max-waste-percent)
            MAX_WASTE_PERCENT="$2"
            shift 2
            ;;
        --max-waste-mb)
            MAX_WASTE_MB="$2"
            shift 2
            ;;
        --max-increase-percent)
            MAX_SIZE_INCREASE_PERCENT="$2"
            shift 2
            ;;
        --max-increase-mb)
            MAX_SIZE_INCREASE_MB="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --ci)
            CI_MODE=true
            # Stricter thresholds for CI
            MIN_EFFICIENCY="0.9"
            MAX_WASTE_PERCENT="10"
            MAX_WASTE_MB="100"
            shift
            ;;
        --install-dive)
            INSTALL_DIVE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "ERROR: Unknown option $1" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -lt 1 ]]; then
    echo "ERROR: IMAGE argument required" >&2
    echo "Run '$0 --help' for usage information." >&2
    exit 1
fi

IMAGE="$1"
BASELINE_IMAGE="${2:-}"

install_dive() {
    if command -v dive >/dev/null 2>&1; then
        echo "dive already installed: $(dive --version)"
        return 0
    fi

    echo "Installing dive v$DIVE_VERSION..."

    local os=""
    local arch=""

    case "$(uname -s)" in
        Linux*)  os="linux" ;;
        Darwin*) os="darwin" ;;
        *)       echo "ERROR: Unsupported OS $(uname -s)" >&2; exit 1 ;;
    esac

    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        arm64)  arch="arm64" ;;
        aarch64) arch="arm64" ;;
        *)      echo "ERROR: Unsupported architecture $(uname -m)" >&2; exit 1 ;;
    esac

    local download_url="https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_${os}_${arch}.tar.gz"
    local temp_dir=$(mktemp -d)

    echo "Downloading from: $download_url"
    curl -L "$download_url" | tar -xz -C "$temp_dir"

    if [[ "$os" == "darwin" ]]; then
        sudo mv "$temp_dir/dive" /usr/local/bin/
    else
        sudo mv "$temp_dir/dive" /usr/local/bin/
    fi

    rm -rf "$temp_dir"
    echo "dive installed successfully: $(dive --version)"
}

analyze_image() {
    local image="$1"
    local output_file="$2"

    echo "Analyzing image: $image"

    # Run dive analysis
    dive --json "$image" > "$output_file" 2>/dev/null

    if [[ ! -s "$output_file" ]]; then
        echo "ERROR: Failed to analyze image $image" >&2
        return 1
    fi

    echo "Analysis saved to: $output_file"
}

check_thresholds() {
    local analysis_file="$1"
    local image_name="$2"
    local exit_code=0

    echo "Checking thresholds for $image_name..."

    # Extract metrics from dive analysis
    local efficiency=$(jq -r '.image.efficiency // 0' "$analysis_file")
    local waste_bytes=$(jq -r '.image.userSizeBytesWasted // 0' "$analysis_file")
    local total_size=$(jq -r '.image.sizeBytes // 0' "$analysis_file")

    # Convert waste to MB and percentage
    local waste_mb=$((waste_bytes / 1024 / 1024))
    local waste_percent=$(echo "scale=2; $waste_bytes * 100 / $total_size" | bc -l)

    echo "  Efficiency: $(echo "scale=1; $efficiency * 100" | bc -l)%"
    echo "  Wasted space: ${waste_mb}MB ($(echo "scale=1; $waste_percent" | bc -l)%)"

    # Check efficiency threshold
    if (( $(echo "$efficiency < $MIN_EFFICIENCY" | bc -l) )); then
        echo "❌ Efficiency $(echo "scale=1; $efficiency * 100" | bc -l)% below minimum $MIN_EFFICIENCY"
        exit_code=1
    else
        echo "✅ Efficiency check passed"
    fi

    # Check waste percentage threshold
    if (( $(echo "$waste_percent > $MAX_WASTE_PERCENT" | bc -l) )); then
        echo "❌ Waste percentage $(echo "scale=1; $waste_percent" | bc -l)% exceeds maximum $MAX_WASTE_PERCENT%"
        exit_code=1
    else
        echo "✅ Waste percentage check passed"
    fi

    # Check absolute waste threshold
    if (( waste_mb > MAX_WASTE_MB )); then
        echo "❌ Waste ${waste_mb}MB exceeds maximum ${MAX_WASTE_MB}MB"
        exit_code=1
    else
        echo "✅ Absolute waste check passed"
    fi

    return $exit_code
}

compare_images() {
    local current_file="$1"
    local baseline_file="$2"
    local exit_code=0

    echo "Comparing against baseline..."

    local current_size=$(jq -r '.image.sizeBytes' "$current_file")
    local baseline_size=$(jq -r '.image.sizeBytes' "$baseline_file")

    local size_diff=$((current_size - baseline_size))
    local size_diff_mb=$((size_diff / 1024 / 1024))
    local size_diff_percent=$(echo "scale=1; $size_diff * 100 / $baseline_size" | bc -l)

    echo "  Current size: $((current_size / 1024 / 1024))MB"
    echo "  Baseline size: $((baseline_size / 1024 / 1024))MB"
    echo "  Size change: ${size_diff_mb}MB ($(echo "scale=1; $size_diff_percent" | bc -l)%)"

    # Check size increase thresholds
    if (( size_diff_mb > MAX_SIZE_INCREASE_MB )); then
        echo "❌ Size increase ${size_diff_mb}MB exceeds maximum ${MAX_SIZE_INCREASE_MB}MB"
        exit_code=1
    elif (( $(echo "$size_diff_percent > $MAX_SIZE_INCREASE_PERCENT" | bc -l) )); then
        echo "❌ Size increase $(echo "scale=1; $size_diff_percent" | bc -l)% exceeds maximum ${MAX_SIZE_INCREASE_PERCENT}%"
        exit_code=1
    else
        echo "✅ Size increase within acceptable limits"
    fi

    return $exit_code
}

generate_report() {
    local analysis_file="$1"
    local baseline_file="$2"
    local image_name="$3"

    case "$FORMAT" in
        json)
            generate_json_report "$analysis_file" "$baseline_file" "$image_name"
            ;;
        github)
            generate_github_report "$analysis_file" "$baseline_file" "$image_name"
            ;;
        text|*)
            generate_text_report "$analysis_file" "$baseline_file" "$image_name"
            ;;
    esac
}

generate_text_report() {
    local analysis_file="$1"
    local baseline_file="$2"
    local image_name="$3"

    echo ""
    echo "========================================"
    echo "Image Analysis Report: $image_name"
    echo "========================================"

    local total_size=$(jq -r '.image.sizeBytes' "$analysis_file")
    local efficiency=$(jq -r '.image.efficiency' "$analysis_file")
    local waste_bytes=$(jq -r '.image.userSizeBytesWasted' "$analysis_file")

    echo "Image Size: $((total_size / 1024 / 1024))MB"
    echo "Efficiency: $(echo "scale=1; $efficiency * 100" | bc -l)%"
    echo "Wasted Space: $((waste_bytes / 1024 / 1024))MB"

    if [[ -n "$baseline_file" && -f "$baseline_file" ]]; then
        echo ""
        echo "Comparison with Baseline:"
        local baseline_size=$(jq -r '.image.sizeBytes' "$baseline_file")
        local size_diff=$((total_size - baseline_size))
        echo "Size Change: $((size_diff / 1024 / 1024))MB"
    fi

    echo ""
    echo "Top 5 Largest Layers:"
    jq -r '.layers[] | "\(.size/1024/1024|floor)MB: \(.command)"' "$analysis_file" | \
        sort -nr | head -5 | nl
}

generate_github_report() {
    local analysis_file="$1"
    local baseline_file="$2"
    local image_name="$3"

    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        cat >> "$GITHUB_STEP_SUMMARY" << EOF
## 📊 Image Analysis: $image_name

| Metric | Value |
|--------|-------|
| Size | $(($(jq -r '.image.sizeBytes' "$analysis_file") / 1024 / 1024))MB |
| Efficiency | $(echo "scale=1; $(jq -r '.image.efficiency' "$analysis_file") * 100" | bc -l)% |
| Wasted Space | $(($(jq -r '.image.userSizeBytesWasted' "$analysis_file") / 1024 / 1024))MB |

EOF

        if [[ -n "$baseline_file" && -f "$baseline_file" ]]; then
            local current_size=$(jq -r '.image.sizeBytes' "$analysis_file")
            local baseline_size=$(jq -r '.image.sizeBytes' "$baseline_file")
            local size_diff=$((current_size - baseline_size))
            local emoji="🟢"

            if (( size_diff > 100*1024*1024 )); then emoji="🔴"
            elif (( size_diff > 10*1024*1024 )); then emoji="🟡"
            fi

            cat >> "$GITHUB_STEP_SUMMARY" << EOF
### Size Change from Baseline
$emoji **$((size_diff / 1024 / 1024))MB** change from baseline

EOF
        fi
    fi
}

generate_json_report() {
    local analysis_file="$1"
    local baseline_file="$2"
    local image_name="$3"

    local output_file="$OUTPUT_DIR/$(basename "$image_name" | tr ':' '-')-report.json"

    jq -n \
        --arg image "$image_name" \
        --arg timestamp "$(date -Iseconds)" \
        --argjson analysis "$(cat "$analysis_file")" \
        --argjson baseline "$(if [[ -n "$baseline_file" && -f "$baseline_file" ]]; then cat "$baseline_file"; else echo "null"; fi)" \
        '{
            image: $image,
            timestamp: $timestamp,
            analysis: $analysis,
            baseline: $baseline,
            summary: {
                size_mb: ($analysis.image.sizeBytes / 1024 / 1024 | floor),
                efficiency_percent: ($analysis.image.efficiency * 100 | floor),
                waste_mb: ($analysis.image.userSizeBytesWasted / 1024 / 1024 | floor),
                change_mb: (if $baseline != null then ($analysis.image.sizeBytes - $baseline.image.sizeBytes) / 1024 / 1024 | floor else null end)
            }
        }' > "$output_file"

    echo "JSON report saved to: $output_file"
}

main() {
    local exit_code=0

    # Install dive if requested
    if [[ "$INSTALL_DIVE" == true ]]; then
        install_dive
    fi

    # Check if dive is available
    if ! command -v dive >/dev/null 2>&1; then
        echo "ERROR: dive not found. Install it or use --install-dive" >&2
        exit 1
    fi

    # Check if bc is available for calculations
    if ! command -v bc >/dev/null 2>&1; then
        echo "ERROR: bc (calculator) not found. Please install it." >&2
        exit 1
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Analyze current image
    local analysis_file="$OUTPUT_DIR/$(basename "$IMAGE" | tr ':' '-')-analysis.json"
    analyze_image "$IMAGE" "$analysis_file" || exit 1

    # Check thresholds
    check_thresholds "$analysis_file" "$IMAGE" || exit_code=1

    # Compare with baseline if provided
    local baseline_analysis_file=""
    if [[ -n "$BASELINE_IMAGE" ]]; then
        baseline_analysis_file="$OUTPUT_DIR/$(basename "$BASELINE_IMAGE" | tr ':' '-')-baseline.json"

        if analyze_image "$BASELINE_IMAGE" "$baseline_analysis_file"; then
            compare_images "$analysis_file" "$baseline_analysis_file" || exit_code=1
        else
            echo "WARNING: Failed to analyze baseline image, skipping comparison"
            baseline_analysis_file=""
        fi
    fi

    # Generate report
    generate_report "$analysis_file" "$baseline_analysis_file" "$IMAGE"

    if [[ "$CI_MODE" == true && $exit_code -ne 0 ]]; then
        echo ""
        echo "❌ CI checks failed. Image does not meet quality thresholds."
        exit $exit_code
    elif [[ $exit_code -eq 0 ]]; then
        echo ""
        echo "✅ All checks passed!"
    fi

    exit $exit_code
}

main "$@"
