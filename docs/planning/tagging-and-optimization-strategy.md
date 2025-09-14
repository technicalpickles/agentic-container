# Tagging and Size Optimization Strategy

**Created**: 2025-01-15  
**Status**: Planning  
**Scope**: Image tagging strategy and size optimization for agentic-container

## Overview

This document outlines the strategy for optimizing image sizes and implementing a coherent tagging strategy that balances functionality, size, and user experience while maintaining Ubuntu as the base OS.

## Current State Analysis

### Existing Images (Post-Restructure)
| Image | Estimated Size | Contents |
|-------|---------------|----------|
| `base` | ~800MB | Ubuntu + mise + Docker CLI + core tools |
| `tools` | ~850MB | Base + starship + dev enhancements |
| `ruby` | ~1.2GB | Tools + Ruby runtime |
| `node` | ~1.1GB | Tools + Node.js runtime |
| `python` | ~1.0GB | Tools + Python runtime |
| `go` | ~1.1GB | Tools + Go runtime |
| `dev` | ~2.2GB | All languages and tools |

### Size Breakdown (Estimated)
- Ubuntu 24.04 base: ~80MB
- System packages: ~200MB
- Mise + core tooling: ~100MB
- Docker CLI + Compose: ~50MB
- Development tools: ~100MB
- User setup + configs: ~20MB
- **Core foundation**: ~550MB

**Per Language Runtime:**
- Python 3.13.7: ~150MB
- Node.js 24.8.0: ~120MB
- Ruby 3.4.5: ~180MB
- Go 1.25.1: ~120MB
- Additional tools (lefthook, etc.): ~100MB

## Proposed Tagging Strategy

### Strategy: Size-Based Hierarchy with Use Cases

#### Core Tags
```
ghcr.io/your-repo/agentic-container:
├── minimal       (~600MB) - Core + mise only, optimized for extension
├── standard      (~800MB) - Current "tools", good developer experience  
├── full          (~2.2GB) - Current "dev", kitchen sink
└── latest        → points to "standard"
```

#### Language-Specific Tags  
```
├── minimal-python    (~750MB) - Minimal + Python only
├── minimal-node      (~700MB) - Minimal + Node only  
├── minimal-ruby      (~800MB) - Minimal + Ruby only
├── minimal-go        (~720MB) - Minimal + Go only
├── standard-python   (~900MB) - Standard + Python + common tools
├── standard-node     (~850MB) - Standard + Node + common tools
├── standard-ruby     (~950MB) - Standard + Ruby + common tools  
├── standard-go       (~870MB) - Standard + Go + common tools
```

#### Specialized Use Case Tags
```
├── web-dev       (~1.2GB) - Node + Python + web frameworks
├── data-science  (~1.1GB) - Python + R + Jupyter + basic ML
├── devops        (~1.0GB) - Go + Terraform + K8s tools
├── backend-dev   (~1.3GB) - Python + Node + Ruby + databases
```

### Tag Mapping Strategy

| User Need | Recommended Tag | Size | Rationale |
|-----------|----------------|------|-----------|
| Extend with custom languages | `minimal` | 600MB | Smallest foundation |
| General development | `standard` | 800MB | Good balance |
| Single language dev | `minimal-python` | 750MB | Optimized single stack |
| Quick prototyping | `standard-python` | 900MB | Ready to code |
| Everything included | `full` | 2.2GB | No setup needed |

## Size Optimization Plan

### Phase 1: Foundation Optimization (Target: -100MB from minimal)

#### 1.1 Package Installation Optimization
```dockerfile
# Current approach
RUN apt-get update && apt-get install -y packages

# Optimized approach  
RUN apt-get update && apt-get install -y --no-install-recommends \
    essential-packages \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* \
    && find /var/log -type f -exec truncate -s 0 {} \;
```

#### 1.2 Multi-Stage Build Optimization
```dockerfile
# Separate build dependencies from runtime
FROM ubuntu:24.04 AS builder
RUN apt-get update && apt-get install -y build-essential curl
RUN download and build tools

FROM ubuntu:24.04 AS minimal
RUN apt-get update && apt-get install -y --no-install-recommends runtime-packages
COPY --from=builder /built/tools /usr/local/bin/
```

#### 1.3 Layer Consolidation
- Combine related RUN commands
- Minimize intermediate layers
- Use `.dockerignore` effectively

#### 1.4 Mise Configuration Optimization
- Pre-configure mise directories
- Remove unused mise plugins
- Optimize cache placement

**Target**: `minimal` at ~500MB (-100MB)

### Phase 2: Language Runtime Optimization (Target: -50MB per language)

