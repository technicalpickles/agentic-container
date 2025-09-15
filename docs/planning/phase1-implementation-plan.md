# Phase 1 Implementation Plan: Minimal Image Optimization

**Created**: 2025-01-15  
**Status**: Implementation Ready  
**Target**: Reduce minimal image from ~800MB to ~500MB (-37% reduction)

## Phase 1 Review and Analysis

### Current State Analysis
From the existing Dockerfile structure:
- **`base`**: Ubuntu 24.04 + system packages + mise + Docker CLI (~800MB estimated)
- **`tools`**: base + starship + dev enhancements (~850MB estimated) 
- **Language variants**: tools + single language runtime (~1GB+ estimated)
- **`dev`**: tools + all languages (~2.2GB estimated)

### Phase 1 Optimization Goals
1. **Package Installation Optimization**: Use `--no-install-recommends`, aggressive cleanup
2. **Multi-Stage Build Optimization**: Separate build dependencies from runtime
3. **Layer Consolidation**: Minimize intermediate layers
4. **Mise Configuration Optimization**: Pre-configure directories, optimize cache placement

## Implementation Steps

### Step 1: Create Optimized Minimal Stage

#### 1.1 Analyze Current Package Installation
Current base stage installs packages without optimization:
```dockerfile
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    # ... many packages
```

**Optimization Strategy**:
- Use `--no-install-recommends` to avoid unnecessary packages
- Combine installation and cleanup in single RUN command
- Remove package caches, docs, and temporary files
- Strip unnecessary build tools from runtime

#### 1.2 Package Categorization

**Essential Runtime Packages** (keep in minimal):
```bash
# Core system tools
git curl ca-certificates gnupg lsb-release
# Essential CLI tools  
vim nano less jq unzip zip
# Process management
dumb-init sudo procps
# Locale support
locales
```

**Development Build Tools** (move to multi-stage builder):
```bash 
# Can be installed in builder stage and removed
build-essential cmake
# Optional development tools
tree htop
# Networking tools (optional)
iputils-ping netcat-traditional telnet
```

**Docker CLI** (optimized installation):
- Keep Docker CLI but optimize GPG key handling
- Use streamlined installation process

#### 1.3 New Minimal Stage Structure

```dockerfile
# Build stage for tools that need compilation
FROM ubuntu:24.04 AS builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install mise in builder stage
RUN curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# Runtime minimal stage
FROM ubuntu:24.04 AS minimal
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates gnupg lsb-release \
    vim nano less jq unzip zip \
    dumb-init sudo procps locales \
    # Docker CLI installation
    && mkdir -m 0755 -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    # Generate locales
    && locale-gen en_US.UTF-8 \
    # Aggressive cleanup
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* /var/tmp/* \
    && find /var/log -type f -exec truncate -s 0 {} \; \
    && find /usr/share/doc -type f -delete \
    && find /usr/share/man -type f -delete
    
# Copy mise from builder
COPY --from=builder /usr/local/bin/mise /usr/local/bin/mise

# Optimized mise setup
ENV MISE_DATA_DIR=/usr/local/share/mise
ENV MISE_CONFIG_DIR=/etc/mise  
ENV MISE_CACHE_DIR=/tmp/mise-cache

RUN mkdir -p $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    && chmod 755 $MISE_DATA_DIR $MISE_CONFIG_DIR \
    && echo 'export MISE_DATA_DIR=/usr/local/share/mise' >> /etc/environment \
    && echo 'export MISE_CONFIG_DIR=/etc/mise' >> /etc/environment \
    && echo 'export MISE_CACHE_DIR=/tmp/mise-cache' >> /etc/environment \
    && echo 'eval "$(mise activate bash)"' >> /etc/bash.bashrc \
    && echo 'eval "$(mise activate bash)"' >> /etc/profile

# Create user (minimal user setup)
ARG USERNAME=agent
ARG USER_UID=1001
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && (groupadd docker 2>/dev/null || true) \
    && usermod -aG docker $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && mkdir -p /workspace && chown $USERNAME:$USERNAME /workspace

# Copy extension script
COPY scripts/extend-image.sh /usr/local/bin/extend-image
RUN chmod +x /usr/local/bin/extend-image
```

