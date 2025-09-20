# Node.js Development Extension  
# Demonstrates: npm global package installation, system packages
FROM ghcr.io/technicalpickles/agentic-container:main

# Add system dependencies and Node.js packages as root
USER root
RUN npm install -g typescript @types/node ts-node nodemon \
    && apt-get update && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*
USER agent

# No HEALTHCHECK - this container is designed for task execution, not service monitoring
WORKDIR /workspace
