# Go Development Extension
# Demonstrates: mise install for new languages, go install for packages
ARG BASE_IMAGE=ghcr.io/technicalpickles/agentic-container:main
FROM ${BASE_IMAGE}

# Build argument for Go version (can be overridden during build)
ARG GO_VERSION=1.25.4

# Install Go via mise
USER root
RUN mise use -g go@${GO_VERSION}

# Add Go packages via go install
RUN go install github.com/air-verse/air@latest
USER agent

# No HEALTHCHECK - this container is designed for task execution, not service monitoring
WORKDIR /workspace
