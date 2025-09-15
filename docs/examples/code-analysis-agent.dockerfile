# Extension Example: Multi-Language Code Analysis Agent
# 
# This example demonstrates how to extend the agentic-container base 
# image for agents that perform structural code analysis and modification
# across multiple programming languages.
#
# Build: docker build -f docs/examples/code-analysis-agent.dockerfile -t my-analysis-agent .
# Run:   docker run --rm -v $(pwd):/workspace my-analysis-agent

FROM ghcr.io/technicalpickles/agentic-container:latest

# Install multiple languages for comprehensive code analysis
USER vscode
RUN mise install python@3.13.7 node@24.8.0 go@1.25.1 && \
    mise use -g python@3.13.7 node@24.8.0 go@1.25.1

# Install Python code analysis tools
RUN \
    pip install --no-cache-dir \
        ast-grep-py \
        tree-sitter \
        libcst \
        anthropic \
        python-dotenv \
        pydantic \
        requests
# Install Node.js parsing and analysis tools  
RUN \
    npm install -g \
        @tree-sitter/cli \
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
# Pre-install tree-sitter grammars for common languages
# This speeds up agent startup by avoiding downloads during execution
RUN \
    tree-sitter init-config && \
    tree-sitter install python && \
    tree-sitter install javascript && \
    tree-sitter install typescript && \
    tree-sitter install go && \
    tree-sitter install rust && \
    tree-sitter install java && \
    tree-sitter install c && \
    tree-sitter install cpp
# Verify all analysis tools are working
RUN \
    ast-grep --version && \
    tree-sitter --version && \
    python3 -c "import tree_sitter; print(\"Python analysis ready\")" && \
    node -e "console.log(\"Node.js analysis ready\")" && \
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
CMD ["bash", "-c", "echo Code Analysis Agent Ready: && echo - ast-grep: structural pattern matching && echo - tree-sitter: syntax tree parsing && echo - Multi-language: Python, JS/TS, Go, Rust, Java, C/C++ && echo Run your analysis script: python analysis.py"]
