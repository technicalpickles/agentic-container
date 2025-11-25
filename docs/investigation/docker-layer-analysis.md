# Docker Image Layer Analysis Report

**Generated on:** September 14, 2025 **Image:** `agentic-container:standard`
**Total Image Size:** 897.7 MB (~898 MB) **Analysis Tool:** `dive v0.13.1`

## Executive Summary

This analysis identifies the largest layers in our agentic-container Docker
image and provides actionable optimization strategies. The image currently
totals **897.7 MB**, with the top 4 layers accounting for **880 MB (98%)** of
the total size.

## Layer Analysis

### Top 5 Largest Layers

| Layer Index | Size (MB) | Size (Bytes) | Files  | Purpose                       |
| ----------- | --------- | ------------ | ------ | ----------------------------- |
| 1           | 515.0 MB  | 514,930,427  | 15,571 | Build tools & system packages |
| 4           | 193.1 MB  | 193,109,401  | 48     | Docker CLI & Compose          |
| 0           | 100.7 MB  | 100,710,794  | 3,440  | Ubuntu 24.04 base layer       |
| 5           | 71.6 MB   | 71,603,840   | 20     | Mise version manager          |
| 12          | 14.2 MB   | 14,211,354   | N/A    | Starship prompt               |

### Detailed Layer Breakdown

#### Layer 1: Build Tools & System Packages (515 MB)

**Command:** `apt-get install build-essential cmake git curl ...`

**Largest Files:**

- `libicudata.so.74.2`: 30.8 MB - ICU data library
- `cc1plus`: 28.9 MB - C++ compiler backend
- `cc1`: 26.8 MB - C compiler backend
- `lto1`: 25.6 MB - Link-time optimization
- `ctest`: 11.8 MB - CMake testing tool
- `cmake`: 10.5 MB - Build system generator

**Analysis:** This layer contains the complete GNU compiler collection (GCC),
CMake, and various development libraries. While necessary for compilation, many
components may not be needed in runtime environments.

#### Layer 4: Docker CLI & Compose (193 MB)

**Command:** `apt-get install docker-ce-cli docker-compose-plugin`

**Largest Files:**

- `docker-buildx`: 75.3 MB - Docker BuildKit plugin
- `docker-compose`: 73.6 MB - Docker Compose plugin
- `docker`: 43.2 MB - Docker CLI binary

**Analysis:** Docker tools are essential for our container-in-container
workflows but represent a significant size investment.

#### Layer 5: Mise Version Manager (72 MB)

**Command:** `curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh`

**Largest Files:**

- `mise`: 51.8 MB - Mise binary
- `mise-v2025.9.10-linux-arm64.tar.gz`: 19.8 MB - Downloaded archive (leftover)

**Analysis:** Mise is a Rust-based tool that's quite large. The temporary
archive wasn't cleaned up during installation.

## Optimization Strategies

### High Impact (Immediate Wins)

#### 1. Multi-stage Build Optimization 🎯

**Potential Savings: 200-300 MB**

Create separate build and runtime stages:

```dockerfile
# Build stage - contains heavy build tools
FROM minimal AS builder
RUN apt-get update && apt-get install -y build-essential cmake
# ... build operations ...

# Runtime stage - lightweight
FROM minimal AS runtime
COPY --from=builder /built/artifacts /usr/local/bin/
# Only install runtime dependencies
```

#### 2. Docker CLI Optimization 🎯

**Potential Savings: 75-150 MB**

- **Option A:** Use official Docker CLI image in multi-stage build
- **Option B:** Download specific Docker CLI version (smaller than full package)
- **Option C:** Make Docker CLI optional via build argument

```dockerfile
ARG INCLUDE_DOCKER=true
RUN if [ "$INCLUDE_DOCKER" = "true" ]; then \
    curl -fsSL https://download.docker.com/linux/static/stable/$(arch)/docker-20.10.x-$(arch).tgz | \
    tar xzvf - --strip 1 -C /usr/local/bin docker/docker; \
    fi
```

#### 3. Mise Installation Cleanup 🎯

**Potential Savings: 20 MB**

Clean up temporary files after mise installation:

```dockerfile
RUN curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && rm -rf /tmp/tmp.* \
    && rm -rf /root/.cache/mise
```

### Medium Impact

#### 4. Selective Package Installation

**Potential Savings: 50-100 MB**

Replace broad package groups with specific packages:

```dockerfile
# Instead of build-essential (185MB), install only what's needed:
RUN apt-get install -y \
    gcc g++ make \
    # Remove: libc6-dev binutils dpkg-dev if not needed
```

#### 5. Language Runtime Optimization

**Potential Savings: Varies by language**

- Use Alpine-based variants where possible
- Install only required language versions
- Use mise's selective installation features

#### 6. Layer Consolidation

**Potential Savings: 5-15 MB**

Combine related RUN commands to reduce layer overhead:

```dockerfile
RUN apt-get update && apt-get install -y package1 package2 \
    && curl -o tool https://example.com/tool \
    && chmod +x tool \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

### Low Impact (Long-term)

#### 7. Base Image Alternatives

- **distroless** for runtime images (much smaller)
- **Alpine Linux** base (~5MB vs 101MB)
- **Ubuntu minimal** variants

#### 8. Build Cache Optimization

- Use BuildKit cache mounts for package managers
- Leverage Docker build cache effectively

## Recommended Implementation Plan

### Phase 1: Quick Wins (Target: -100MB)

1. ✅ Clean up mise installation temporary files
2. ✅ Consolidate apt commands and clean package cache
3. ✅ Make Docker CLI installation conditional

### Phase 2: Architecture Changes (Target: -200MB)

1. 🔄 Implement multi-stage builds for build vs runtime separation
2. 🔄 Create language-specific variants with only needed tools
3. 🔄 Optimize package selections

### Phase 3: Advanced Optimizations (Target: -100MB)

1. 🔄 Evaluate Alpine base image migration
2. 🔄 Implement distroless runtime images
3. 🔄 Advanced BuildKit caching strategies

## Monitoring & Validation

- **Target Size:** Reduce from 898MB to ~400-500MB (-40-45%)
- **Validation:** Use `dive` for each optimization iteration
- **Performance:** Monitor build time impact
- **Functionality:** Ensure all development tools remain functional

## Implementation Notes

- Test each optimization in isolation first
- Maintain separate tracks for different use cases (full-dev vs runtime)
- Consider using `.dockerignore` to prevent unnecessary context copying
- Document any compatibility changes for users

---

**Next Steps:** Begin with Phase 1 optimizations and measure impact before
proceeding to architectural changes.
