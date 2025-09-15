# Extension Example: Multi-Language Code Analysis Agent
# 
# This example demonstrates how to extend the agentic-container base 
# image for agents that perform structural code analysis and modification
# across multiple programming languages.
#
# Build: docker build -f docs/examples/code-analysis-agent.dockerfile -t my-analysis-agent .
# Run:   docker run --rm -v $(pwd):/workspace my-analysis-agent

FROM ghcr.io/technicalpickles/agentic-container:latest

# Python and Node.js already installed - add Go for comprehensive analysis
USER vscode
RUN mise install go@1.25.1 && \
    mise use -g go@1.25.1

# Install Python code analysis tools (ast-grep already installed as standard)
RUN \
    pip install --no-cache-dir \
        libcst \
        anthropic \
        python-dotenv \
        pydantic \
        requests

# Install Node.js parsing and analysis tools  
RUN \
    npm install -g \
        typescript \
        @typescript-eslint/parser \
        @babel/parser \
        @babel/traverse \
        acorn \
        esprima

# Install Go analysis tools
RUN \
    go install golang.org/x/tools/cmd/goimports@latest && \
    go install golang.org/x/tools/cmd/gofmt@latest && \
    go install golang.org/x/tools/gopls@latest

# Verify all analysis tools are working
RUN \
    sg --version && \
    python3 -c "import libcst; print('Python analysis ready')" && \
    node -e "console.log('Node.js analysis ready')" && \
    go version && \
    echo "Multi-language code analysis agent ready"
# Set working directory
WORKDIR /workspace

# Set environment variables optimized for analysis workloads
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV GO111MODULE=on
ENV CGO_ENABLED=0

# Default command demonstrates analysis capabilities
CMD ["bash", "-c", "echo Code Analysis Agent Ready: && echo - ast-grep: structural pattern matching && echo - Multi-language support: Python, JS/TS, Go && echo Run your analysis script: python analysis.py"]
