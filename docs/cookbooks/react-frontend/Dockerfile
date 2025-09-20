# Frontend Development Extension
# Demonstrates: npm global installs for frontend tools
FROM ghcr.io/technicalpickles/agentic-container:main

# Node.js already available - add packages via npm
USER root
RUN npm install -g create-vite typescript eslint prettier
USER agent

# No HEALTHCHECK - this container is designed for task execution, not service monitoring
WORKDIR /workspace
