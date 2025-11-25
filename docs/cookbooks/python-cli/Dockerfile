# Python Development Extension
# Demonstrates: pip package manager usage
ARG BASE_IMAGE=ghcr.io/technicalpickles/agentic-container:main
FROM ${BASE_IMAGE}

# Python already available - add packages via pip
RUN pip install --no-cache-dir \
    click \
    typer \
    rich \
    pydantic

# Ensure we run as non-root user for security
USER agent

WORKDIR /workspace
