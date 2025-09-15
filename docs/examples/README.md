# Agent Extension Examples

This directory contains practical examples of how to extend the `agentic-container` images to create custom agent execution environments. These examples demonstrate best practices, common patterns, and serve as starting points for your own agent deployments.

## Quick Start

All examples extend the `latest` image, which provides a solid foundation with mise, agent tools, and analysis capabilities. Each example includes comprehensive comments explaining the approach and customization options.

## Agent-Focused Examples

### 🤖 Claude Agent Environment
**File**: [`claude-agent.dockerfile`](claude-agent.dockerfile)

Creates an environment optimized for Claude Desktop agents and similar AI code modification tools:
- Python 3.13.7 runtime via mise
- Core agent packages: anthropic, pydantic, python-dotenv
- Code analysis tools: ast-grep, libcst
- Database tools for agent state management
- Headless execution optimizations

```bash
# Build and run
docker build -f docs/examples/claude-agent.dockerfile -t my-claude-agent .
docker run --rm -v $(pwd):/workspace my-claude-agent python agent_script.py
```

**Use Cases**: Claude Desktop agents, AI code modification, automated programming

### 🔍 Code Analysis Agent
**File**: [`code-analysis-agent.dockerfile`](code-analysis-agent.dockerfile)

Creates a multi-language environment for structural code analysis:
- Python + Node.js + Go runtime support
- Pre-installed ast-grep for structural analysis
- Cross-language analysis capabilities
- Code modification and transformation tools

```bash
# Build and run
docker build -f docs/examples/code-analysis-agent.dockerfile -t my-analysis-agent .
docker run --rm -v $(pwd):/workspace my-analysis-agent
```

**Use Cases**: Multi-language code analysis, automated refactoring, code quality agents

### 🌐 MCP Server Host
**File**: [`mcp-server.dockerfile`](mcp-server.dockerfile)

Creates an environment ready for hosting Model Context Protocol servers:
- Python + Node.js runtime support
- MCP framework packages for both languages
- Universal runners (uvx, npx) pre-configured
- Network optimizations for agent communication

```bash
# Build and run
docker build -f docs/examples/mcp-server.dockerfile -t my-mcp-server .
docker run --rm -p 8080:8080 -v $(pwd):/workspace my-mcp-server
```

**Use Cases**: MCP server hosting, protocol integration, agent communication

## Development-Focused Examples

### 🐍 Python Development
**File**: [`extend-python.dockerfile`](extend-python.dockerfile)

Creates a Python development environment with:
- Python 3.13.7 runtime via mise
- Pip package manager
- Proper mise activation patterns
- Security best practices (non-root user)

```bash
# Build and run
docker build -f docs/examples/extend-python.dockerfile -t my-python-env .
docker run -it --rm my-python-env
```

**Use Cases**: Data science, web APIs, automation scripts, machine learning

### 🟨 Node.js Development  
**File**: [`extend-nodejs.dockerfile`](extend-nodejs.dockerfile)

Creates a Node.js development environment with:
- Node.js 24.8.0 runtime via mise
- NPM package manager
- Optional TypeScript tooling
- Modern JavaScript/TypeScript development

```bash
# Build and run
docker build -f docs/examples/extend-nodejs.dockerfile -t my-node-env .
docker run -it --rm my-node-env
```

**Use Cases**: Web applications, APIs, React/Vue development, TypeScript projects

### 🔧 Full-Stack Development
**File**: [`extend-fullstack.dockerfile`](extend-fullstack.dockerfile)

Creates a comprehensive development environment with:
- Python 3.13.7 + FastAPI, pandas, pytest
- Node.js 24.8.0 + TypeScript, React CLI, Vue CLI  
- Go 1.25.1 + common tools
- Development tools (build-essential, tree, htop)
- Example project structure

```bash
# Build and run
docker build -f docs/examples/extend-fullstack.dockerfile -t my-fullstack-env .
docker run -it --rm my-fullstack-env
```

**Use Cases**: Polyglot development, microservices, full-stack applications

### 🏗️ Multi-Stage Production Build
**File**: [`multistage-app.dockerfile`](multistage-app.dockerfile)

