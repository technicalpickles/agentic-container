# Agentic Container

A flexible, extensible development container built for modern software development. Provides a solid foundation with development tools and mise version manager, designed to be extended with exactly the languages and tools you need.

## 🚀 Quick Start

### Option 1: Extend the base image (Recommended)
```dockerfile
FROM ghcr.io/your-repo/agentic-container:latest

# Add languages and configure in a single RUN to minimize layers
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0 && \
    bash -c 'eval "$(mise activate bash)" && \
        pip install fastapi requests && \
        npm install -g typescript'
```

### Option 2: Use the kitchen sink example
```bash
# Use the dev environment (all languages pre-installed, for prototyping only)
docker run -it --rm ghcr.io/your-repo/agentic-container:dev
```

## 🤔 When to Use Which Image?

| Scenario | Recommended Image | Why? |
|----------|------------------|------|
| **Production applications** | `latest` + extensions | Smaller, controlled dependencies, maintained |
| **CI/CD pipelines** | `latest` + extensions | Predictable, minimal, fast builds |
| **Team development** | `latest` + extensions | Consistent environment, documented requirements |
| **Quick prototyping** | `dev` | All languages ready, fastest to start experimenting |
| **Learning/tutorials** | `dev` | No setup required, focus on code not configuration |
| **Unknown requirements** | Start with `dev`, then create extension | Explore needs, then optimize |

### ⚠️ Important Notes

- **`dev` is NOT maintained**: Language versions may become outdated
- **`latest` is actively maintained**: Regular updates with latest tools and security patches  
- **Extension > Variants**: Better to extend `latest` than use an unmaintained variant
- **Document your extensions**: Make it easy for team members to reproduce your environment

## 📦 Available Images

| Image Tag | Description | Size | Maintenance Level | Use Case |
|-----------|-------------|------|------------------|----------|
| `latest` | Ubuntu + mise + starship + dev tools | ~750MB | **Actively maintained** | Production-ready base for extension |
| `dev` | Standard + all languages | ~2.2GB | **Example only** | Quick prototyping, not for production |

### Migration from Previous Versions

If you were using specific language variants, here's how to migrate:

```dockerfile
# Old approach: FROM ghcr.io/your-repo/agentic-container:python  
# New approach:
FROM ghcr.io/your-repo/agentic-container:latest
RUN mise install python@3.13.7 && mise use -g python@3.13.7

# Old approach: FROM ghcr.io/your-repo/agentic-container:node
# New approach:  
FROM ghcr.io/your-repo/agentic-container:latest
RUN mise install node@24.8.0 && mise use -g node@24.8.0

# Old approach: FROM ghcr.io/your-repo/agentic-container:ruby
# New approach:
FROM ghcr.io/your-repo/agentic-container:latest  
RUN mise install ruby@3.4.5 && mise use -g ruby@3.4.5

# Old approach: FROM ghcr.io/your-repo/agentic-container:go
# New approach:
FROM ghcr.io/your-repo/agentic-container:latest
RUN mise install go@1.25.1 && mise use -g go@1.25.1

# Old approach: FROM ghcr.io/your-repo/agentic-container:minimal
# New approach: Use latest (it's our maintained minimal base)
FROM ghcr.io/your-repo/agentic-container:latest
```

## 🔧 What's Included

### Core Tools (`latest` image)
- **mise** - Universal version manager for all languages
- **Docker CLI** + Docker Compose - Container orchestration
- **Git** - Version control with sensible defaults
- **Starship** - Beautiful, customizable shell prompt
- **Essential CLI tools** - vim, nano, jq, curl, tree, htop, etc.
- **Non-root user** - Ready for dev container use
- **Optimized shell** - Configured bash environment

### Additional Languages (`dev` image only)
The `dev` image includes pre-installed language runtimes for quick prototyping:
- **Ruby** 3.4.5 + **Node.js** 24.8.0 + **Python** 3.13.7 + **Go** 1.25.1
- **Lefthook** - Git hooks manager

> **Note**: For production use, extend `latest` with only the languages you need rather than using the large `dev` image.

