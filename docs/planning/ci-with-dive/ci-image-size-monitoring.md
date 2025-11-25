# CI Image Size Monitoring with Dive

**Created**: 2025-01-15 **Status**: Planning **Scope**: Using dive to monitor
and control image size changes in CI/CD

## Overview

This document outlines strategies for using `dive` and other tools to monitor
image size changes over time, prevent regressions, and maintain visibility into
layer efficiency within our CI/CD pipeline.

## What is Dive?

`dive` is a tool for exploring Docker images layer by layer:

- **Layer Analysis**: Shows size and efficiency of each layer
- **Wasted Space Detection**: Identifies files added then removed
- **Image Efficiency Score**: Provides overall efficiency metrics
- **CI Integration**: Can be automated with exit codes and JSON output

## Integration Strategies

### Strategy 1: Size Regression Prevention

Block builds that significantly increase image size without justification.

```yaml
# In GitHub Actions workflow
- name: Analyze image size with dive
  run: |
    # Install dive
    curl -OL https://github.com/wagoodman/dive/releases/download/v0.12.0/dive_0.12.0_linux_amd64.tar.gz
    tar -xzf dive_0.12.0_linux_amd64.tar.gz
    sudo mv dive /usr/local/bin/

    # Analyze current build
    dive --ci ghcr.io/${{ github.repository }}:${{ github.sha }}-base \
      --highestUserWastedPercent=10 \
      --highestWasted=100MB \
      --lowestEfficiency=0.9
```

### Strategy 2: Historical Size Tracking

Track size changes over time and generate reports.

```yaml
- name: Generate size report
  run: |
    # Get current image size
    CURRENT_SIZE=$(docker images --format "table {{.Size}}" ghcr.io/${{ github.repository }}:${{ github.sha }}-base | tail -n 1)

    # Compare with previous build
    docker pull ghcr.io/${{ github.repository }}:main-base || true
    PREVIOUS_SIZE=$(docker images --format "table {{.Size}}" ghcr.io/${{ github.repository }}:main-base | tail -n 1)

    # Generate comparison report
    dive --ci --json ghcr.io/${{ github.repository }}:${{ github.sha }}-base > current_analysis.json
    dive --ci --json ghcr.io/${{ github.repository }}:main-base > previous_analysis.json || echo "{}" > previous_analysis.json

    # Process results
    python scripts/size-analysis.py current_analysis.json previous_analysis.json
```

### Strategy 3: Multi-Image Monitoring

Monitor all image variants simultaneously.

```yaml
strategy:
  matrix:
    target: [minimal, standard, python, node, ruby, go, dev]

steps:
  - name: Size analysis for ${{ matrix.target }}
    run: |
      IMAGE_NAME="ghcr.io/${{ github.repository }}:${{ github.sha }}-${{ matrix.target }}"

      # Analyze with dive
      dive --ci --json "$IMAGE_NAME" > "analysis-${{ matrix.target }}.json"

      # Upload results as artifacts
  - name: Upload size analysis
    uses: actions/upload-artifact@v4
    with:
      name: size-analysis-${{ matrix.target }}
      path: analysis-${{ matrix.target }}.json
```

### Strategy 4: Efficiency Scoring

Set minimum efficiency thresholds for images.

```yaml
- name: Efficiency check
  run: |
    for target in minimal standard python node ruby go dev; do
      IMAGE="ghcr.io/${{ github.repository }}:${{ github.sha }}-$target"
      echo "Analyzing $target..."

      # Fail if efficiency below threshold
      dive --ci "$IMAGE" \
        --lowestEfficiency=0.85 \
        --highestUserWastedPercent=15 \
        --highestWasted=200MB

      if [ $? -ne 0 ]; then
        echo "::error::$target image failed efficiency check"
        exit 1
      fi
    done
```

## Implementation Options

### Option 1: Basic Size Monitoring

**Pros**: Simple, quick feedback **Cons**: Limited insights

