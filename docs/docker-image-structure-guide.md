# Docker Image Structure Guide

**Created**: 2024-09-15
**Purpose**: Reference guide for contributors modifying the agentic-container
Dockerfile
**Scope**: Docker layer optimization, multi-stage builds, and best practices

## Overview

This document outlines the architectural decisions, layer optimization
strategies, and best practices used in the agentic-container Docker image.
Understanding these patterns is crucial for anyone modifying the Dockerfile to
ensure optimal build times, image size, and maintainability.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Multi-Stage Build Strategy](#multi-stage-build-strategy)
- [Layer Optimization Principles](#layer-optimization-principles)
- [Copying Patterns](#copying-patterns)
- [Environment Management](#environment-management)
- [Build Arguments and Version Management](#build-arguments-and-version-management)
- [Best Practices](#best-practices)
- [Common Anti-Patterns](#common-anti-patterns)
- [Troubleshooting](#troubleshooting)

## Architecture Overview

Our Dockerfile uses a sophisticated multi-stage build approach with the
following structure:

```
├── builder (FROM ubuntu:24.04)          # Build dependencies + common tools
├── ruby-stage (FROM builder)            # Ruby runtime compilation
├── go-stage (FROM builder)              # Go installation
├── lefthook-stage (FROM builder)        # Git hooks tooling
├── standard (FROM ubuntu:24.04)         # Main maintained image
└── dev (FROM standard)                  # Kitchen sink example
```

### Design Philosophy

1. **Parallel builds**: Language-specific stages enable parallel compilation
2. **Layer reuse**: Common tools installed once in builder, copied to final
   stages
3. **Minimal final image**: Only runtime dependencies in the final standard
   image
4. **Selective copying**: Only necessary artifacts from build stages

## Multi-Stage Build Strategy

### Builder Stage Pattern

```dockerfile
FROM ubuntu:24.04 AS builder

# Install build dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    curl \
    ca-certificates \
    # ... other build tools
    && rm -rf /var/lib/apt/lists/*

# Install commonly used languages
RUN mise install node@latest \
    && mise install python@latest
```

**Why this works:**

- Build dependencies are isolated from the final image
- Common languages installed once, shared across language-specific stages
- Parallel language stages can reference the same base builder

### Language-Specific Stages

```dockerfile
FROM builder AS ruby-stage
RUN rv ruby install --install-dir $MISE_DATA_DIR/installs/ruby/ ruby-3.4.5

FROM builder AS go-stage
RUN mise install go@latest

FROM builder AS lefthook-stage
RUN mise install lefthook@latest
```

**Benefits:**

- **Parallelization**: Docker can build these stages concurrently
- **Specialization**: Each stage focuses on one runtime
- **Layer caching**: Changes to one language don't invalidate others
- **Build efficiency**: Only rebuild what changed

### Final Stage Assembly

```dockerfile
FROM ubuntu:24.04 AS standard

# Install only runtime packages (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates vim jq \
    && rm -rf /var/lib/apt/lists/*

# Copy pre-compiled tools from build stages
COPY --from=builder /usr/local/bin/mise /usr/local/bin/mise
COPY --from=builder $MISE_DATA_DIR/installs/node $MISE_DATA_DIR/installs/node
COPY --from=ruby-stage $MISE_DATA_DIR/installs/ruby $MISE_DATA_DIR/installs/ruby
```

## Layer Optimization Principles

### 1. Combine Related Operations

```dockerfile
# ✅ GOOD: Single layer for related package installation
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    vim \
    && rm -rf /var/lib/apt/lists/*

# ❌ BAD: Multiple layers for related operations
RUN apt-get update
RUN apt-get install -y git
RUN apt-get install -y curl
RUN apt-get install -y vim
```

**Impact**: The bad approach creates 4 layers (~40MB each), while good creates 1
layer (~120MB total).

### 2. Strategic Layer Separation

```dockerfile
# ✅ GOOD: Separate frequently-changing from stable operations
RUN apt-get update && apt-get install -y system-packages \
    && rm -rf /var/lib/apt/lists/*

# Separate layer for version-specific tools (changes more often)
RUN mise install node@latest python@latest

# Separate layer for user configuration (changes frequently)
RUN useradd -m agent && usermod -aG docker agent
```

**Why**: Stable system packages are cached longer, while version updates only
invalidate specific layers.

### 3. Order Dependencies by Change Frequency

```dockerfile
# System packages (rarely change) - early in Dockerfile
RUN apt-get update && apt-get install -y base-packages

# Language runtimes (monthly updates) - middle
RUN mise install node@latest python@latest

# Application code (frequent changes) - late in Dockerfile
COPY . /app
```

## Copying Patterns

### Selective Artifact Copying

Our approach prioritizes copying only necessary artifacts:

```dockerfile
# ✅ GOOD: Copy only the installed runtime
COPY --from=builder $MISE_DATA_DIR/installs/node $MISE_DATA_DIR/installs/node
COPY --from=builder $MISE_DATA_DIR/installs/python $MISE_DATA_DIR/installs/python

# ❌ BAD: Copy entire builder stage
COPY --from=builder / /
```

### Directory Structure Preservation

```dockerfile
# Preserve mise directory structure for proper tool discovery
COPY --from=builder $MISE_DATA_DIR/installs/node $MISE_DATA_DIR/installs/node
```

**Critical**: The destination path must match the source path for mise to locate
tools correctly.

### Binary vs Runtime Copying

```dockerfile
# Copy standalone binaries
COPY --from=builder /usr/local/bin/mise /usr/local/bin/mise
COPY --from=builder /usr/local/bin/rv /usr/local/bin/rv

# Copy complete runtime directories (includes dependencies)
COPY --from=builder $MISE_DATA_DIR/installs/node $MISE_DATA_DIR/installs/node
```

## Environment Management

### Global Environment Configuration

```dockerfile
# Set mise environment for consistent paths across stages
ENV MISE_DATA_DIR=/usr/local/share/mise
ENV MISE_CONFIG_DIR=/etc/mise
ENV MISE_CACHE_DIR=/tmp/mise-cache
ENV PATH="/usr/local/share/mise/shims:${PATH}"
```

**Design decision**: Global paths enable consistent tool access without
activation.

### User-Specific vs System-Wide

```dockerfile
# System-wide configuration (accessible to all users)
RUN echo 'export PATH="/usr/local/share/mise/shims:$PATH"' >> /etc/bash.bashrc
RUN echo 'eval "$(mise activate bash)"' >> /etc/bash.bashrc

# User-specific enhancements
RUN echo 'eval "$(starship init bash)"' >> /home/$USERNAME/.bashrc
```

### Permission Strategy

```dockerfile
# Create mise group for shared access
RUN groupadd --gid 2000 mise \
    && usermod -aG mise root

# Set group permissions on directories
RUN chgrp -R mise $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    && chmod -R g+ws $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR
```

**Why**: Enables both root and agent users to install packages without
permission conflicts.

## Build Arguments and Version Management

### ARG Inheritance Pattern

Our Dockerfile uses a global ARG declaration with inheritance pattern to manage
language versions and tool versions across multiple build stages:

```dockerfile
# Global ARGs with default values (defined once at the top)
ARG NODE_VERSION=24.8.0
ARG PYTHON_VERSION=3.13.7
ARG RUBY_VERSION=3.4.5
ARG GO_VERSION=1.25.1
ARG AST_GREP_VERSION=0.39.5
ARG LEFTHOOK_VERSION=1.13.0
ARG UV_VERSION=0.8.17

FROM ubuntu:24.04 AS builder
# Re-declare ARGs needed in this stage (inherit from global)
ARG NODE_VERSION
ARG PYTHON_VERSION
RUN mise install node@${NODE_VERSION} && mise install python@${PYTHON_VERSION}

FROM builder AS ruby-stage
# Re-declare ARG for this stage (inherit from global)
ARG RUBY_VERSION
RUN rv ruby install --install-dir $MISE_DATA_DIR/installs/ruby/ ruby-${RUBY_VERSION}
```

### Why This Pattern

**❌ Alternative: Duplicate Defaults**

```dockerfile
# Duplicated defaults in each stage (anti-pattern)
ARG NODE_VERSION=24.8.0  # Global

FROM ubuntu:24.04 AS builder
ARG NODE_VERSION=24.8.0  # Duplicated default

FROM builder AS ruby-stage
ARG RUBY_VERSION=3.4.5   # Duplicated default
```

**✅ Our Approach: Single Source of Truth**

```dockerfile
# Default values defined once at the top
ARG NODE_VERSION=24.8.0  # Global default only

FROM ubuntu:24.04 AS builder
ARG NODE_VERSION          # Inherit from global (no duplication)

FROM builder AS ruby-stage
ARG RUBY_VERSION          # Inherit from global (no duplication)
```

### Benefits

1. **DRY Principle**: Default versions defined once at the top of the Dockerfile
2. **Consistency**: All stages use the same version unless explicitly overridden
3. **Maintainability**: Update a version in one place, affects all stages
4. **Propagation**: `--build-arg` overrides apply to all stages that declare the
   ARG
5. **Self-Documentation**: Each stage clearly declares which ARGs it depends on

### Usage Examples

```bash
# Use global defaults (versions from ARG declarations)
docker build -t agentic-container .

# Override specific versions (propagates to all relevant stages)
docker build \
  --build-arg NODE_VERSION=20.0.0 \
  --build-arg RUBY_VERSION=3.3.0 \
  -t agentic-container .

# Override in CI/CD pipeline
- name: Build with custom versions
  uses: docker/build-push-action@v5
  with:
    build-args: |
      NODE_VERSION=22.0.0
      PYTHON_VERSION=3.11.0
```

### ARG Scope Rules

**Critical**: Docker ARG values don't automatically carry over between `FROM`
statements. Each stage must re-declare the ARGs it needs:

```dockerfile
# ❌ WRONG: ARG not available in new stage
ARG NODE_VERSION=24.8.0
FROM ubuntu:24.04 AS builder
RUN mise install node@${NODE_VERSION}  # ERROR: NODE_VERSION is empty

# ✅ CORRECT: Re-declare ARG in each stage
ARG NODE_VERSION=24.8.0
FROM ubuntu:24.04 AS builder
ARG NODE_VERSION  # Re-declare to inherit value
RUN mise install node@${NODE_VERSION}  # Works correctly
```

### Version Update Strategy

1. **Monthly Review**: Check for new stable versions of language runtimes
2. **Security Updates**: Update immediately for security patches
3. **Testing**: Validate version updates don't break examples or functionality
4. **Documentation**: Update this guide when version strategies change

```bash
# Check current versions available in mise
mise ls-remote node | tail -5
mise ls-remote python | tail -5
mise ls-remote ruby | tail -5
mise ls-remote go | tail -5
```

### Integration with CI/CD

Our GitHub Actions workflow can override versions for testing or specific
builds:

```yaml
- name: Build with specific versions
  uses: docker/build-push-action@v5
  with:
    build-args: |
      NODE_VERSION=${{ matrix.node-version }}
      PYTHON_VERSION=${{ matrix.python-version }}
```

This pattern enables:

- **Matrix builds**: Test multiple language version combinations
- **Pinned releases**: Lock specific versions for stable releases
- **Development builds**: Use bleeding-edge versions for testing

## Best Practices

### 1. Package Manager Cleanup

```dockerfile
# ✅ GOOD: Clean up package manager caches
RUN apt-get update && apt-get install -y packages \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# ✅ GOOD: Python packages without cache
RUN pip install --no-cache-dir package1 package2

# ✅ GOOD: Node.js global packages
RUN npm install -g package1 package2
```

### 2. Documentation and File Cleanup

```dockerfile
# Aggressive cleanup for production images
RUN find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true \
    && find /usr/share/doc -depth -type f ! -name copyright -delete 2>/dev/null || true \
    && rm -rf /usr/share/man/* /usr/share/groff/* /usr/share/info/*
```

**Impact**: Can reduce image size by 50-100MB.

### 3. Multi-Line RUN Organization

```dockerfile
# ✅ GOOD: Logical grouping with comments
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core system tools
    git \
    curl \
    ca-certificates \
    # Development tools
    vim \
    nano \
    jq \
    # Process management
    dumb-init \
    sudo \
    && rm -rf /var/lib/apt/lists/*
```

### 4. Version Pinning Strategy

```dockerfile
# ✅ GOOD: Pin base image versions
FROM ubuntu:24.04 AS builder

# ✅ GOOD: Use ARG-based versioning for flexibility
ARG NODE_VERSION=24.8.0
ARG PYTHON_VERSION=3.13.7
ARG RUBY_VERSION=3.4.5

# Re-declare in each stage
ARG NODE_VERSION
ARG PYTHON_VERSION
ARG RUBY_VERSION

RUN mise install node@${NODE_VERSION} python@${PYTHON_VERSION}
RUN rv ruby install ruby-${RUBY_VERSION}
```

**Benefits of ARG-based versioning:**

- **Flexibility**: Override versions at build time without editing Dockerfile
- **Consistency**: Same version used across all stages
- **CI/CD Integration**: Easy to test different version combinations
- **Maintenance**: Update versions in one place

### 5. Build Context Optimization

```dockerfile
# Use .dockerignore to exclude unnecessary files
# .dockerignore contents:
# .git
# node_modules
# *.log
# docs/
```

## Common Anti-Patterns

### 1. Unnecessary Layer Creation

```dockerfile
# ❌ BAD: Each RUN creates a layer
RUN apt-get update
RUN apt-get install -y git
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*

# ✅ GOOD: Single optimized layer
RUN apt-get update && apt-get install -y git curl \
    && rm -rf /var/lib/apt/lists/*
```

### 2. Missing Cache Cleanup

```dockerfile
# ❌ BAD: Leaves large cache files
RUN apt-get update && apt-get install -y packages

# ❌ BAD: Cleanup in separate layer doesn't help image size
RUN rm -rf /var/lib/apt/lists/*

# ✅ GOOD: Cleanup in same layer
RUN apt-get update && apt-get install -y packages \
    && rm -rf /var/lib/apt/lists/*
```

### 3. Inefficient Copying

```dockerfile
# ❌ BAD: Copy entire build context
COPY . /app

# ❌ BAD: Copy unnecessary build artifacts
COPY --from=builder / /

# ✅ GOOD: Copy only what's needed
COPY --from=builder /usr/local/bin/mise /usr/local/bin/mise
COPY --from=builder $MISE_DATA_DIR/installs/node $MISE_DATA_DIR/installs/node
```

### 4. Poor Layer Ordering

```dockerfile
# ❌ BAD: Frequently changing steps early in Dockerfile
COPY package.json /app/
RUN apt-get update && apt-get install -y system-packages

# ✅ GOOD: Stable operations first
RUN apt-get update && apt-get install -y system-packages
COPY package.json /app/
```

### 5. ARG Scope Violations

```dockerfile
# ❌ BAD: ARG not re-declared in stage (causes empty variables)
ARG NODE_VERSION=24.8.0

FROM ubuntu:24.04 AS builder
RUN mise install node@${NODE_VERSION}  # ERROR: NODE_VERSION is empty

# ❌ BAD: Duplicating default values in every stage
ARG NODE_VERSION=24.8.0
FROM ubuntu:24.04 AS builder
ARG NODE_VERSION=24.8.0  # Duplicated default (maintenance burden)

# ✅ GOOD: ARG inheritance pattern
ARG NODE_VERSION=24.8.0  # Global default
FROM ubuntu:24.04 AS builder
ARG NODE_VERSION          # Inherit from global
RUN mise install node@${NODE_VERSION}  # Works correctly
```

### 6. Missing User Security

```dockerfile
# ❌ BAD: Running as root in final image
USER root
WORKDIR /app

# ✅ GOOD: Non-root user for security
USER $USERNAME
WORKDIR /workspace
```

## Extension Guidelines

### For Language Additions

When adding a new language to the build:

1. **Create a dedicated build stage** if compilation is needed:

   ```dockerfile
   FROM builder AS newlang-stage
   RUN mise install newlang@latest
   ```

2. **Copy to appropriate final stages**:

   ```dockerfile
   FROM standard AS enhanced
   COPY --from=newlang-stage $MISE_DATA_DIR/installs/newlang $MISE_DATA_DIR/installs/newlang
   ```

3. **Update global configuration**:
   ```dockerfile
   RUN mise use -g newlang@latest
   ```

### For System Package Additions

1. **Add to existing RUN statements** when possible:

   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends \
       existing-package \
       new-package \
       && rm -rf /var/lib/apt/lists/*
   ```

2. **Group by purpose** for maintainability:
   ```dockerfile
   # Development tools
   vim nano less jq \
   # Network tools
   curl wget netcat-traditional
   ```

### For Tool Additions

1. **Choose the appropriate installation method**:
   - `mise` for language runtimes and many tools
   - `apt-get` for system packages
   - Direct download for standalone binaries
   - Language package managers (pip, npm, gem) for libraries

2. **Consider build vs runtime stages**:
   - Install in builder if compilation needed
   - Install in final stage if pre-compiled

## Troubleshooting

### Build Performance Issues

**Symptom**: Slow builds or frequent cache invalidation

**Solutions**:

- Review layer ordering - put stable operations first
- Check .dockerignore - exclude unnecessary files
- Use build-time cache mounts for package managers:
  ```dockerfile
  RUN --mount=type=cache,target=/var/cache/apt \
      apt-get update && apt-get install -y packages
  ```

### Size Issues

**Symptom**: Image size larger than expected

**Investigation**:

```bash
# Analyze layer sizes
docker history ghcr.io/technicalpickles/agentic-container:latest

# Find large files
docker run --rm -it image find / -size +100M -ls
```

**Solutions**:

- Add missing cache cleanup
- Remove unnecessary files in same layer
- Use multi-stage builds to exclude build dependencies

### Runtime Issues

**Symptom**: Tools not found or permission errors

**Solutions**:

- Verify PATH includes mise shims
- Check file permissions on mise directories
- Ensure user is in mise group
- Validate environment variables are set

### Build Failures

**Common causes and solutions**:

1. **Package not found**: Update package lists first

   ```dockerfile
   RUN apt-get update && apt-get install -y package
   ```

2. **Permission denied**: Check user context

   ```dockerfile
   USER root    # For system changes
   USER $USERNAME  # For user-specific operations
   ```

3. **Tool not available**: Verify mise activation

   ```dockerfile
   RUN eval "$(mise activate bash)" && command
   ```

4. **ARG variable is empty**: Re-declare ARG in each stage that uses it

   ```dockerfile
   # ❌ This fails - ARG not available in new stage
   ARG NODE_VERSION=24.8.0
   FROM ubuntu:24.04 AS builder
   RUN mise install node@${NODE_VERSION}  # NODE_VERSION is empty

   # ✅ This works - ARG re-declared
   ARG NODE_VERSION=24.8.0
   FROM ubuntu:24.04 AS builder
   ARG NODE_VERSION  # Re-declare to inherit value
   RUN mise install node@${NODE_VERSION}  # Works correctly
   ```

## Contributing Guidelines

### Before Modifying the Dockerfile

1. **Understand the impact**: Consider which layers your changes will affect
2. **Test locally**: Build and test the image thoroughly
3. **Check size impact**: Use `docker images` to verify size changes
4. **Validate examples**: Ensure extension examples still work

### Making Changes

1. **Follow existing patterns**: Use the established RUN statement structure
2. **Update related documentation**: Keep this guide and examples in sync
3. **Consider backwards compatibility**: Avoid breaking existing extension
   patterns
4. **Test multi-architecture**: Verify changes work on both amd64 and arm64

### Pull Request Guidelines

1. **Explain the rationale**: Why is this change needed?
2. **Document size impact**: Include before/after image sizes
3. **Provide test cases**: Show how to verify the change works
4. **Update examples**: If needed, update extension examples

## References

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Multi-stage Build Documentation](https://docs.docker.com/build/building/multi-stage/)
- [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)
- [mise Documentation](https://mise.jdx.dev/)

---

**Last Updated**: 2024-09-16
**Next Review**: When major Dockerfile changes are made
**Maintainer**: Review this guide when contributing to the Dockerfile

**Recent Changes**:

- Added comprehensive ARG inheritance pattern documentation
- Documented Docker ARG scope rules and troubleshooting
