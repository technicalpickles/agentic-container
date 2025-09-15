# Extension Example: Claude Desktop Agent Environment
# 
# This example demonstrates how to extend the agentic-container base 
# image for Claude Desktop agents and similar AI code modification tools.
# Optimized for fast startup and reliable headless execution.
#
# Build: docker build -f docs/examples/claude-agent.dockerfile -t my-claude-agent .
# Run:   docker run --rm -v $(pwd):/workspace my-claude-agent python agent_script.py

FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Python and system dependencies for agent operations
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-dev \
    build-essential \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Install and configure Python runtime
USER vscode
RUN mise install python@3.13.7 && mise use -g python@3.13.7

# Install core agent packages in a single layer for efficiency
RUN \
    pip install --no-cache-dir \
        anthropic \
        python-dotenv \
        pydantic \
        requests \
        aiohttp \
        httpx
# Install code analysis tools that agents commonly need
RUN \
    pip install --no-cache-dir \
        ast-grep-py \
        tree-sitter \
        libcst \
        sqlite-utils \
        sqlalchemy
# Verify agent toolchain is ready (fail fast if something is wrong)
RUN \
    ast-grep --version && \
    python3 -c "import anthropic; print(\"Claude agent runtime ready\")" && \
    python3 -c "import tree_sitter; print(\"Code analysis tools ready\")"
# Set working directory
WORKDIR /workspace

# Set environment variables optimized for headless agent execution
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV ANTHROPIC_API_KEY=""

# Default command for agent execution (can be overridden)
CMD ["python", "--version"]
