# Extension Example: Multi-Stage Build with Minimal Base
#
# This example demonstrates how to use agentic-container:minimal in a
# multi-stage build to create optimized application images. 
# 
# The pattern:
# 1. Build stage: Use minimal + build tools to compile/build application
# 2. Runtime stage: Use minimal + runtime dependencies for final image
#
# Build: docker build -f docs/examples/multistage-minimal-app.dockerfile -t my-app .
# Run:   docker run -it --rm my-app

# =============================================================================
# BUILD STAGE: Compile and build the application
# =============================================================================
FROM ghcr.io/technicalpickles/agentic-container:minimal AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install languages needed for building
RUN mise install python@3.13.7 node@24.8.0

# Set global versions
RUN mise use -g python@3.13.7 node@24.8.0

# Set working directory for build
WORKDIR /build

# Copy source code (in real scenario, this would be your app)
# For demo purposes, we'll create a simple Python web app
RUN bash -c 'eval "$(mise activate bash)" && \
    printf "%s\n" \
        "from fastapi import FastAPI" \
        "app = FastAPI()" \
        "" \
        "@app.get(\"/\")" \
        "def read_root():" \
        "    return {\"message\": \"Hello from minimal container!\"}" \
        "" \
        "@app.get(\"/health\")" \
        "def health():" \
        "    return {\"status\": \"healthy\"}" \
        > app.py && \
    printf "%s\n" \
        "fastapi==0.104.1" \
        "uvicorn[standard]==0.24.0" \
        > requirements.txt'

# Install Python dependencies
RUN bash -c 'eval "$(mise activate bash)" && pip install --no-cache-dir -r requirements.txt'

# Build/compile step (in real scenario, this might compile Go, build React app, etc.)
RUN bash -c 'eval "$(mise activate bash)" && \
    python -m py_compile app.py && \
    echo "Build completed successfully"'

# =============================================================================
# RUNTIME STAGE: Minimal runtime environment
# =============================================================================
FROM ghcr.io/technicalpickles/agentic-container:minimal AS runtime

# Install only runtime dependencies (no build tools)
RUN mise install python@3.13.7
RUN mise use -g python@3.13.7

# Copy built application from builder stage
COPY --from=builder /build/app.py /app/app.py
COPY --from=builder /build/requirements.txt /app/requirements.txt

# Install only runtime Python packages
RUN bash -c 'eval "$(mise activate bash)" && \
    cd /app && \
    pip install --no-cache-dir -r requirements.txt'

# Switch to non-root user for security
USER vscode

# Set working directory
WORKDIR /app

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD bash -c 'eval "$(mise activate bash)" && curl -f http://localhost:8000/health || exit 1'

# Expose port
EXPOSE 8000

# Run the application
CMD ["/bin/bash", "-c", "eval \"$(mise activate bash)\" && uvicorn app:app --host 0.0.0.0 --port 8000"]
