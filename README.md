# Agentic Container

A fast, reliable container environment optimized for AI agent execution in cloud platforms. Provides a solid foundation with agent tooling and mise version manager, designed to be extended with exactly the languages and tools your agents need.

## 🤖 Built for AI Agents

Optimized for cloud providers offering agentic experiences like Cursor Background Agents, Replit AI, and similar platforms:

- **Fast startup time**: Pre-installed agent toolchain for quick execution
- **Headless execution**: No interactive prompts, reliable automation  
- **Code analysis ready**: ast-grep and ripgrep pre-installed, Python/Node.js standard
- **MCP server ready**: Universal package runners (uvx, npx) available
- **Cloud-native**: Designed for multi-tenant, scalable execution
- **Extension-friendly**: Easy to customize for specific agent workflows

## 🚀 Quick Start for Agent Workloads

### Claude Agent Environment (Recommended)
```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Python and Node.js already installed as standard
# Add Claude agent-specific tooling
RUN pip install anthropic pydantic python-dotenv

# Verify Claude agent is ready
RUN python3 -c "import anthropic; print('Claude agent ready')" && \
    sg --version
```

### MCP Server Environment
```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Python and Node.js already installed as standard
# Both uvx and npx are ready to use for protocol servers
RUN pip install pydantic httpx && \
    npm install -g @modelcontextprotocol/sdk
```

### Quick Prototyping
```bash
# Use the dev environment (all languages pre-installed, for Claude agent prototyping only)
docker run --rm ghcr.io/technicalpickles/agentic-container:dev python your_claude_agent.py
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
| `latest` | Ubuntu + mise + Python + Node.js + ast-grep | ~950MB | **Actively maintained** | Production-ready base for agent deployment |
| `dev` | Latest + all languages | ~2.2GB | **Example only** | Agent prototyping and experimentation |


## 🔧 What's Included

### Core Tools (`latest` image)
- **Python 3.13.7** + **Node.js 24.8.0** - Standard runtime environments for agents
- **ast-grep** - Structural code search and analysis tool
- **mise** - Universal version manager for additional languages and tools
- **Docker CLI** + Docker Compose - Container orchestration capabilities
- **Git** - Version control with sensible defaults for agent workflows
- **Universal runners** - uvx (Python) and npx (Node.js) ready for MCP server deployment
- **Essential CLI tools** - vim, nano, jq, curl, tree, htop, ripgrep for agent scripting
- **Non-root user** - Security-conscious execution environment
- **Optimized shell** - Configured bash environment for headless operations

### Additional Languages (`dev` image only)
The `dev` image includes pre-installed language runtimes for quick agent experimentation:
- **Ruby** 3.4.5 + **Node.js** 24.8.0 + **Python** 3.13.7 + **Go** 1.25.1
- **Lefthook** - Git hooks manager

> **Note**: For production agent deployment, extend `latest` with only the languages your agents need rather than using the large `dev` image.

## 🏗️ Extending Images

The recommended approach is to extend the `latest` image with exactly the languages and tools your agents need.

### Basic Claude Agent Extension

Create a Dockerfile extending the base image for Claude agent workloads:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Python and Node.js already installed as standard
# Add Claude agent packages
RUN pip install anthropic pydantic python-dotenv requests

# Verify Claude agent is ready
RUN python3 -c "import anthropic; print('Claude agent runtime ready')" && \
    sg --version

WORKDIR /workspace
```

### Multi-Language Agent Extension

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Python and Node.js already installed - add Go for cross-language analysis
RUN mise install go@1.25.1 && \
    mise use -g go@1.25.1 && \
    pip install libcst && \
    npm install -g typescript && \
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

# Python, Node.js, and ast-grep already installed as standard
USER root
RUN apt-get update && apt-get install -y \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
RUN pip install anthropic python-dotenv pydantic && \
    pip install requests aiohttp httpx && \
    pip install libcst

# Verify Claude agent toolchain
RUN sg --version && \
    python3 -c "import anthropic; print('Claude agent runtime ready')"

WORKDIR /workspace
```

### Code Analysis Agent
```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Python and Node.js already installed - add Go for multi-language analysis
RUN mise install go@1.25.1 && \
    mise use -g go@1.25.1

USER $USERNAME
# ast-grep already installed as standard
RUN pip install libcst && \
    pip install anthropic python-dotenv pydantic && \
    # Node.js parsing tools  
    npm install -g typescript && \
    npm install -g @babel/parser @babel/traverse && \
    # Go analysis tools
    go install golang.org/x/tools/cmd/goimports@latest

# Verify multi-language toolchain
RUN sg --version && \
    python3 -c "import libcst; print('Python analysis ready')" && \
    tsc --version && \
    go version

WORKDIR /workspace  
```

### MCP Server Host
```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Python and Node.js already installed as standard
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

# Verify MCP server capabilities (uvx and npx available from standard install)
RUN uvx --version && npx --version && \
    python3 -c "import pydantic; print('MCP server runtime ready')"

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
    npm install -g typescript
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

### Quick Claude Agent Prototyping with Pre-built Dev Image

For quick Claude agent experimentation, you can use the `dev` image directly:

```json
{
  "name": "Quick Claude Agent Prototyping Environment", 
  "image": "ghcr.io/technicalpickles/agentic-container:dev",
  "postCreateCommand": "pip install anthropic pydantic python-dotenv",
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

# ✅ Good: Python and Node.js already available - just add packages
RUN pip install fastapi anthropic && \
    npm install -g typescript

# ✅ Good: Install additional languages efficiently
RUN mise install go@1.25.1 ruby@3.4.5 && \
    mise use -g go@1.25.1 ruby@3.4.5 && \
    go install example.com/tool@latest && \
    gem install rails rake

# ❌ Avoid: Multiple RUN commands create unnecessary layers
# RUN mise install go@1.25.1
# RUN mise use -g go@1.25.1  
# RUN go install example.com/tool@latest
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