#### 2.1 Language-Specific Multi-Stage
```dockerfile
FROM minimal AS python-builder
RUN mise install python@3.13.7
# Remove build artifacts, documentation, cache

FROM minimal AS python-minimal
COPY --from=python-builder $MISE_DATA_DIR/installs/python $MISE_DATA_DIR/installs/python
RUN cleanup python installation
```

#### 2.2 Selective Language Features
- Install only essential Python packages
- Remove unnecessary Node.js modules
- Strip debug symbols from binaries
- Remove language documentation

#### 2.3 Shared Dependencies
- Identify common libraries across languages
- Use system packages where possible
- Avoid duplicate installations

**Target**: Language variants at 650-750MB (-50-100MB each)

### Phase 3: Advanced Optimization (Target: Additional -50MB)

#### 3.1 File System Optimization
```dockerfile
# Remove unnecessary files
RUN find /usr -name "*.a" -delete && \
    find /usr -name "*.la" -delete && \
    find /usr -name "*README*" -delete && \
    find /usr -name "*CHANGELOG*" -delete && \
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/*
```

#### 3.2 Compression and Deduplication
- Use BuildKit for better layer caching
- Implement layer deduplication
- Optimize file permissions to reduce metadata

#### 3.3 Strategic Tool Placement
```dockerfile
# Move less common tools to on-demand installation
RUN mise install commonly-used-tools
# Document how users can install additional tools via mise
```

## Implementation Plan

### Phase 1: Create Minimal Variant (Week 1)
1. **Create `minimal` target** in Dockerfile
   - Strip non-essential packages
   - Optimize package installation
   - Remove build dependencies

2. **Update GitHub Actions** to build minimal variant
   - Add minimal to matrix strategy
   - Test build and functionality

3. **Update documentation** for minimal usage
   - Add minimal to README
   - Update extension examples

### Phase 2: Language Optimization (Week 2)
1. **Optimize language build stages**
   - Implement multi-stage for each language
   - Add cleanup steps
   - Test language functionality

2. **Create minimal-language variants**
   - minimal-python, minimal-node, etc.
   - Update GitHub Actions matrix
   - Test extension workflows

3. **Update tooling scripts**
   - Support minimal variants in extend-image.sh
   - Update templates and examples

### Phase 3: Specialized Images (Week 3)
1. **Create use-case specific images**
   - web-dev, data-science, devops
   - Define tool combinations
   - Optimize for common workflows

2. **Update documentation**
   - Add guidance for choosing images
   - Update API reference
   - Create migration guide

### Phase 4: Advanced Optimization (Week 4)
1. **Implement file system optimization**
2. **Add compression strategies**
3. **Performance testing and benchmarking**
4. **Documentation and user migration**

## Success Metrics

### Size Targets
| Image Type | Current | Target | Reduction |
|-----------|---------|--------|-----------|
| Minimal | ~800MB | ~500MB | 37% |
| Minimal + Language | ~1000MB | ~650MB | 35% |
| Standard | ~850MB | ~750MB | 12% |
| Full | ~2200MB | ~1800MB | 18% |

### Performance Targets
- **Download time**: 50% reduction for minimal images
- **Build time**: Maintain current build speeds
- **Functionality**: 100% compatibility maintained

### User Experience Targets
- **Clear upgrade path** from current images
- **Intuitive tag naming** 
- **Comprehensive documentation**
- **Backward compatibility** during transition

## Risk Mitigation

### Breaking Changes
- **Maintain current tags** during transition
- **Provide migration documentation**
- **Use deprecation warnings** before removing old tags

### Size vs Functionality Trade-offs
- **Test all language runtimes** after optimization
- **Maintain development tool functionality**
- **Provide expansion path** via extension scripts

### Build Complexity
- **Keep Dockerfile readable** with clear comments
- **Modularize optimization steps**
- **Maintain CI/CD performance**

## Future Considerations

### Potential Extensions
- **Regional registry mirrors** for faster downloads
- **Language version matrix** (python3.11, python3.12, etc.)
- **Architecture-specific optimizations** (ARM vs x64)
- **Compressed layer experiments** (squashfs, etc.)

### User Feedback Integration
- **Monitor image usage patterns** via registry analytics
- **Collect user feedback** on size vs functionality
- **Iterate based on real usage** data

## Decision Points

### Tag Naming Convention
- **Chosen**: Size-based (minimal/standard/full) + language suffix
- **Alternative**: Use-case based (web/data/devops)
- **Rationale**: More predictable for users, easier to maintain

### Default Latest Tag
- **Chosen**: Point to `standard`
- **Alternative**: Point to `tools` (current behavior)
- **Rationale**: Better balance of features vs size for new users

### Optimization Approach
- **Chosen**: Gradual multi-stage optimization
- **Alternative**: Complete rewrite with different base
- **Rationale**: Maintains compatibility while achieving size goals

---

**Next Steps**: Begin Phase 1 implementation with minimal variant creation and testing.