### Step 2: Update Build Stages to use Minimal

#### 2.1 Update Standard Stage
```dockerfile
FROM minimal AS standard
# Add starship and enhanced development experience
RUN curl -sS https://starship.rs/install.sh | FORCE=true sh \
    && echo 'eval "$(starship init bash)"' >> /etc/bash.bashrc \
    # Add development tools that were removed from minimal
    && apt-get update && apt-get install -y --no-install-recommends \
        tree htop iputils-ping netcat-traditional telnet \
    && apt-get autoremove -y && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/*

# Enhanced shell setup for user
RUN echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.bashrc && \
    echo 'eval "$(starship init bash)"' >> /home/$USERNAME/.bashrc && \
    echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.bash_profile && \
    echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.profile

# Environment setup
RUN echo 'export DEBIAN_FRONTEND=noninteractive' >> /home/$USERNAME/.bashrc && \
    echo 'export TERM=xterm-256color' >> /home/$USERNAME/.bashrc && \
    echo 'export LANG=en_US.UTF-8' >> /home/$USERNAME/.bashrc && \
    echo 'export LC_ALL=en_US.UTF-8' >> /home/$USERNAME/.bashrc

USER $USERNAME

# Git configuration
RUN git config --global --add safe.directory /workspace && \
    git config --global --add safe.directory '*' && \
    git config --global init.defaultBranch main && \
    git config --global pull.rebase false && \
    git config --global core.autocrlf input

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/bin/bash", "--login"]
```

#### 2.2 Update Language Variants
Change all language variants to build from `standard` instead of `tools`:
```dockerfile
FROM standard AS ruby
COPY --from=ruby-stage $MISE_DATA_DIR/installs/ruby $MISE_DATA_DIR/installs/ruby
RUN mise use -g ruby@3.4.5

FROM standard AS node
COPY --from=node-stage $MISE_DATA_DIR/installs/node $MISE_DATA_DIR/installs/node  
RUN mise use -g node@24.8.0

# etc.
```

### Step 3: Update GitHub Actions

#### 3.1 Add Minimal to Build Matrix
```yaml
strategy:
  matrix:
    target: [minimal, standard, dev, ruby, node, python, go]  # removed base, tools
    include:
      - target: minimal
        platforms: linux/amd64,linux/arm64
        tags: |
          type=ref,event=branch,suffix=-minimal
          type=ref,event=pr,suffix=-minimal
          type=semver,pattern={{version}},suffix=-minimal
          type=semver,pattern={{major}}.{{minor}},suffix=-minimal
          type=raw,value=minimal,enable={{is_default_branch}}
      - target: standard
        platforms: linux/amd64,linux/arm64
        tags: |
          type=ref,event=branch,suffix=-standard
          type=ref,event=pr,suffix=-standard
          type=semver,pattern={{version}},suffix=-standard
          type=semver,pattern={{major}}.{{minor}},suffix=-standard
          type=raw,value=standard,enable={{is_default_branch}}
          type=raw,value=latest,enable={{is_default_branch}}
```

### Step 4: Update Extension Script

#### 4.1 Update Help Text
```bash
BASE IMAGES:
    minimal               Core system tools, mise, Docker CLI only (~500MB)
    standard              Minimal + starship prompt and dev enhancements (~750MB)  
    ruby                  Standard + Ruby runtime
    node                  Standard + Node.js runtime
    python                Standard + Python runtime
    go                    Standard + Go runtime  
    dev                   All languages and tools (kitchen sink)
```

## Validation Steps

### Step 1: Build Size Validation

#### 1.1 Build and Measure Images
```bash
# Build all variants locally
docker build --target minimal -t agentic-container:minimal .
docker build --target standard -t agentic-container:standard .
docker build --target dev -t agentic-container:dev .

# Measure sizes
docker images agentic-container --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Expected results:
# REPOSITORY           TAG        SIZE
# agentic-container    minimal    ~500MB  (target: <550MB)
# agentic-container    standard   ~750MB  (target: <800MB)  
# agentic-container    dev        ~2.0GB  (target: <2.2GB)
```

