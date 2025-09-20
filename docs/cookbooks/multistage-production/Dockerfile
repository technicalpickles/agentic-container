# Multi-Stage Build Pattern
# Demonstrates: multi-stage builds for optimized production images
FROM ghcr.io/technicalpickles/agentic-container:main AS builder

# Build stage - install build tools
USER root
RUN apt-get update && apt-get install -y --no-install-recommends build-essential && \
    rm -rf /var/lib/apt/lists/*
USER agent

# Install build dependencies
RUN pip install --no-cache-dir wheel setuptools

# Runtime stage - minimal dependencies only
FROM ghcr.io/technicalpickles/agentic-container:main AS runtime

# Install only runtime dependencies
RUN pip install --no-cache-dir requests

# No HEALTHCHECK - this container is designed for task execution, not service monitoring
WORKDIR /workspace
