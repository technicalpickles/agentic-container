# Frontend Development Extension
# Demonstrates: npm global installs for frontend tools
ARG BASE_IMAGE=ghcr.io/technicalpickles/agentic-container:main
FROM ${BASE_IMAGE}

# Node.js already available - add packages via npm
USER root
RUN npm install -g create-vite typescript eslint prettier
USER agent

WORKDIR /workspace
