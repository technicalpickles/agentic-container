# Docker Image Investigation

This directory contains analysis and investigation reports for optimizing our Docker images.

## Files

- **`docker-layer-analysis.md`** - Comprehensive analysis of the `agentic-container:standard` image layers, identifying optimization opportunities
- **`analyze-image-layers.sh`** - Reusable script for analyzing any Docker image with `dive`

## Quick Analysis

To run a quick analysis on any image:

```bash
./analyze-image-layers.sh <image-name>
```

Example:
```bash
./analyze-image-layers.sh agentic-container:dev
./analyze-image-layers.sh agentic-container:python
```

## Key Findings Summary

From our September 2025 analysis of the `tools` target:

- **Total Size:** 898 MB
- **Optimization Potential:** 40-45% size reduction (~400MB savings)
- **Primary Opportunities:**
  1. Multi-stage builds for build vs runtime separation (200-300MB savings)
  2. Docker CLI optimization (75-150MB savings)  
  3. Mise installation cleanup (20MB savings)
  4. Selective package installation (50-100MB savings)

See `docker-layer-analysis.md` for detailed findings and implementation roadmap.
