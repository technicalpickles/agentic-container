# Agentic Container

A fast, reliable container environment optimized for AI agent execution in cloud platforms. Provides a solid foundation with agent tooling and mise version manager, designed to be extended with exactly the languages and tools your agents need.

## 🤖 Built for AI Agents

Optimized for cloud providers offering agentic experiences like Cursor Background Agents, Replit AI, and similar platforms:

- **Fast startup time**: Pre-installed agent toolchain for quick execution
- **Headless execution**: No interactive prompts, reliable automation
- **Code analysis ready**: ast-grep and ripgrep pre-installed, Python/Node.js standard
- **MCP server ready**: uv/uvx and npx universal package runners available
- **Extension-friendly**: Easy to customize for specific agent workflows

## 🚀 Quick Start with AI Coding Agents

All AI coding agents are pre-installed and ready to use! Just run the container and start with your preferred agent:

### Claude Code ([docs](https://docs.anthropic.com/en/docs/claude-code/setup))
```bash
# Start Claude Code directly - authenticate when prompted
docker run -it --rm -v $(pwd):/workspace ghcr.io/technicalpickles/agentic-container:latest claude

# Or start with a specific prompt
docker run -it --rm -v $(pwd):/workspace ghcr.io/technicalpickles/agentic-container:latest claude "explain this codebase"
```

### OpenAI Codex CLI ([docs](https://developers.openai.com/codex/cli/))
```bash
# Start Codex CLI - authenticate when prompted
docker run -it --rm -v $(pwd):/workspace ghcr.io/technicalpickles/agentic-container:latest codex

# Or start with a specific task
docker run -it --rm -v $(pwd):/workspace ghcr.io/technicalpickles/agentic-container:latest codex "fix the CI failure"
```

### GitHub Copilot CLI ([docs](https://docs.github.com/en/copilot/how-tos/use-copilot-for-common-tasks/use-copilot-in-the-cli))
```bash
# Authenticate with GitHub first, then use Copilot
docker run -it --rm -v $(pwd):/workspace ghcr.io/technicalpickles/agentic-container:latest bash -c "gh auth login && gh copilot suggest 'install dependencies'"

# Or use for code explanation
docker run -it --rm -v $(pwd):/workspace ghcr.io/technicalpickles/agentic-container:latest gh copilot explain "git rebase -i HEAD~3"
```

### Goose ([docs](https://block.github.io/goose/docs/getting-started/installation))
```bash
# Start Goose session - configure provider when prompted
docker run -it --rm -v $(pwd):/workspace ghcr.io/technicalpickles/agentic-container:latest goose session

# Or use Goose CLI for quick tasks
docker run -it --rm -v $(pwd):/workspace ghcr.io/technicalpickles/agentic-container:latest goose exec "analyze code quality"
```

### OpenCode.ai ([docs](https://opencode.ai/))
```bash
# Start OpenCode with terminal UI
docker run -it --rm -v $(pwd):/workspace ghcr.io/technicalpickles/agentic-container:latest opencode

# Use specific model provider
docker run -it --rm -v $(pwd):/workspace ghcr.io/technicalpickles/agentic-container:latest opencode --provider anthropic
```

### Experimenting with the container
```bash
# Use the dev environment for quick experimentation
docker run -it --rm -v $(pwd):/workspace ghcr.io/technicalpickles/agentic-container:dev bash
# Then run: claude, codex, gh copilot, goose, or opencode
```

## 🤔 When to Use Which Image?

| Scenario | Recommended Image | Why? |
|----------|------------------|------|
| **Production agent deployment** | `latest` + extensions | Smaller, controlled dependencies, maintained |
| **Cloud agent platforms** | `latest` + extensions | Predictable, minimal, fast startup |
| **Background agent processing** | `latest` + extensions | Consistent environment, documented requirements |
| **Agent prototyping** | `dev` | All languages ready, fastest to start experimenting |
| **Development environments** | `latest` + project tools | Optimized for the languages your projects use |
| **Unknown agent requirements** | Start with `dev`, then create extension | Explore needs, then optimize |

### ⚠️ Important Notes

- **`latest` is actively maintained**: Regular updates with latest tools and security patches  
- **Extension > Variants**: Better to extend `latest` than use an unmaintained variant
- **Document your extensions**: Make it easy to reproduce your agent environment
- **Headless by design**: All operations are non-interactive, suitable for automated agent execution

## 📦 Available Images

| Image Tag | Description | Size | Maintenance Level | Use Case |
|-----------|-------------|------|------------------|----------|
| `latest` | Ubuntu + mise + Python + Node.js + ast-grep + uv/uvx | ~950MB | **Actively maintained** | Production-ready base for agent deployment |
| `dev` | Latest + all languages | ~2.2GB | **Example only** | Agent prototyping and experimentation |


## 🔧 What's Included

### Core Tools (`latest` image)
- **Python** + **Node.js** (latest stable versions) - Standard runtime environments for agents
- **AI Coding Agents** - All pre-installed and ready to use:
  - **Claude Code** (`claude` command) - Anthropic's AI coding assistant
  - **OpenAI Codex CLI** (`codex` command) - OpenAI's coding agent
  - **GitHub Copilot CLI** (`gh copilot` command) - GitHub's AI pair programmer  
  - **Goose** (`goose` command) - Block's AI coding assistant
  - **OpenCode.ai** (`opencode` command) - Terminal-based AI coding agent
