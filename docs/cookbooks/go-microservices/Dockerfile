# Go Development Extension
# Demonstrates: mise install for new languages, go install for packages
FROM ghcr.io/technicalpickles/agentic-container:latest

# Build argument for Go version (can be overridden during build)
ARG GO_VERSION=1.23.5

# Install Go via mise
USER root
RUN mise use -g go@${GO_VERSION}

# Add Go packages via go install
RUN go install github.com/air-verse/air@latest
USER agent

WORKDIR /workspace
