# Agentic Container

A flexible, extensible development container ecosystem built for modern software development. Provides ready-to-use development environments with multiple programming languages, development tools, and Docker support.

## 🚀 Quick Start

Choose your base image and get started immediately:

```bash
# Use the full development environment (all languages)
docker run -it --rm ghcr.io/your-repo/agentic-container:latest

# Use a specific language environment
docker run -it --rm ghcr.io/your-repo/agentic-container:python

# Use just the base tools without languages
docker run -it --rm ghcr.io/your-repo/agentic-container:base
```

## 📦 Available Images

| Image Tag | Description | Use Case |
|-----------|-------------|----------|
| `base` | Core system tools, mise, Docker CLI | Minimal foundation for custom builds |
| `tools` | Base + starship prompt and dev enhancements | Enhanced development experience |
| `ruby` | Tools + Ruby runtime | Ruby development |
| `node` | Tools + Node.js runtime | JavaScript/TypeScript development |
| `python` | Tools + Python runtime | Python development |
| `go` | Tools + Go runtime | Go development |
| `dev` (latest) | All languages and tools | Full-featured development environment |

## 🔧 What's Included

### Core Tools (All Images)
- **mise** - Universal version manager
- **Docker CLI** + Docker Compose - Container orchestration
- **Git** - Version control with sensible defaults
- **Essential CLI tools** - vim, nano, jq, curl, tree, htop, etc.
- **Non-root user** - Ready for dev container use

### Development Enhancements (tools+ images)  
- **Starship** - Beautiful, customizable shell prompt
- **Configured shell** - Optimized bash environment
- **Git configuration** - Safe directories and reasonable defaults

### Language Runtimes
- **Ruby** 3.4.5 (latest stable)
- **Node.js** 24.8.0 LTS, 22.11.0 
- **Python** 3.13.7 (latest)
- **Go** 1.25.1 (latest)
- **Lefthook** - Git hooks manager

## 🏗️ Extending Images

### Method 1: Simple Extension with Helper Script

Use the included `extend-image` script for quick customization:

```bash
# Initialize a new Dockerfile extending the Node.js image
extend-image.sh init node

# Add Python to your existing setup
extend-image.sh add-language python@3.12

# Add additional tools
extend-image.sh add-tool gh
extend-image.sh add-tool kubectl

# Build your custom image
extend-image.sh build my-dev-container:v1.0.0
```

### Method 2: Custom Dockerfile

Create your own Dockerfile extending any base image:

```dockerfile
FROM ghcr.io/your-repo/agentic-container:python

# Add your custom tools and configurations
USER root
RUN apt-get update && apt-get install -y postgresql-client && rm -rf /var/lib/apt/lists/*

USER $USERNAME  
RUN mise install terraform@latest && \
    python -m pip install django fastapi

# Your customizations here
WORKDIR /workspace
```

### Method 3: Automated Publishing

Use the publishing script for automated builds:

```bash
# Create and publish a custom Python ML environment
./scripts/publish-extended-image.sh \
    --template python-ml \
    --push \
    python \
    ghcr.io/myorg/python-ml-dev:v1.0.0

# Create a custom environment with specific tools
./scripts/publish-extended-image.sh \
    --language ruby@3.2 \
    --tool gh \
    --tool kubectl \
    --package postgresql-client \
    --push \
    base \
    ghcr.io/myorg/ruby-devops:latest
```

## 📋 Templates

Pre-built templates for common use cases:

### Python Machine Learning (`python-ml`)
- Jupyter Lab environment
- ML libraries: numpy, pandas, scikit-learn, torch, tensorflow
- Data tools: duckdb, sqlite
- Ready for notebook development

### Full-Stack Web Development (`fullstack-web`)  
- Database clients: postgresql, mysql, redis
- Frontend tooling: Angular CLI, Vue CLI, React, Next.js
- Backend frameworks: Django, FastAPI, Rails
- DevOps tools: terraform, kubectl, helm

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

## 🧑‍💻 Development Container Usage

### VS Code Dev Containers

Create `.devcontainer/devcontainer.json`:

```json
{
  "name": "My Development Environment",
  "image": "ghcr.io/your-repo/agentic-container:python",
  "customizations": {
    "vscode": {
      "extensions": ["ms-python.python"]
    }
  },
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
    image: ghcr.io/your-repo/agentic-container:dev
    volumes:
      - .:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
    working_dir: /workspace
    tty: true
    stdin_open: true
```

## 🔍 Architecture

The image architecture uses multi-stage builds for optimal layering and extensibility:

```
ubuntu:24.04 (base OS)
├── base (system tools, mise, Docker CLI, user setup)
│   ├── tools (starship, shell enhancements)
│   │   ├── ruby (tools + Ruby runtime)  
│   │   ├── node (tools + Node.js runtime)
│   │   ├── python (tools + Python runtime)
│   │   ├── go (tools + Go runtime)
│   │   └── dev (tools + all languages)
│   ├── ruby-stage (Ruby build stage)
│   ├── node-stage (Node.js build stage)
│   ├── python-stage (Python build stage)
│   └── go-stage (Go build stage)
```

This design allows you to:
- Extend from any layer based on your needs
- Mix and match language runtimes  
- Maintain small image sizes through shared layers
- Build custom combinations efficiently

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

**Built with ❤️ for the developer community**
