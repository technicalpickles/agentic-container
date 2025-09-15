# Frontend Development Extension
# Demonstrates: npm global installs for frontend tools
FROM ghcr.io/technicalpickles/agentic-container:latest

# Node.js already available - add frontend-specific packages
USER root
RUN npm install -g create-vite typescript eslint prettier
USER vscode

WORKDIR /workspace
