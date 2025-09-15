# Extension Example: MCP Server Host Environment
# 
# This example demonstrates how to extend the agentic-container base 
# image for hosting Model Context Protocol (MCP) servers.
# Ready for both Python and Node.js MCP server implementations.
#
# Build: docker build -f docs/examples/mcp-server.dockerfile -t my-mcp-server .
# Run:   docker run --rm -p 8080:8080 -v $(pwd):/workspace my-mcp-server

FROM ghcr.io/technicalpickles/agentic-container:latest

# Install system dependencies for MCP server operations
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Install multiple languages for versatile MCP server hosting
USER vscode
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0

# Install Python MCP server tools and frameworks
RUN bash -c 'eval "$(mise activate bash)" && \
    pip install --no-cache-dir \
        pydantic \
        httpx \
        uvicorn \
        fastapi \
        python-dotenv \
        anthropic \
        sqlite-utils \
        sqlalchemy'

# Install Node.js MCP server tools and frameworks
RUN bash -c 'eval "$(mise activate bash)" && \
    npm install -g \
        @modelcontextprotocol/sdk \
        express \
        cors \
        ws \
        typescript \
        @types/node'

# Verify MCP server capabilities (both uvx and npx should work)
RUN bash -c 'eval "$(mise activate bash)" && \
    uvx --help > /dev/null && echo "uvx ready for Python MCP servers" && \
    npx --help > /dev/null && echo "npx ready for Node.js MCP servers" && \
    python3 -c "import pydantic; print(\"Python MCP runtime ready\")" && \
    node -e "console.log(\"Node.js MCP runtime ready\")"'

# Set working directory
WORKDIR /workspace

# Set environment variables optimized for MCP server deployment
ENV PYTHONUNBUFFERED=1
ENV NODE_ENV=production
ENV MCP_SERVER_PORT=8080

# Expose common MCP server ports
EXPOSE 8080 3000

# Default command shows available runtimes
CMD ["bash", "-c", "echo 'MCP Server Host Ready:' && echo '- Python: uvx your-python-mcp-server' && echo '- Node.js: npx your-nodejs-mcp-server' && echo '- Custom: python your_server.py or node your_server.js'"]
