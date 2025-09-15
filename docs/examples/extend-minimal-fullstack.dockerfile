# Extension Example: Full-Stack Development Environment
#
# This example demonstrates extending the minimal image with multiple
# language runtimes for full-stack development. This creates a custom
# development environment with Python, Node.js, and essential tools.
#
# Build: docker build -f docs/examples/extend-minimal-fullstack.dockerfile -t my-fullstack-container .
# Run:   docker run -it --rm my-fullstack-container

FROM ghcr.io/technicalpickles/agentic-container:minimal

# Install multiple language runtimes
RUN mise install python@3.13.7 node@24.8.0 go@1.25.1

# Set global versions
RUN mise use -g python@3.13.7 node@24.8.0 go@1.25.1

# Verify all installations work
RUN bash -c 'eval "$(mise activate bash)" && \
    echo "=== Verifying Language Installations ===" && \
    python3 --version && \
    node --version && \
    go version && \
    echo "=== All languages ready! ==="'

# Install common development tools and packages
RUN bash -c 'eval "$(mise activate bash)" && \
    # Python packages for web development and data science
    pip install --no-cache-dir \
        fastapi uvicorn requests pandas numpy pytest black flake8 && \
    # Node.js packages for modern web development  
    npm install -g \
        typescript @types/node ts-node \
        prettier eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin \
        create-react-app @vue/cli && \
    # Go tools
    go install golang.org/x/tools/cmd/goimports@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest'

# Add development-specific tools that weren't in minimal
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    tree \
    htop \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/*

# Switch to non-root user
USER vscode

# Set working directory
WORKDIR /workspace

# Create example project structure
RUN mkdir -p /workspace/examples && \
    echo 'print("Hello from Python!")' > /workspace/examples/hello.py && \
    echo 'console.log("Hello from Node.js!");' > /workspace/examples/hello.js && \
    echo 'package main\nimport "fmt"\nfunc main() { fmt.Println("Hello from Go!") }' > /workspace/examples/hello.go

# Test that everything works with a comprehensive test
RUN bash -c 'eval "$(mise activate bash)" && \
    cd /workspace/examples && \
    echo "=== Testing Full-Stack Environment ===" && \
    python3 hello.py && \
    node hello.js && \
    go run hello.go && \
    echo "=== Full-Stack environment ready! ==="'

# Default command
CMD ["/bin/bash", "--login"]