Demonstrates production-ready patterns:
- **Build stage**: Compile/build with full tooling
- **Runtime stage**: Minimal runtime dependencies only
- FastAPI web application example
- Health checks and security practices
- Optimized final image size

```bash
# Build and run
docker build -f docs/examples/multistage-app.dockerfile -t my-production-app .
docker run -p 8000:8000 my-production-app
curl http://localhost:8000  # Test the API
```

**Use Cases**: Production deployments, web services, optimized container images

## Testing and Validation

### Automated Testing
Run the comprehensive test suite to validate all examples:

```bash
# Test all examples
./docs/examples/test-extensions.sh

# Test and cleanup afterwards  
./docs/examples/test-extensions.sh --cleanup
```

The test script:
- ✅ Builds each example image
- ✅ Validates functionality works correctly
- ✅ Tests mise activation and language runtimes
- ✅ Provides detailed success/failure reporting
- 🧹 Optional cleanup of test images

### Manual Testing
Test individual examples:

```bash
# Build specific example
docker build -f docs/examples/extend-python.dockerfile -t test-python .

# Test functionality
docker run --rm test-python bash -c 'python3 --version'

# Interactive testing
docker run -it --rm test-python
```

## Best Practices Demonstrated

### 1. **Mise Activation Pattern**
All examples show the correct way to activate mise in Dockerfiles:
```dockerfile
RUN python3 --version
```

### 2. **Security (Non-Root User)**
```dockerfile
USER vscode
WORKDIR /workspace
```

### 3. **Package Cleanup**
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends package \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/*
```

### 4. **Multi-Stage Optimization**
```dockerfile
# Build stage with full tooling
FROM ghcr.io/technicalpickles/agentic-container:latest AS builder
# ... build steps ...

# Runtime stage
FROM ghcr.io/technicalpickles/agentic-container:latest AS runtime
COPY --from=builder /build/app /app
```

## Customization Guidelines

### Adding Languages
```dockerfile
# Install language runtime
RUN mise install python@3.13.7 node@24.8.0

# Set as global version
RUN mise use -g python@3.13.7 node@24.8.0

# Test installation
RUN python3 --version && node --version
```

### Adding System Packages
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    your-package-here \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/*
```

### Adding Application Dependencies
```dockerfile
# For Python
RUN pip install --no-cache-dir package1 package2

# For Node.js
RUN npm install -g package1 package2

# For Go
RUN go install github.com/user/package@latest
```

## Size Optimization Tips

1. **Start with `latest`**: Use the maintained `latest` image which provides optimal balance of tools and size

2. **Multi-stage builds**: Use separate build and runtime stages for production images

3. **Package cleanup**: Always clean up package caches and temporary files

4. **Combine RUN commands**: Reduce layers by combining related commands

5. **Use `.dockerignore`**: Exclude unnecessary files from build context

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Test Extension Examples
  run: |
    chmod +x docs/examples/test-extensions.sh
    ./docs/examples/test-extensions.sh --cleanup
```

### Dependency on Latest Image
All examples depend on the `agentic-container:latest` image being available. In CI, ensure it's built first or pull from registry.

## Contributing

When adding new examples:

1. **Follow naming pattern**: `extend-{purpose}.dockerfile`
2. **Add comprehensive comments**: Explain the purpose and customization options
3. **Include in test script**: Add validation test to `test-extensions.sh`
4. **Update this README**: Document the new example
5. **Test thoroughly**: Ensure the example works in different scenarios

## Troubleshooting

### Common Issues

**"python3: not found"**
```dockerfile
# Wrong: RUN python3 --version  
# Right: RUN python3 --version
```

**"Permission denied"** 
```dockerfile
# Add after installing packages
USER vscode
WORKDIR /workspace
```

**Large image size**
```dockerfile
# Always cleanup after package installation
RUN apt-get update && apt-get install -y package \
    && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
```

### Getting Help

- Check the [main documentation](../../README.md)
- Review the [contributing guide](../../CONTRIBUTING.md)  
- Run the test suite for validation
- Look at working examples for patterns

---

These examples provide a solid foundation for creating custom development environments while maintaining the benefits of the maintained `agentic-container:latest` base image.