#### 1.2 Layer Analysis
```bash
# Analyze layers to identify optimization opportunities
docker history agentic-container:minimal --no-trunc
dive agentic-container:minimal
```

### Step 2: Functionality Validation

#### 2.1 Core Tools Testing
```bash
# Test minimal image
docker run --rm agentic-container:minimal bash -c '
    set -e
    echo "=== Testing Core Tools ==="
    git --version
    curl --version
    docker --version
    mise --version
    jq --version
    
    echo "=== Testing Mise Setup ==="
    mise list
    eval "$(mise activate bash)"
    
    echo "=== Testing User Setup ==="
    whoami
    sudo echo "sudo works"
    
    echo "=== Testing Extension Script ==="
    extend-image --help
'
```

#### 2.2 Extension Testing
```bash
# Test extending minimal image
echo 'FROM agentic-container:minimal
RUN mise install python@3.13
RUN mise use -g python@3.13' > test-extend.dockerfile

docker build -f test-extend.dockerfile -t test-minimal-extend .
docker run --rm test-minimal-extend python3 --version
```

#### 2.3 Development Workflow Testing
```bash
# Test standard image development workflow  
docker run --rm -v $(pwd):/workspace agentic-container:standard bash -c '
    set -e
    cd /workspace
    git status || git init
    starship --version
    echo "Development workflow test passed"
'
```

### Step 3: Performance Validation

#### 2.1 Image Pull Time Testing
```bash
# Clean docker images and test pull times
docker system prune -f
time docker pull agentic-container:minimal
time docker pull agentic-container:standard
```

#### 2.2 Container Start Time Testing
```bash
# Measure container startup times
time docker run --rm agentic-container:minimal echo "started"
time docker run --rm agentic-container:standard echo "started"
```

### Step 4: Regression Testing

#### 4.1 Existing Extension Examples
```bash
# Test all existing extension examples still work
cd docs/examples
for example in *.dockerfile; do
    echo "Testing $example"
    docker build -f $example -t test-example .
    docker run --rm test-example echo "Extension example $example works"
done
```

#### 4.2 Template Compatibility
```bash
# Test that templates still work with new minimal base
cd templates
for template in Dockerfile.*; do
    echo "Testing template $template"
    # Modify template to use minimal base and test build
    sed 's/FROM.*agentic-container.*/FROM agentic-container:minimal/' $template > test-$template
    docker build -f test-$template -t test-template .
done
```

## Success Criteria

### Primary Criteria (Must Pass)
- [ ] `minimal` image < 550MB (target: ~500MB)
- [ ] `standard` image < 800MB (target: ~750MB)  
- [ ] All core functionality preserved (git, docker, mise, basic tools)
- [ ] Extension mechanism works with new minimal base
- [ ] No regression in container startup time
- [ ] All existing examples and templates compatible

### Secondary Criteria (Should Pass)
- [ ] Image pull time reduced by 30%+ for minimal
- [ ] `dev` image size reduced to < 2.0GB
- [ ] Build time maintained or improved
- [ ] CI/CD pipeline builds successfully

### Documentation Criteria
- [ ] README updated with new image structure
- [ ] Extension examples updated for minimal base
- [ ] Migration guide provided for existing users
- [ ] Performance comparisons documented

## Rollback Plan

If validation fails:
1. Revert Dockerfile changes
2. Remove minimal from GitHub Actions matrix  
3. Keep existing `base` and `tools` stages as fallback
4. Document lessons learned for future optimization

## Next Steps After Phase 1

Upon successful completion:
1. Begin Phase 2: Language-specific optimization 
2. Create specialized use-case images
3. Implement advanced file system optimizations
4. Monitor real-world usage patterns and feedback

---

**Implementation Ready**: All steps documented, validation criteria defined, rollback plan established.