```yaml
jobs:
  size-check:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Check image sizes
        run: |
          echo "## Image Size Report" >> $GITHUB_STEP_SUMMARY
          echo "| Image | Size |" >> $GITHUB_STEP_SUMMARY
          echo "|-------|------|" >> $GITHUB_STEP_SUMMARY

          for tag in base tools python node ruby go dev; do
            size=$(docker inspect ghcr.io/${{ github.repository }}:${{ github.sha }}-$tag | jq '.[0].Size')
            size_mb=$((size / 1024 / 1024))
            echo "| $tag | ${size_mb}MB |" >> $GITHUB_STEP_SUMMARY
          done
```

### Option 2: Comprehensive Analysis with Dive

**Pros**: Detailed insights, layer analysis **Cons**: More complex setup

```yaml
jobs:
  image-analysis:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Install dive
        run: |
          DIVE_VERSION=0.12.0
          curl -OL "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_amd64.tar.gz"
          tar -xzf "dive_${DIVE_VERSION}_linux_amd64.tar.gz"
          sudo mv dive /usr/local/bin/

      - name: Analyze images
        run: |
          mkdir -p reports

          for target in minimal standard python node ruby go dev; do
            image="ghcr.io/${{ github.repository }}:${{ github.sha }}-$target"

            # Generate detailed analysis
            dive --json "$image" > "reports/${target}-analysis.json"

            # Run CI checks
            dive --ci "$image" \
              --lowestEfficiency=0.8 \
              --highestUserWastedPercent=20 \
              --json > "reports/${target}-ci.json"
          done

      - name: Upload reports
        uses: actions/upload-artifact@v4
        with:
          name: dive-reports
          path: reports/
```

### Option 3: Historical Tracking with Database

**Pros**: Long-term trends, regression analysis **Cons**: Requires external
storage

```yaml
- name: Track size history
  run: |
    # Create size tracking data
    cat > size_data.json << EOF
    {
      "commit": "${{ github.sha }}",
      "branch": "${{ github.ref_name }}",
      "timestamp": "$(date -Iseconds)",
      "images": {
    EOF

    first=true
    for target in minimal standard python node ruby go dev; do
      if [ "$first" = false ]; then echo "," >> size_data.json; fi
      first=false

      image="ghcr.io/${{ github.repository }}:${{ github.sha }}-$target"
      analysis=$(dive --json "$image")
      size=$(echo "$analysis" | jq '.image.sizeBytes')
      efficiency=$(echo "$analysis" | jq '.image.efficiency')
      waste=$(echo "$analysis" | jq '.image.userSizeBytesWasted')

      cat >> size_data.json << EOF
        "$target": {
          "size": $size,
          "efficiency": $efficiency,
          "waste": $waste
        }
    EOF
    done

    echo "}}" >> size_data.json

    # Store in GitHub Gist or external database
    curl -X POST \
      -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/gists \
      -d @- << EOF
    {
      "description": "Image size tracking for ${{ github.sha }}",
      "public": false,
      "files": {
        "size-data.json": {
          "content": $(cat size_data.json | jq -Rs .)
        }
      }
    }
    EOF
```

## Alerting and Thresholds

### Size Increase Thresholds

```yaml
# Environment variables for thresholds
env:
  MAX_SIZE_INCREASE_PERCENT: 10    # Fail if >10% increase
  MAX_SIZE_INCREASE_MB: 100        # Fail if >100MB increase
  MIN_EFFICIENCY: 0.85             # Minimum efficiency score
  MAX_WASTE_PERCENT: 15            # Maximum wasted space percentage

- name: Size regression check
  run: |
    python scripts/check-size-regression.py \
      --current-analysis current_analysis.json \
      --previous-analysis previous_analysis.json \
      --max-increase-percent $MAX_SIZE_INCREASE_PERCENT \
      --max-increase-mb $MAX_SIZE_INCREASE_MB
```

### Pull Request Comments

```yaml
- name: Comment on PR with size analysis
  uses: actions/github-script@v6
  if: github.event_name == 'pull_request'
  with:
    script: |
      const fs = require('fs');
      const analysis = JSON.parse(fs.readFileSync('size_analysis.json', 'utf8'));

      let comment = '## 📊 Image Size Analysis\n\n';
      comment += '| Image | Current Size | Previous Size | Change |\n';
      comment += '|-------|-------------|--------------|--------|\n';

      for (const [image, data] of Object.entries(analysis.images)) {
        const change = data.sizeChange > 0 ? `+${data.sizeChange}MB` : `${data.sizeChange}MB`;
        const emoji = data.sizeChange > 50 ? '🔴' : data.sizeChange > 10 ? '🟡' : '🟢';
        comment += `| ${image} | ${data.currentSize}MB | ${data.previousSize}MB | ${emoji} ${change} |\n`;
      }

      comment += '\n### Efficiency Scores\n\n';
      for (const [image, data] of Object.entries(analysis.images)) {
        comment += `- **${image}**: ${(data.efficiency * 100).toFixed(1)}% efficient, ${data.wastedSpace}MB wasted\n`;
      }

      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: comment
      });
```