## 🏗️ Extending Images

The recommended approach is to extend the `latest` image with exactly the languages and tools you need.

### Basic Extension Pattern

Create a Dockerfile extending the base image:

```dockerfile
FROM ghcr.io/your-repo/agentic-container:latest

# Add a single language
RUN mise install python@3.13.7 && \
    mise use -g python@3.13.7 && \
    bash -c 'eval "$(mise activate bash)" && pip install django fastapi'
```

### Multi-Language Extension

```dockerfile
FROM ghcr.io/your-repo/agentic-container:latest

# Add multiple languages in a single layer
RUN mise install python@3.13.7 node@24.8.0 go@1.25.1 && \
    mise use -g python@3.13.7 node@24.8.0 go@1.25.1 && \
    bash -c 'eval "$(mise activate bash)" && \
        pip install fastapi requests && \
        npm install -g typescript @nestjs/cli && \
        go install github.com/gorilla/mux@latest'
```

### Adding System Packages

```dockerfile
FROM ghcr.io/your-repo/agentic-container:latest

# Add system packages and languages
USER root
RUN apt-get update && apt-get install -y \
    postgresql-client \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME  
RUN mise install python@3.13.7 && \
    mise use -g python@3.13.7 && \
    bash -c 'eval "$(mise activate bash)" && pip install django psycopg2-binary redis'

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

## 📋 Extension Examples

Common extension patterns for different use cases:

### Python Machine Learning
```dockerfile
FROM ghcr.io/your-repo/agentic-container:latest

RUN mise install python@3.13.7 && mise use -g python@3.13.7

USER root
RUN apt-get update && apt-get install -y \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
RUN bash -c 'eval "$(mise activate bash)" && \
    pip install jupyter pandas numpy scikit-learn torch tensorflow && \
    pip install duckdb sqlite-utils plotly seaborn'

EXPOSE 8888
WORKDIR /workspace
```

### Full-Stack Web Development
```dockerfile
FROM ghcr.io/your-repo/agentic-container:latest

# Install languages
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0

# Install system packages
USER root  
RUN apt-get update && apt-get install -y \
    postgresql-client \
    mysql-client \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
RUN bash -c 'eval "$(mise activate bash)" && \
    # Python backend tools
    pip install django fastapi uvicorn psycopg2-binary redis && \
    # Node.js frontend tools  
    npm install -g @angular/cli @vue/cli create-react-app next'

WORKDIR /workspace  
```

### DevOps & Infrastructure
```dockerfile
FROM ghcr.io/your-repo/agentic-container:latest

RUN mise install python@3.13.7 go@1.25.1 && \
    mise use -g python@3.13.7 go@1.25.1

USER root
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME  
RUN bash -c 'eval "$(mise activate bash)" && \
    # Install cloud tools
    pip install awscli ansible && \
    # Install terraform
    mise install terraform@latest && mise use -g terraform@latest && \
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && sudo mv kubectl /usr/local/bin/'

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

## 🧑‍💻 Development Container Usage

### VS Code Dev Containers

For custom language combinations, create a `Dockerfile` and reference it:

```dockerfile
# .devcontainer/Dockerfile  
FROM ghcr.io/your-repo/agentic-container:latest

RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0 && \
    bash -c 'eval "$(mise activate bash)" && \
        pip install fastapi requests && \
        npm install -g typescript'
```

```json
{
  "name": "My Development Environment",
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

### Quick Prototyping with Pre-built Dev Image

For quick experimentation, you can use the `dev` image directly:

```json
{
  "name": "Quick Prototyping Environment", 
  "image": "ghcr.io/your-repo/agentic-container:dev",
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
    image: ghcr.io/your-repo/agentic-container:dev
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
FROM ghcr.io/your-repo/agentic-container:latest

# ✅ Good: Install multiple languages in one RUN command
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0

# ✅ Good: Install packages in the same layer as language activation  
RUN bash -c 'eval "$(mise activate bash)" && \
        pip install fastapi && \
        npm install -g typescript'

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

**Built with ❤️ for the developer community**
