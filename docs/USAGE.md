# Usage Guide

This guide covers common usage patterns and advanced configuration for the
agentic-container ecosystem.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Extension Patterns](#extension-patterns)
- [Configuration Management](#configuration-management)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)

## Basic Usage

### Running Interactive Sessions

Start an interactive development session:

```bash
# Full development environment
docker run -it --rm \
  -v $(pwd):/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/technicalpickles/agentic-container:latest

# Language-specific environment
docker run -it --rm \
  -v $(pwd):/workspace \
  ghcr.io/technicalpickles/agentic-container:latest
```

### Using with Docker Compose

Create a `docker-compose.yml` for your project:

```yaml
services:
  dev:
    image: ghcr.io/technicalpickles/agentic-container:dev
    volumes:
      - .:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
      - ~/.gitconfig:/home/agent/.gitconfig:ro
      - ~/.ssh:/home/agent/.ssh:ro
    working_dir: /workspace
    tty: true
    stdin_open: true
    environment:
      - TERM=xterm-256color
    ports:
      - '3000:3000' # Expose development servers
      - '8000:8000'
```

Then start your development environment:

```bash
docker-compose up -d dev
docker-compose exec dev bash
```

## Extension Patterns

### Pattern 1: Minimal Extension

Start with the base image and add only what you need:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Add just Python
RUN mise install python@3.11 && mise use -g python@3.11

# Add project-specific tools
RUN python -m pip install poetry black pytest
```

### Pattern 2: Multi-Language Projects

Combine multiple languages as needed:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:standard

# Add multiple languages
RUN mise install python@3.11 node@20 && \
    mise use -g python@3.11 node@20

# Install language-specific tools
RUN python -m pip install poetry && \
    npm install -g typescript @nestjs/cli

# Add project configuration
COPY pyproject.toml package.json /workspace/
RUN cd /workspace && poetry install && npm install
```

### Pattern 3: Specialized Environment

Create a purpose-built environment:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install ML/AI specific tools
USER root
RUN apt-get update && apt-get install -y \
    python3-dev libopenblas-dev liblapack-dev \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
RUN python -m pip install \
    torch tensorflow \
    jupyter jupyterlab \
    pandas numpy scikit-learn

# Configure Jupyter
RUN jupyter lab --generate-config && \
    echo "c.ServerApp.ip = '0.0.0.0'" >> ~/.jupyter/jupyter_lab_config.py

EXPOSE 8888
CMD ["jupyter", "lab", "--allow-root"]
```

## Configuration Management

### Environment Variables

Key environment variables you can customize:

| Variable          | Description                  | Default                 |
| ----------------- | ---------------------------- | ----------------------- |
| `MISE_DATA_DIR`   | Mise installation directory  | `/usr/local/share/mise` |
| `MISE_CONFIG_DIR` | Mise configuration directory | `/etc/mise`             |
| `MISE_CACHE_DIR`  | Mise cache directory         | `/tmp/mise-cache`       |
| `USERNAME`        | Non-root user name           | `agent`                 |
| `USER_UID`        | User ID                      | `1001`                  |
| `USER_GID`        | Group ID                     | `1001`                  |

### Custom Configuration Files

Mount your configuration files:

```yaml
# docker-compose.yml
services:
  dev:
    image: ghcr.io/technicalpickles/agentic-container:dev
    volumes:
      # Git configuration
      - ~/.gitconfig:/home/agent/.gitconfig:ro
      # SSH keys
      - ~/.ssh:/home/agent/.ssh:ro
      # Shell configuration
      - ./config/.bashrc:/home/agent/.bashrc:ro
      # Tool configurations
      - ./config/.vimrc:/home/agent/.vimrc:ro
      - ./config/starship.toml:/home/agent/.config/starship.toml:ro
```

### Language Version Management

Use mise to manage multiple versions:

```bash
# In your project directory
echo "python 3.11.0" > .tool-versions
echo "node 20.0.0" >> .tool-versions
echo "ruby 3.2.0" >> .tool-versions

# mise will automatically use these versions in this directory
```

### Global vs Project Configuration

```bash
# Global configuration (affects all projects)
mise use -g python@3.11 node@20

# Project configuration (affects current directory)
mise use python@3.11 node@20

# List installed versions
mise list

# List available versions
mise list-remote python
```

## CI/CD Integration

### GitHub Actions

Complete workflow for building custom images:

```yaml
name: Build Custom Dev Container

on:
  push:
    paths: ['Dockerfile', '.github/workflows/build.yml']
  schedule:
    - cron: '0 2 * * 0' # Weekly rebuild

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### GitLab CI

```yaml
# .gitlab-ci.yml
variables:
  DOCKER_DRIVER: overlay2
  DOCKER_BUILDKIT: 1

build:
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER
      --password-stdin $CI_REGISTRY
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - |
      if [ "$CI_COMMIT_BRANCH" == "$CI_DEFAULT_BRANCH" ]; then
        docker tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA $CI_REGISTRY_IMAGE:latest
        docker push $CI_REGISTRY_IMAGE:latest
      fi
```

## Troubleshooting

### Common Issues

#### Permission Issues

```bash
# If you get permission errors, ensure correct user mapping
docker run -it --rm \
  --user $(id -u):$(id -g) \
  -v $(pwd):/workspace \
  ghcr.io/technicalpickles/agentic-container:dev
```

#### Docker Socket Access

```bash
# Ensure Docker socket is accessible
ls -la /var/run/docker.sock

# Fix permissions if needed (Linux)
sudo usermod -aG docker $USER
newgrp docker
```

#### Mise Not Working

```bash
# Check if mise is properly activated
which mise
mise --version

# Manually activate if needed
eval "$(mise activate bash)"

# Check configuration
mise config
```

### Performance Optimization

#### Build Cache

Use BuildKit for faster builds:

```bash
export DOCKER_BUILDKIT=1
docker build --cache-from ghcr.io/technicalpickles/agentic-container:latest .
```

#### Image Size Optimization

```dockerfile
# Combine RUN commands to reduce layers
RUN apt-get update && apt-get install -y \
    package1 \
    package2 \
    && rm -rf /var/lib/apt/lists/*

# Use multi-stage builds for build dependencies
FROM ghcr.io/technicalpickles/agentic-container:latest AS builder
RUN install build dependencies...

FROM ghcr.io/technicalpickles/agentic-container:latest AS final
COPY --from=builder /built/artifacts /usr/local/
```

#### Faster Development Cycles

```yaml
# Use volume mounts for faster iteration
services:
  dev:
    image: ghcr.io/technicalpickles/agentic-container:latest
    volumes:
      - .:/workspace
      # Cache directories to persist between runs
      - python-packages:/home/agent/.cache/pip
      - node-modules:/workspace/node_modules

volumes:
  python-packages:
  node-modules:
```

### Debugging

#### Shell Access

```bash
# Get shell access to debug issues
docker run -it --rm \
  --entrypoint /bin/bash \
  ghcr.io/technicalpickles/agentic-container:dev

# Or override entrypoint in docker-compose
services:
  dev:
    entrypoint: ["/bin/bash"]
    command: ["--login"]
```

#### Inspect Image

```bash
# Check what's installed
docker run --rm ghcr.io/technicalpickles/agentic-container:latest mise list

# Check environment
docker run --rm ghcr.io/technicalpickles/agentic-container:latest env

# Check file system
docker run --rm ghcr.io/technicalpickles/agentic-container:latest ls -la /usr/local/bin/
```

#### Log Analysis

```bash
# View container logs
docker logs container-name

# Follow logs in real-time
docker logs -f container-name

# Check system logs
docker run --rm -v /var/log:/host/var/log ghcr.io/technicalpickles/agentic-container:latest \
  tail -f /host/var/log/syslog
```

---

For more specific use cases or advanced configuration, check the
[API Reference](API.md) or open an issue on GitHub.
