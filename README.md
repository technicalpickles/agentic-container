# Agentic Container

A fast, reliable container environment optimized for AI agent execution in cloud platforms. Provides a solid foundation with agent tooling and mise version manager, designed to be extended with exactly the languages and tools your agents need.

## 🤖 Built for AI Agents

Optimized for cloud providers offering agentic experiences like Cursor Background Agents, Replit AI, and similar platforms:

- **Fast startup time**: Pre-installed agent toolchain for quick execution
- **Headless execution**: No interactive prompts, reliable automation  
- **Code analysis ready**: ast-grep, tree-sitter, ripgrep pre-installed
- **MCP server ready**: Universal package runners (uvx, npx) available
- **Cloud-native**: Designed for multi-tenant, scalable execution
- **Extension-friendly**: Easy to customize for specific agent workflows

## 🚀 Quick Start for Agent Workloads

### Agent Execution Environment (Recommended)
```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Add agent-specific tooling
RUN mise install python@3.13.7 && \
    mise use -g python@3.13.7 && \
    pip install anthropic pydantic python-dotenv
```

### MCP Server Environment
```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Ready for MCP servers in any language
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0
# Both uvx and npx are ready to use for protocol servers
```

### Quick Prototyping
```bash
# Use the dev environment (all languages pre-installed, for agent prototyping only)
docker run --rm ghcr.io/technicalpickles/agentic-container:dev python your_agent.py
```

## 🤔 When to Use Which Image?

| Scenario | Recommended Image | Why? |
|----------|------------------|------|
| **Production agent deployment** | `latest` + extensions | Smaller, controlled dependencies, maintained |
| **Cloud agent platforms** | `latest` + extensions | Predictable, minimal, fast startup |
| **Background agent processing** | `latest` + extensions | Consistent environment, documented requirements |
| **Agent prototyping** | `dev` | All languages ready, fastest to start experimenting |
| **MCP server hosting** | `latest` + languages | Optimized runtime, minimal overhead |
| **Code analysis agents** | `latest` + analysis tools | Pre-configured for structural code work |
| **Unknown agent requirements** | Start with `dev`, then create extension | Explore needs, then optimize |

### ⚠️ Important Notes

- **`dev` is NOT maintained**: Language versions may become outdated
- **`latest` is actively maintained**: Regular updates with latest tools and security patches  
- **Extension > Variants**: Better to extend `latest` than use an unmaintained variant
- **Document your extensions**: Make it easy to reproduce your agent environment
- **Headless by design**: All operations are non-interactive, suitable for automated agent execution

## 📦 Available Images

| Image Tag | Description | Size | Maintenance Level | Use Case |
|-----------|-------------|------|------------------|----------|
| `latest` | Ubuntu + mise + agent tools + analysis tools | ~750MB | **Actively maintained** | Production-ready base for agent deployment |
| `dev` | Latest + all languages | ~2.2GB | **Example only** | Agent prototyping and experimentation |


## 🔧 What's Included

### Core Tools (`latest` image)
- **mise** - Universal version manager for all languages and tools
- **Docker CLI** + Docker Compose - Container orchestration capabilities
- **Git** - Version control with sensible defaults for agent workflows
- **Code analysis tools** - ast-grep, tree-sitter, ripgrep for structural analysis
- **Universal runners** - uvx, npx ready for MCP server deployment
- **Essential CLI tools** - vim, nano, jq, curl, tree, htop for agent scripting
- **Non-root user** - Security-conscious execution environment
- **Optimized shell** - Configured bash environment for headless operations

### Additional Languages (`dev` image only)
The `dev` image includes pre-installed language runtimes for quick agent experimentation:
- **Ruby** 3.4.5 + **Node.js** 24.8.0 + **Python** 3.13.7 + **Go** 1.25.1
- **Lefthook** - Git hooks manager

> **Note**: For production agent deployment, extend `latest` with only the languages your agents need rather than using the large `dev` image.

## 🏗️ Extending Images

The recommended approach is to extend the `latest` image with exactly the languages and tools your agents need.

### Basic Agent Extension

Create a Dockerfile extending the base image for agent workloads:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Add language runtime for agent
RUN mise install python@3.13.7 && \
    mise use -g python@3.13.7 && \
    pip install anthropic pydantic python-dotenv requests
```

### Multi-Language Agent Extension

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Add multiple languages for cross-language agent analysis
RUN mise install python@3.13.7 node@24.8.0 go@1.25.1 && \
    mise use -g python@3.13.7 node@24.8.0 go@1.25.1 && \
    pip install ast-grep-py tree-sitter libcst && \
    npm install -g @tree-sitter/cli typescript && \
    go install golang.org/x/tools/cmd/goimports@latest
```

### Agent with Database Tools

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Add system packages for database interaction
USER root
RUN apt-get update && apt-get install -y \
    postgresql-client \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME  
RUN mise install python@3.13.7 && \
    mise use -g python@3.13.7 && \
    pip install sqlalchemy psycopg2-binary sqlite-utils && \
    pip install anthropic python-dotenv

WORKDIR /workspace
```

### Using Helper Scripts (Optional)

If available, you can use the extension scripts for convenience:

```bash
# Use the extend-image script if it exists
./scripts/extend-image.sh init
./scripts/extend-image.sh add-language python@3.13.7
./scripts/extend-image.sh add-tool gh
./scripts/extend-image.sh build my-custom-container:v1.0.0
```

## 📋 Agent Extension Examples

Common extension patterns for different agent use cases:

### Claude Agent Environment
```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

