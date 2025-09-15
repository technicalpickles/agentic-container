# API Reference

This document provides detailed reference information for the agentic-container tooling and extension APIs.

## Table of Contents

- [Extension Scripts](#extension-scripts)
- [Docker Image Targets](#docker-image-targets)
- [Environment Variables](#environment-variables)
- [File Paths and Structure](#file-paths-and-structure)
- [GitHub Actions Reference](#github-actions-reference)

## Extension Scripts

### extend-image.sh

Interactive helper script for extending base images.

#### Syntax

```bash
extend-image.sh COMMAND [OPTIONS]
```

#### Commands

| Command | Description | Example |
|---------|-------------|---------|
| `init [BASE_IMAGE]` | Initialize new Dockerfile | `extend-image.sh init python` |
| `add-language LANG` | Add language runtime | `extend-image.sh add-language ruby@3.2` |
| `add-tool TOOL` | Add development tool | `extend-image.sh add-tool gh` |
| `build [TAG]` | Build extended image | `extend-image.sh build my-image:v1.0` |
| `push [TAG]` | Push to registry | `extend-image.sh push my-image:v1.0` |
| `help` | Show help message | `extend-image.sh help` |

#### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BASE_REGISTRY` | Registry for base images | `ghcr.io/your-repo/agentic-container` |
| `DOCKER_BUILDKIT` | Enable BuildKit | `1` |

### publish-extended-image.sh

Automated script for creating and publishing custom images.

#### Syntax

```bash
publish-extended-image.sh [OPTIONS] BASE_IMAGE TARGET_REGISTRY/IMAGE:TAG
```

#### Options

| Option | Description | Example |
|--------|-------------|---------|
| `-l, --language LANG` | Add language runtime | `--language python@3.11` |
| `-t, --tool TOOL` | Add development tool | `--tool kubectl` |
| `-p, --package PKG` | Add system package | `--package postgresql-client` |
| `-f, --dockerfile FILE` | Use custom Dockerfile | `--dockerfile ./custom/Dockerfile` |
| `--template TEMPLATE` | Use predefined template | `--template python-ml` |
| `--platforms PLATFORMS` | Target platforms | `--platforms linux/amd64,linux/arm64` |
| `--push` | Push after building | `--push` |
| `--latest` | Also tag as latest | `--latest` |
| `--dry-run` | Show commands without executing | `--dry-run` |

#### Examples

```bash
# Python ML environment
publish-extended-image.sh \
  --template python-ml \
  --push \
  python \
  ghcr.io/myorg/python-ml:v1.0.0

# Custom Ruby environment
publish-extended-image.sh \
  --language ruby@3.2 \
  --tool gh \
  --package redis-tools \
  --push \
  base \
  ghcr.io/myorg/ruby-dev:latest
```

## Docker Image Targets

### Base Images

#### `base`
**Purpose**: Minimal foundation with core tools and mise  
**Size**: ~800MB  
**Includes**:
- Ubuntu 24.04 LTS
- Build tools (gcc, make, cmake)
- Core utilities (git, curl, jq, vim)
- Docker CLI + Docker Compose
- mise version manager
- Non-root user setup

**Use Case**: Starting point for minimal custom images

```dockerfile
FROM ghcr.io/your-repo/agentic-container:minimal
# Your minimal additions here
```

#### `tools`
**Purpose**: Enhanced development experience  
**Size**: ~850MB  
**Includes**: Everything from `base` plus:
- Starship shell prompt
- Configured shell environment
- Git configuration
- Development-friendly defaults

**Use Case**: Base for most custom development environments

```dockerfile
FROM ghcr.io/your-repo/agentic-container:standard
# Add your languages and tools
```

### Language-Specific Images

#### `ruby`
**Purpose**: Ruby development environment  
**Size**: ~1.2GB  
**Includes**: Everything from `tools` plus:
- Ruby 3.4.5 (configured globally)
- RubyGems package manager

#### `node`
**Purpose**: JavaScript/TypeScript development  
**Size**: ~1.1GB  
**Includes**: Everything from `tools` plus:
- Node.js 24.8.0 LTS (primary)
- Node.js 22.11.0 (secondary)
- npm package manager

#### `python`
**Purpose**: Python development environment  
**Size**: ~1.0GB  
**Includes**: Everything from `tools` plus:
- Python 3.13.7 (configured globally)
- pip package manager

#### `go`
**Purpose**: Go development environment  
**Size**: ~1.1GB  
**Includes**: Everything from `tools` plus:
- Go 1.25.1 (configured globally)
- Go module support

#### `dev` (latest)
**Purpose**: Full-featured development environment  
**Size**: ~2.2GB  
**Includes**: Everything from `tools` plus:
- All language runtimes (Ruby, Node.js, Python, Go)
- Lefthook git hooks manager
- All package managers

### Build Stages

Internal build stages (not published as images):

| Stage | Purpose |
|-------|---------|
| `ruby-stage` | Builds Ruby runtime |
| `node-stage` | Builds Node.js runtime |
| `python-stage` | Builds Python runtime |
| `go-stage` | Builds Go runtime |
| `lefthook-stage` | Builds Lefthook tool |

## Environment Variables

### Runtime Environment

| Variable | Description | Default | Scope |
|----------|-------------|---------|--------|
| `MISE_DATA_DIR` | Mise installation directory | `/usr/local/share/mise` | System |
| `MISE_CONFIG_DIR` | Mise configuration directory | `/etc/mise` | System |
| `MISE_CACHE_DIR` | Mise cache directory | `/tmp/mise-cache` | System |
| `USERNAME` | Non-root user name | `vscode` | Build-time |
| `USER_UID` | User ID | `1001` | Build-time |
| `USER_GID` | Group ID | `1001` | Build-time |
| `DEBIAN_FRONTEND` | Suppress interactive prompts | `noninteractive` | User shell |
| `TERM` | Terminal type | `xterm-256color` | User shell |
| `LANG` | System locale | `en_US.UTF-8` | User shell |
| `LC_ALL` | Locale override | `en_US.UTF-8` | User shell |

### Build-time ARGs

| Argument | Description | Default |
|----------|-------------|---------|
| `USERNAME` | Non-root user name | `vscode` |
| `USER_UID` | User ID | `1001` |
| `USER_GID` | Group ID | `1001` |

Override at build time:

```bash
docker build \
  --build-arg USERNAME=developer \
  --build-arg USER_UID=1000 \
  --build-arg USER_GID=1000 \
  -t my-custom-image .
```

## File Paths and Structure

### Directory Structure

```
/usr/local/
├── bin/
│   ├── mise              # Version manager binary
│   └── extend-image      # Extension helper script
└── share/
    └── mise/             # Mise data directory
        └── installs/     # Language installations
            ├── ruby/
            ├── node/
            ├── python/
            └── go/

/etc/
├── mise/                 # System-wide mise config
├── environment           # Environment variables
├── bash.bashrc          # System-wide bash config
└── profile              # System-wide profile

/home/vscode/             # Non-root user home
├── .bashrc              # User bash config
├── .bash_profile        # User bash profile
├── .profile             # User profile
└── .config/
    └── starship.toml    # Starship config (if created)

/workspace/               # Working directory
```

### Configuration Files

#### Mise Configuration

Global configuration at `/etc/mise/config.toml`:

```toml
# System-wide tool versions
[tools]
python = "3.13.7"
node = "24.8.0" 
ruby = "3.4.5"
go = "1.25.1"
lefthook = "latest"
```

Project-specific configuration at `/workspace/.tool-versions`:

```
python 3.11.0
node 20.0.0
ruby 3.2.0
```

#### Shell Configuration

The images include pre-configured shell environments:

```bash
# Added to ~/.bashrc
eval "$(mise activate bash)"
eval "$(starship init bash)"
export DEBIAN_FRONTEND=noninteractive
export TERM=xterm-256color
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

## GitHub Actions Reference

### Workflow Events

The included workflow responds to these events:

| Event | Trigger | Purpose |
|-------|---------|---------|
| `push` | Main/develop branches | Build and publish |
| `push` | Version tags (`v*`) | Release builds |
| `pull_request` | To main branch | Test builds |
| `schedule` | Weekly (Sunday 2 AM UTC) | Security updates |

### Workflow Outputs

| Output | Description | Example |
|--------|-------------|---------|
| Tags | Generated image tags | `latest`, `v1.0.0`, `main-abc123` |
| Platforms | Target architectures | `linux/amd64`, `linux/arm64` |
| Cache | Build cache status | Hit/miss rates |

### Matrix Strategy

The workflow builds multiple targets in parallel:

```yaml
strategy:
  matrix:
    target: [minimal, standard, dev, ruby, node, python, go]
```

Each target gets its own set of tags based on the target name.

### Registry Authentication

Uses GitHub's built-in `GITHUB_TOKEN` for authentication:

```yaml
- name: Log in to Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

### Custom Workflows

For custom images, you can override the workflow:

```yaml
# Custom matrix for your specific images
strategy:
  matrix:
    include:
      - dockerfile: ./custom/Dockerfile.ml
        image-suffix: -ml
        platforms: linux/amd64,linux/arm64
      - dockerfile: ./custom/Dockerfile.web  
        image-suffix: -web
        platforms: linux/amd64
```

---

For implementation examples, see the [Usage Guide](USAGE.md). For contributing, see [CONTRIBUTING.md](CONTRIBUTING.md).
