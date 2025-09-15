# Go Development Extension
# Demonstrates: mise install for new languages, go install for packages
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Go via mise
USER root
RUN mise install go@1.23.5
USER agent

# Add Go packages via go install
RUN go install github.com/air-verse/air@latest

WORKDIR /workspace