RUN mise install python@3.13.7 && mise use -g python@3.13.7

USER root
RUN apt-get update && apt-get install -y \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
RUN pip install anthropic python-dotenv pydantic && \
    pip install requests aiohttp httpx && \
    pip install ast-grep-py tree-sitter libcst

# Verify agent toolchain
RUN ast-grep --version && \
    python3 -c "import anthropic; print(\"Agent runtime ready\")"

WORKDIR /workspace
```

### Code Analysis Agent
```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install multiple languages for cross-language analysis
RUN mise install python@3.13.7 node@24.8.0 go@1.25.1 && \
    mise use -g python@3.13.7 node@24.8.0 go@1.25.1

USER $USERNAME
RUN pip install ast-grep-py tree-sitter libcst && \
    pip install anthropic python-dotenv pydantic && \
    # Node.js parsing tools  
    npm install -g @tree-sitter/cli typescript && \
    npm install -g @babel/parser @babel/traverse && \
    # Go analysis tools
    go install golang.org/x/tools/cmd/goimports@latest

# Pre-install tree-sitter grammars for common languages
RUN tree-sitter init-config && \
    tree-sitter install python javascript typescript go rust

WORKDIR /workspace  
```

### MCP Server Host
```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install multiple languages for versatile MCP server hosting
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0

USER root
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME  
RUN pip install pydantic httpx uvicorn fastapi && \
    pip install python-dotenv anthropic && \
    npm install -g @modelcontextprotocol/sdk && \
    npm install -g express cors ws

# Verify MCP server capabilities
RUN uvx --help && npx --help && \
    python3 -c "import pydantic; print(\"MCP server runtime ready\")"

WORKDIR /workspace
```

## 🔄 GitHub Actions Integration

Automate your custom image builds with GitHub Actions:

1. Copy the template workflow:
   ```bash
   cp templates/github-workflow-template.yml .github/workflows/build-container.yml
   ```

2. Customize for your needs:
   ```yaml
   - name: Build and push Docker image
     uses: docker/build-push-action@v5
     with:
       context: .
       file: ./path/to/your/Dockerfile  # Optional
       platforms: linux/amd64,linux/arm64
       push: ${{ github.event_name != 'pull_request' }}
       tags: ${{ steps.meta.outputs.tags }}
   ```

3. Enable GitHub Container Registry in your repository settings

4. Push changes - your custom image will be built and published automatically!

## 🧑‍💻 Container Usage

### VS Code Dev Containers (for agent development)

For custom agent development environments, create a `Dockerfile` and reference it:

```dockerfile
# .devcontainer/Dockerfile  
FROM ghcr.io/technicalpickles/agentic-container:latest

RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0 && \
    pip install anthropic pydantic python-dotenv && \
    npm install -g @tree-sitter/cli
```

```json
{
  "name": "My Agent Development Environment",
  "build": {
    "dockerfile": "Dockerfile"
  },
  "customizations": {
    "vscode": {
      "extensions": ["ms-python.python", "ms-vscode.vscode-typescript-next"]
    }
  },
  "mounts": [
    "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
  ],
  "privileged": true
}
```

### Quick Agent Prototyping with Pre-built Dev Image

For quick agent experimentation, you can use the `dev` image directly:

```json
{
  "name": "Quick Agent Prototyping Environment", 
  "image": "ghcr.io/technicalpickles/agentic-container:dev",
  "mounts": [
    "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
  ],
  "privileged": true
}
```

### Docker Compose

```yaml
services:
  dev:
    build:
      context: .
      dockerfile: Dockerfile.dev  # Your custom extension
    volumes:
      - .:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
    working_dir: /workspace
    tty: true
    stdin_open: true

  # Or for quick prototyping:
  prototype:
    image: ghcr.io/technicalpickles/agentic-container:dev
    volumes:
      - .:/workspace
      - /var/run/docker.sock:/var/run/docker.sock  
    working_dir: /workspace
    tty: true
    stdin_open: true
```

## 🔍 Architecture

The simplified architecture focuses on maintainability and flexibility:

```
ubuntu:24.04 (base OS)
├── standard (latest) → Ubuntu + mise + starship + dev tools (~750MB)
│   └── [Your Extensions] → Add languages via mise as needed
└── dev → Standard + all languages pre-installed (~2.2GB, example only)
```

### Design Principles

- **Single Maintained Base**: Focus on one solid foundation (`latest`)
- **Extension Pattern**: Add only what you need via mise
- **Predictable Structure**: Clear path from base to custom environment
- **Layer Optimization**: Minimize layers in your extensions

### Why This Approach?

- **Maintainable**: One image to keep updated instead of many variants
- **Flexible**: Get exactly the languages and tools you need
- **Predictable**: Consistent base across all use cases
- **Efficient**: Shared base layer, custom extension layers

### Extension Best Practices

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# ✅ Good: Install multiple languages in one RUN command
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0

# ✅ Good: Install packages in the same layer as language activation  
RUN pip install fastapi && \
    npm install -g typescript

# ❌ Avoid: Multiple RUN commands create unnecessary layers
# RUN mise install python@3.13.7
# RUN mise use -g python@3.13.7  
# RUN pip install fastapi
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/my-new-feature`
3. Test your changes with different base images
4. Commit your changes: `git commit -am 'Add some feature'`
5. Push to the branch: `git push origin feature/my-new-feature`
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the `docs/` directory for detailed guides
- **Issues**: Open an issue on GitHub for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions and community support

---

**Built with ❤️ for the AI agent community**
