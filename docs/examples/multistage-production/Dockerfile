# Multi-Stage Build Pattern
# Demonstrates: multi-stage builds for optimized production images
FROM ghcr.io/technicalpickles/agentic-container:latest AS builder

# Build stage - install build tools
USER root
RUN apt-get update && apt-get install -y build-essential && \
    rm -rf /var/lib/apt/lists/*
USER vscode

# Install build dependencies
RUN pip install --no-cache-dir wheel setuptools

# Runtime stage - minimal dependencies only
FROM ghcr.io/technicalpickles/agentic-container:latest AS runtime

# Install only runtime dependencies
RUN pip install --no-cache-dir requests

WORKDIR /workspace