## Metrics and Monitoring

### Key Metrics to Track

1. **Absolute Size**: Total image size in MB/GB
2. **Size Change**: Difference from previous build
3. **Efficiency Score**: Dive's efficiency calculation
4. **Wasted Space**: Files added then removed
5. **Layer Count**: Number of layers in image
6. **Largest Layers**: Top 5 layers by size

### Dashboard Integration

```yaml
- name: Send metrics to monitoring
  run: |
    # Send to DataDog, Grafana, or similar
    for target in minimal standard python node ruby go dev; do
      analysis=$(cat "reports/${target}-analysis.json")
      size=$(echo "$analysis" | jq '.image.sizeBytes')
      efficiency=$(echo "$analysis" | jq '.image.efficiency')

      curl -X POST https://api.datadoghq.com/api/v1/series \
        -H "Content-Type: application/json" \
        -H "DD-API-KEY: ${{ secrets.DATADOG_API_KEY }}" \
        -d "{
          \"series\": [{
            \"metric\": \"docker.image.size\",
            \"points\": [[$(date +%s), $size]],
            \"tags\": [\"image:$target\", \"repo:agentic-container\"]
          }]
        }"
    done
```

## Helper Scripts

### size-analysis.py

```python
#!/usr/bin/env python3
import json
import sys
import argparse

def analyze_size_changes(current_file, previous_file, thresholds):
    with open(current_file) as f:
        current = json.load(f)

    try:
        with open(previous_file) as f:
            previous = json.load(f)
    except FileNotFoundError:
        print("No previous analysis found, skipping comparison")
        return 0

    current_size = current['image']['sizeBytes']
    previous_size = previous['image']['sizeBytes']

    size_change = current_size - previous_size
    size_change_percent = (size_change / previous_size) * 100

    print(f"Size change: {size_change:,} bytes ({size_change_percent:.1f}%)")

    if size_change_percent > thresholds['max_increase_percent']:
        print(f"❌ Size increase {size_change_percent:.1f}% exceeds threshold {thresholds['max_increase_percent']}%")
        return 1

    if size_change > thresholds['max_increase_mb'] * 1024 * 1024:
        print(f"❌ Size increase {size_change//1024//1024}MB exceeds threshold {thresholds['max_increase_mb']}MB")
        return 1

    print("✅ Size change within acceptable limits")
    return 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--current-analysis", required=True)
    parser.add_argument("--previous-analysis", required=True)
    parser.add_argument("--max-increase-percent", type=int, default=10)
    parser.add_argument("--max-increase-mb", type=int, default=100)

    args = parser.parse_args()

    thresholds = {
        'max_increase_percent': args.max_increase_percent,
        'max_increase_mb': args.max_increase_mb
    }

    sys.exit(analyze_size_changes(args.current_analysis, args.previous_analysis, thresholds))
```

## Recommended Implementation

### Phase 1: Basic Integration

1. Add dive to GitHub Actions workflow
2. Set basic size and efficiency thresholds
3. Generate simple reports

### Phase 2: Enhanced Monitoring

1. Add historical tracking
2. Implement PR comments with size analysis
3. Create size regression alerts

### Phase 3: Advanced Analytics

1. Dashboard integration
2. Trend analysis
3. Automated optimization suggestions

### Immediate Next Steps

1. **Add dive to existing workflow**
2. **Set initial thresholds** (conservative at first)
3. **Test with current images** to establish baselines
4. **Create helper scripts** for analysis
5. **Document workflow** for contributors

This approach will give you excellent visibility into image size changes and
help prevent regressions while you implement the optimization strategy outlined
in the previous planning document.

Would you like me to start implementing any of these approaches in your current
workflow?