- **ast-grep** - Structural code search and analysis tool (installed via mise)
- **uv/uvx** - Fast Python package installer and universal script runner for MCP servers (installed via mise)
- **mise** - Universal version manager for additional languages and tools
- **Docker CLI** + Docker Compose - Container orchestration capabilities
- **Git** + **GitHub CLI** - Version control and GitHub integration with agent workflows
- **Essential CLI tools** - vim, nano, jq, curl, tree, htop, ripgrep for agent scripting
- **Non-root user** - Security-conscious execution environment
- **Optimized shell** - Configured bash environment for headless operations

### Additional Languages (`dev` image only)
The `dev` image includes pre-installed language runtimes for quick agent experimentation:
- **Ruby** + **Node.js** + **Python** + **Go** (all latest stable versions)
- **Lefthook** - Git hooks manager

> **Note**: For production agent deployment, extend `latest` with only the languages your agents need rather than using the large `dev` image. Pin specific versions using `mise use` or `.mise.toml` files.

## 🏗️ Extending for Different Technology Stacks

The recommended approach is to extend the `latest` image with exactly the languages and tools your **application stack needs**. All AI agents are pre-installed and ready to work with any stack you configure. Focus on the runtime environment for your specific application type.

### Python CLI Applications

Perfect for CLI tools, data processing, automation scripts:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Python already installed - add CLI-specific tools
RUN pip install click typer rich pydantic pytest black ruff mypy && \
    mise use -g python@3.13.7

# Verify CLI development environment
RUN python3 --version && click --version

WORKDIR /workspace
```

### Backend JavaScript/Node.js Services

For APIs, microservices, and server-side applications:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Node.js already installed - add backend-specific tools
RUN npm install -g typescript @types/node ts-node nodemon \
    express fastify @nestjs/cli prisma && \
    mise use -g node@22.12.0

# Add database clients
USER root
RUN apt-get update && apt-get install -y postgresql-client redis-tools && \
    rm -rf /var/lib/apt/lists/*
USER $USERNAME

WORKDIR /workspace
```

### Full-Stack Rails Applications

Complete environment for Ruby on Rails development:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Ruby and Rails ecosystem
RUN mise use -g ruby@3.4.1 node@22.12.0 && \
    gem install rails bundler rake rspec rubocop && \
    npm install -g yarn @hotwired/stimulus webpack

# Add database and system dependencies
USER root
RUN apt-get update && apt-get install -y \
    postgresql-client \
    redis-tools \
    imagemagick \
    libvips-tools && \
    rm -rf /var/lib/apt/lists/*
USER $USERNAME

WORKDIR /workspace
```

### Go Microservices

Lightweight, fast services and API backends:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Go and common tools
RUN mise use -g go@1.23.5 && \
    go install github.com/air-verse/air@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Add service dependencies  
USER root
RUN apt-get update && apt-get install -y postgresql-client && \
    rm -rf /var/lib/apt/lists/*
USER $USERNAME

WORKDIR /workspace
```

### React Frontend Applications

Modern web frontends with development tooling:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Node.js already installed - add frontend-specific tools
RUN npm install -g @vitejs/create-vite create-react-app \
    typescript @types/react @types/react-dom \
    eslint prettier tailwindcss && \
    mise use -g node@22.12.0

WORKDIR /workspace
```

### Using mise.toml for Version Management (Recommended)

For production deployments, use a `.mise.toml` file to pin exact versions:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Copy your version requirements
COPY .mise.toml ./
RUN mise install

# Install stack-specific dependencies
RUN pip install fastapi sqlalchemy alembic && \
    npm install -g typescript

WORKDIR /workspace
```

Example `.mise.toml`:
```toml
[tools]
python = "3.13.7"
node = "22.12.0" 
go = "1.23.5"
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

## 🔄 Cursor Background Agent Integration

Your agentic-container provides development environments that work seamlessly with Cursor Background Agents, Claude Code, Codex CLI, and other AI coding tools.

### Environment Configuration

Create `.cursor/environment.json` for containerized agent development:

```json
{
  "name": "Agentic Container Development",
  "dockerComposeFile": "docker-compose.yml",
  "service": "dev",
  "install": "mise install && pip install fastapi sqlalchemy pytest",
  "terminals": [
    {
      "name": "FastAPI Development", 
      "command": "python -c 'import fastapi; print(\"FastAPI development environment ready\")'"
    },
    {
      "name": "Code Analysis",
      "command": "sg --version && echo 'ast-grep ready for structural code search'"
    },
    {
      "name": "Package Tools",
      "command": "uvx --version && npm --version && echo 'Package runners ready'"
    }
  ]
}
```

### Best Practices for Background Agents

- **Use `standard` + extensions** for Background Agent environments (not `dev` - it's too large)
- **Mount code as volume** to enable agent file modifications
- **Include `.dockerignore`** to optimize build context for faster agent startup
- **Set non-interactive environment** for reliable automation
- **Pre-install agent dependencies** in your extended image for faster execution

### Example Extended Image for Background Agents

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:standard

# Set up development environment for the project agents will work on
RUN mise use -g python@3.13.7 node@22.12.0 && \
    pip install fastapi sqlalchemy alembic pytest && \
    npm install -g typescript @types/node vitest

# Verify development environment is ready for agent work
RUN python3 -c "import fastapi; print('FastAPI project environment ready')" && \
    tsc --version

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

RUN mise use -g python@3.13.7 node@22.12.0 && \
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

# ✅ Good: Install additional languages efficiently with specific versions
RUN mise use -g go@1.23.5 ruby@3.3.6 && \
    go install example.com/tool@latest && \
    gem install rails rake

# ❌ Avoid: Multiple RUN commands create unnecessary layers
# RUN mise use -g go@1.23.5
# RUN go install example.com/tool@latest
# RUN gem install rails rake
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
