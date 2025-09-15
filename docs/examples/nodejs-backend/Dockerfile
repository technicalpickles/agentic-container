# Node.js Development Extension  
# Demonstrates: npm global package installation, system packages
FROM ghcr.io/technicalpickles/agentic-container:latest

# Node.js already available - add packages via npm
RUN npm install -g typescript @types/node ts-node nodemon

# Add system dependencies when needed
USER root
RUN apt-get update && apt-get install -y postgresql-client && \
    rm -rf /var/lib/apt/lists/*
USER agent

WORKDIR /workspace
