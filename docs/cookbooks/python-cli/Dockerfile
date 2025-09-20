# Python Development Extension
# Demonstrates: pip package manager usage
FROM ghcr.io/technicalpickles/agentic-container:main

# Python already available - add packages via pip
RUN pip install --no-cache-dir \
    click \
    typer \
    rich \
    pydantic

# Ensure we run as non-root user for security
USER agent

# No HEALTHCHECK - this container is designed for task execution, not service monitoring
WORKDIR /workspace
