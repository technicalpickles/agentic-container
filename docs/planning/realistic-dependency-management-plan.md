# Realistic Dependency Management Plan

## Purpose
Analyze current dependency handling in examples and create guidelines for **agent-driven dependency management** that handles dynamic changes, version updates, and package installation/removal during container runtime.

## Created
2025-09-15

## Critical Insight: Agent-Driven Environment

**Key Challenge:** Agents will actively modify dependencies during container runtime:
- Installing new packages (`npm install lodash`, `pip install requests`)
- Changing versions (`npm update`, `bundle update`)
- Modifying lock files (package-lock.json, Gemfile.lock)
- Adding/removing dependencies from manifest files
- Switching between different dependency management tools

This requires a **DevContainer-style approach** that's resilient to runtime changes rather than static build-time examples.

## Current State Analysis

### Example Dockerfiles Assessment

**Current Patterns:**
1. **Global tool installation** - Installing language tools globally in the image
2. **Minimal dependency examples** - Simple pip/npm/gem install commands
3. **No ecosystem-specific dependency files** - Not using package.json, Gemfile, requirements.txt, etc.
4. **Build-time only** - All dependencies installed during image build

**Issues Identified:**
- Examples don't reflect real-world development scenarios
- Missing handling of lock files (package-lock.json, Gemfile.lock, poetry.lock)
- No consideration of dependency caching strategies
- No examples of mounting dependencies from host
- Missing multi-environment patterns (dev vs prod dependencies)

## Agent-Driven Dependency Patterns

The key insight from DevContainers and modern Docker development is to use **persistent volumes** and **entrypoint scripts** to handle dynamic dependency changes.

### Core Strategy: Persistent Dependencies + Smart Entrypoints

**Principles:**
1. **Persistent storage** - Use named volumes to preserve agent-installed dependencies
2. **Smart initialization** - Entrypoint scripts detect and handle dependency changes  
3. **Minimal base image** - Only install stable global tools in the image
4. **Runtime flexibility** - Allow agents to modify anything without breaking the container

### 1. Node.js Ecosystem (Phase 1)

**Structured Environment Configuration:**
```bash
# Configure Node.js package managers with structured paths
export NPM_CONFIG_CACHE=/tmp/node/npm/cache
export YARN_CACHE_FOLDER=/tmp/node/yarn/cache  
export PNPM_STORE_DIR=/tmp/node/pnpm/store

# Environment variable override support
export NODEJS_PKG_MANAGER=${NODEJS_PKG_MANAGER:-auto}  # auto|npm|yarn|pnpm
```

**detect-nodejs.sh:**
```bash
#!/bin/bash

# Detect Node.js project and handle dependencies
detect_nodejs() {
    [ ! -f "package.json" ] && return 0
    
    echo "📦 Detected Node.js project"
    
    # Configure structured cache paths
    export NPM_CONFIG_CACHE=/tmp/node/npm/cache
    export YARN_CACHE_FOLDER=/tmp/node/yarn/cache
    export PNPM_STORE_DIR=/tmp/node/pnpm/store
    
    # Determine package manager (with override support)
    local pkg_manager="npm"  # default
    
    if [ "$NODEJS_PKG_MANAGER" != "auto" ]; then
        pkg_manager="$NODEJS_PKG_MANAGER"
        echo "🔧 Using override: $pkg_manager"
    elif [ -f "pnpm-lock.yaml" ] || [ -f ".pnpmfile.cjs" ]; then
        pkg_manager="pnpm"
    elif [ -f "yarn.lock" ] || [ -f ".yarnrc.yml" ]; then
        pkg_manager="yarn"
    fi
    
    # Create cache directories
    mkdir -p "/tmp/node/$pkg_manager/cache"
    
    # Install/update if needed
    if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules/.timestamp" ]; then
        echo "Installing Node.js dependencies with $pkg_manager..."
        
        case "$pkg_manager" in
            yarn)
                yarn install
                ;;
            pnpm)
                pnpm install
                ;;
            *)
                npm install
                ;;
        esac
        
        touch node_modules/.timestamp
    fi
}
```

### 2. Ruby Ecosystem (Phase 1)

**Structured Environment Configuration:**
```bash
# Configure Ruby tools with structured paths
export BUNDLE_PATH=/workspace/vendor/bundle
export BUNDLE_CACHE_PATH=/tmp/ruby/bundle/cache
export GEM_SPEC_CACHE=/tmp/ruby/gem/spec_cache
export BUNDLE_DEPLOYMENT=false
export BUNDLE_WITHOUT=""

# Environment variable override support
export RUBY_PKG_MANAGER=${RUBY_PKG_MANAGER:-auto}  # auto|bundler|gem
```

**detect-ruby.sh:**
```bash
#!/bin/bash

# Detect Ruby project and handle dependencies
detect_ruby() {
    [ ! -f "Gemfile" ] && [ ! -f "*.gemspec" ] && return 0
    
    echo "💎 Detected Ruby project"
    
    # Configure structured cache paths
    export BUNDLE_PATH=/workspace/vendor/bundle
    export BUNDLE_CACHE_PATH=/tmp/ruby/bundle/cache
    export GEM_SPEC_CACHE=/tmp/ruby/gem/spec_cache
    export BUNDLE_DEPLOYMENT=false
    export BUNDLE_WITHOUT=""
    
    # Create cache directories
    mkdir -p /tmp/ruby/bundle/cache
    mkdir -p /tmp/ruby/gem/spec_cache
    
    # Determine tool and install dependencies
    if [ -f "Gemfile" ]; then
        echo "Using Bundler for gem management"
        if [ ! -d "vendor/bundle" ] || [ "Gemfile" -nt "vendor/bundle/.timestamp" ]; then
            echo "Installing Ruby gems with bundle..."
            bundle install
            mkdir -p vendor/bundle && touch vendor/bundle/.timestamp
        fi
    elif [ -f "*.gemspec" ]; then
        echo "Detected gem project, using bundle for development dependencies"
        bundle install  # This handles gemspec automatically
    fi
}
```

### 3. Python Ecosystem (Phase 2)

**Will implement with structured paths:**
```bash
# Future: Structured paths for Python tools
export PIP_CACHE_DIR=/tmp/python/pip/cache
export POETRY_CACHE_DIR=/tmp/python/poetry/cache
export PIPENV_CACHE_DIR=/tmp/python/pipenv/cache
export PYTHON_PKG_MANAGER=${PYTHON_PKG_MANAGER:-auto}  # auto|pip|poetry|pipenv
```

**Note:** Python implementation will follow same pattern as Node.js and Ruby but will be implemented in Phase 2 after validating the approach.

### 4. Go Ecosystem (Phase 2)

**Will implement with structured paths:**
```bash
# Future: Structured paths for Go tools
export GOCACHE=/tmp/go/build/cache
export GOMODCACHE=/tmp/go/mod/cache
export GO111MODULE=on
```

**Note:** Go implementation will be added in Phase 2, focusing on module cache management.

## Agent-Specific Challenges and Solutions

### Challenge 1: Version Conflicts
**Problem:** Agent installs `lodash@4.17.0`, later installs `lodash@5.0.0`, causing conflicts
**Solution:** 
- Use lock files and proper package manager commands (`npm install` vs `npm ci`)
- Entrypoint scripts detect lock file changes and rebuild cleanly
- Named volumes preserve installations but allow clean rebuilds

### Challenge 2: Cache Invalidation  
**Problem:** Agent modifies `package.json`, but container still uses old `node_modules`
**Solution:**
- Timestamp-based detection in entrypoint scripts
- Compare manifest files against marker files
- Automatic dependency refresh when changes detected

### Challenge 3: Mixed Dependency Managers
**Problem:** Agent starts with npm, switches to yarn, installs with pnpm, or has ambiguous setups
**Solution:**
- Entrypoint scripts detect and use appropriate package manager based on lock files
- **Environment variable overrides** for ambiguous cases:
  - `NODEJS_PKG_MANAGER=npm|yarn|pnpm` - Force specific Node.js package manager
  - `PYTHON_PKG_MANAGER=pip|poetry|pipenv` - Force specific Python package manager
- Clean up conflicting lock files when switching
- Support multiple package managers in same container

### Challenge 4: Persistent State vs Clean Builds
**Problem:** Agent needs persistent dependencies but occasionally needs clean rebuilds
**Solution:**
- Named volumes provide persistence by default
- Environment variable (`REBUILD_DEPS=true`) forces clean rebuild
- Agent can clear cache directories when needed

## DevContainer-Style Architecture

### Core Pattern: Smart Entrypoints + Persistent Volumes

```dockerfile
# Base image with global tools only
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install stable global development tools
RUN install-global-tools-script.sh

# Copy smart entrypoint that handles all ecosystems  
COPY smart-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/smart-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/smart-entrypoint.sh"]
CMD ["/bin/bash"]
```

**smart-entrypoint.sh:**
```bash
#!/bin/bash
set -e

# Configure all package managers to use /tmp for caches
export NPM_CONFIG_CACHE=/tmp/npm
export YARN_CACHE_FOLDER=/tmp/yarn
export PNPM_STORE_DIR=/tmp/pnpm
export PIP_CACHE_DIR=/tmp/pip
export POETRY_CACHE_DIR=/tmp/poetry
export POETRY_VENV_IN_PROJECT=1
export PIPENV_CACHE_DIR=/tmp/pipenv
export PIPENV_VENV_IN_PROJECT=1
export BUNDLE_CACHE_PATH=/tmp/bundle
export BUNDLE_PATH=/workspace/vendor/bundle
export GEM_SPEC_CACHE=/tmp/gem
export GOCACHE=/tmp/go-build
export GOMODCACHE=/tmp/go-mod
export GO111MODULE=on

# Handle environment variables for rebuilds
if [ "$REBUILD_DEPS" = "true" ]; then
    echo "🔄 Force rebuilding all dependencies..."
    rm -rf /tmp/* node_modules .venv vendor/bundle __pycache__
fi

# Auto-detect project types and handle dependencies
source /usr/local/bin/detect-nodejs.sh
source /usr/local/bin/detect-python.sh  
source /usr/local/bin/detect-ruby.sh
source /usr/local/bin/detect-go.sh

exec "$@"
```

## Simplified Volume Strategy: Single `/tmp` Mount

### Docker Compose Configuration for Agent Development

```yaml
services:
  agentic-dev:
    build: .
    volumes:
      # Mount project directory
      - .:/workspace
      
      # Single volume for ALL package manager caches
      - package_cache:/tmp
      
    environment:
      # Force rebuild when needed
      - REBUILD_DEPS=${REBUILD_DEPS:-false}
    working_dir: /workspace

volumes:
  # Single volume for all package manager caches and dependencies
  package_cache:
```

**Benefits:**
- ✅ **Single volume to manage** instead of 10+ separate volumes
- ✅ **Simpler configuration** - just mount `/tmp` and let each language configure itself
- ✅ **Unix conventions** - `/tmp` is the standard location for temporary/cache data
- ✅ **Agent-friendly** - agents can easily understand and clear `/tmp/npm`, `/tmp/pip`, etc.
- ✅ **Persistent across restarts** - volume preserves caches but allows easy cleanup

### Structured Package Manager Configuration

**Path Structure:** `/tmp/{language}/{tool}/{cache-type}`

| Language | Package Manager | Cache Location | Workspace Location | Symlink Strategy |
|----------|----------------|----------------|--------------------|-----------------| 
| Node.js | npm | `/tmp/node/npm/cache` | `/workspace/node_modules` | Symlink if needed |
| Node.js | yarn | `/tmp/node/yarn/cache` | `/workspace/node_modules` | Symlink if needed |
| Node.js | pnpm | `/tmp/node/pnpm/store` | `/workspace/node_modules` | Symlink if needed |
| Ruby | bundler | `/tmp/ruby/bundle/cache` | `/workspace/vendor/bundle` | Direct install to workspace |
| Ruby | gem | `/tmp/ruby/gem/spec_cache` | System gems | N/A |
| Python | pip | `/tmp/python/pip/cache` | `/workspace/.venv` | Direct install to workspace |
| Python | poetry | `/tmp/python/poetry/cache` | `/workspace/.venv` | Direct install to workspace |
| Python | pipenv | `/tmp/python/pipenv/cache` | `/workspace/.venv` | Direct install to workspace |
| Go | modules | `/tmp/go/mod/cache` | Module cache | N/A |
| Go | build | `/tmp/go/build/cache` | Build cache | N/A |

**Environment Variable Overrides:**
- `NODEJS_PKG_MANAGER=npm|yarn|pnpm` - Override package manager detection
- `PYTHON_PKG_MANAGER=pip|poetry|pipenv` - Override Python tooling
- `RUBY_PKG_MANAGER=bundler|gem` - Override Ruby tooling
- `GO_PKG_MANAGER=modules` - Go module configuration

**Symlink Strategy for Workspace Dependencies:**
Some tools expect dependencies in workspace but benefit from volume-backed storage:
```bash
# Example: node_modules that needs workspace location but volume-backed storage
ln -sf /tmp/node/shared/node_modules /workspace/node_modules
```

## Benefits for Agent Development

### Why Entrypoint-Only + Volume-Backed Storage is Perfect for Agents

1. **Agent Flexibility**: Agents can install, upgrade, or switch package managers without breaking the container
2. **Persistent State**: Dependencies persist across container restarts, but can be cleared when needed  
3. **Fast Iteration**: No image rebuilds needed when agents modify dependency files
4. **Multi-Project Support**: Single container can handle multiple different project types
5. **Cache Efficiency**: Package manager caches are preserved, speeding up subsequent installs
6. **Clean Rebuilds**: `REBUILD_DEPS=true` environment variable allows agents to start fresh

### Agent Workflow Examples

```bash
# Agent installs a new package
npm install lodash
# ✅ Works immediately, cached in /tmp/npm, persisted in volume

# Agent switches package managers
rm package-lock.json && yarn install  
# ✅ Entrypoint detects yarn.lock, uses /tmp/yarn cache

# Agent needs clean dependencies
docker-compose run -e REBUILD_DEPS=true app
# ✅ Clears /tmp/* and reinstalls fresh

# Agent clears just npm cache
rm -rf /tmp/npm && npm install
# ✅ Single directory to understand and manage

# Agent works on multiple projects
cd project1 && npm install  # Uses /tmp/npm
cd ../project2 && pip install requests  # Uses /tmp/pip  
cd ../project3 && bundle install  # Uses /tmp/bundle
# ✅ All caches in predictable /tmp locations
```

## Phased Implementation Plan

### Phase 1: Foundation - Node.js & Ruby (Familiar Languages)

**Scope:** Implement structured dependency management for Node.js and Ruby ecosystems

**Timeline:** 2-3 weeks

**Phase 1 Tasks:**
- [ ] **Core Infrastructure**
  - [ ] Create `smart-entrypoint.sh` with structured `/tmp/{lang}/{tool}` paths
  - [ ] Implement environment variable override system (`NODEJS_PKG_MANAGER`, `RUBY_PKG_MANAGER`)
  - [ ] Add `REBUILD_DEPS=true` cleanup functionality
- [ ] **Node.js Implementation**
  - [ ] Build `detect-nodejs.sh` with npm/yarn/pnpm detection and override support
  - [ ] Configure structured caches: `/tmp/node/npm/cache`, `/tmp/node/yarn/cache`, `/tmp/node/pnpm/store`
  - [ ] Test package manager switching scenarios
- [ ] **Ruby Implementation**
  - [ ] Build `detect-ruby.sh` with Bundler/gem detection  
  - [ ] Configure structured caches: `/tmp/ruby/bundle/cache`, `/tmp/ruby/gem/spec_cache`
  - [ ] Test Gemfile vs gemspec project handling
- [ ] **Base Container Updates**
  - [ ] Update main Dockerfile to use smart-entrypoint.sh
  - [ ] Remove static dependency installation from Node.js and Ruby examples
  - [ ] Create simple docker-compose.yml with single `/tmp` volume mount

**Phase 1 Success Criteria:**
- [ ] Agents can `npm install`, `yarn add`, `bundle install` without breaking container
- [ ] Package manager switching works: `rm package-lock.json && yarn install`
- [ ] Environment variable overrides work: `NODEJS_PKG_MANAGER=pnpm`
- [ ] Cache cleanup works: `REBUILD_DEPS=true` clears `/tmp/node/*` and `/tmp/ruby/*`
- [ ] Dependencies persist across container restarts
- [ ] **Documentation:** `docs/dependency-management.md` explaining the what/why

### Phase 2: Production Readiness & Documentation (Familiar Languages)

**Scope:** Polish, test, and document Node.js & Ruby implementation thoroughly before expansion

**Timeline:** 2-3 weeks

**Phase 2 Tasks:**
- [ ] **Comprehensive Testing**
  - [ ] Create automated test suite simulating agent workflows for Node.js & Ruby
  - [ ] Test edge cases: version conflicts, corrupted caches, network failures
  - [ ] Performance benchmarking: startup times, cache efficiency
  - [ ] Test package manager switching scenarios extensively
- [ ] **Documentation Suite** (Critical Success Requirement)
  - [ ] `docs/dependency-management.md` - Complete technical specification
  - [ ] `docs/agent-workflows.md` - Agent usage patterns and examples  
  - [ ] `docs/troubleshooting.md` - Common issues and solutions
  - [ ] `docs/performance.md` - Optimization guide and benchmarks
- [ ] **Developer Experience**
  - [ ] Add helpful error messages and debugging output
  - [ ] Create diagnostic commands for agents (`agentic-container status`)
  - [ ] Implement health checks for dependency systems
- [ ] **Advanced Features**
  - [ ] Implement symlink strategy for workspace dependencies that need specific locations
  - [ ] Add performance optimization for large dependency trees
  - [ ] Polish environment variable override system

**Phase 2 Success Criteria:**
- [ ] **Complete documentation** explaining architecture decisions and rationale
- [ ] Test suite passes in CI/CD with real agent simulation
- [ ] Container startup time < 30 seconds with cached dependencies
- [ ] Memory usage remains reasonable (< 1GB) with Node.js & Ruby caches
- [ ] **Future maintainers can understand why decisions were made**
- [ ] Pattern is proven and ready for expansion to other languages

### Phase 3: Expansion - Python & Go (Less Familiar Languages)  

**Scope:** Extend the proven pattern to Python and Go ecosystems

**Timeline:** 2-3 weeks

**Phase 3 Tasks:**
- [ ] **Python Implementation**
  - [ ] Build `detect-python.sh` following established Node.js/Ruby patterns
  - [ ] Configure structured caches: `/tmp/python/{pip,poetry,pipenv}/cache`
  - [ ] Handle virtual environments (.venv in workspace, caches in /tmp)
  - [ ] Test requirements.txt, pyproject.toml, Pipfile scenarios
- [ ] **Go Implementation**  
  - [ ] Build `detect-go.sh` following established patterns
  - [ ] Configure structured caches: `/tmp/go/mod/cache`, `/tmp/go/build/cache`
  - [ ] Test go.mod dependency handling and `go mod tidy`
- [ ] **Enhanced Examples**
  - [ ] Update Python and Go example Dockerfiles to use entrypoint pattern
  - [ ] Add comprehensive docker-compose.yml with all language support
- [ ] **Extended Documentation**
  - [ ] Update `docs/dependency-management.md` with Python & Go sections
  - [ ] Add Python & Go examples to `docs/agent-workflows.md`

**Phase 3 Success Criteria:**
- [ ] All four languages (Node.js, Ruby, Python, Go) work seamlessly in same container
- [ ] Agents can switch between different Python package managers
- [ ] Go module caching works correctly
- [ ] Mixed-language projects work (e.g., Node.js frontend + Python backend)
- [ ] **Documentation:** Complete `docs/dependency-management.md` with all languages
- [ ] Load testing with multiple concurrent projects across all languages

## Documentation Requirements (Success Criteria)

**Critical:** Must produce `docs/dependency-management.md` explaining:

1. **Architecture Decision Record (ADR)**
   - Why we chose entrypoint scripts over build-time installation
   - Why we use `/tmp` with single volume instead of multiple named volumes
   - Why structured paths `/tmp/{lang}/{tool}` vs flat structure
   - Why environment variable overrides are needed for agents

2. **Technical Specification**
   - Complete environment variable reference
   - File system layout and conventions  
   - Package manager detection logic
   - Cache invalidation strategies

3. **Agent Usage Guide**
   - How agents should install/manage dependencies
   - When to use override environment variables
   - How to clear caches when needed
   - Troubleshooting common scenarios

4. **Future Maintainer Guide**
   - How to add new languages/package managers
   - Testing procedures for changes
   - Performance considerations and monitoring

## Key References for This Pattern

The agent-driven dependency pattern we're implementing is well-documented in several key sources:

### DevContainers Specification
- **[containers.dev](https://containers.dev)** - Official DevContainers specification
  - Documents `postStartCommand` and `onCreateCommand` lifecycle hooks for dynamic setup
  - Covers persistent volume patterns for development containers
- **[DevContainers Features](https://containers.dev/features)** - Modular installation patterns
- **[DevContainer Templates](https://containers.dev/templates)** - Real-world examples of this pattern

### VS Code Remote Development
- **[VS Code DevContainers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)**
  - Covers lifecycle commands, volume mounts, and dynamic dependency handling
- **[DevContainer Configuration Reference](https://code.visualstudio.com/docs/devcontainers/devcontainer-cli)**
  - Details on `devcontainer.json` configuration for persistent dependencies

### Docker Development Best Practices
- **[Docker Development Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)** 
  - Documents entrypoint patterns and volume mounting strategies
- **[Docker Compose for Development](https://docs.docker.com/compose/gettingstarted/)**
  - Named volume patterns for dependency persistence
- **[TatvaSoft Docker Best Practices](https://www.tatvasoft.com/blog/docker-best-practices/)**
  - Covers avoiding baked-in dependencies and using entrypoint scripts

### GitHub Examples
- **[DevContainers/templates repository](https://github.com/devcontainers/templates)** - Real examples
- **[VS Code DevContainers samples](https://github.com/Microsoft/vscode-dev-containers)** - Practical implementations
- **[GitHub Codespaces configuration examples](https://docs.github.com/en/codespaces/setting-up-your-project-for-codespaces)**

### Key Pattern Documentation
1. **Lifecycle Commands**: `onCreateCommand` runs once when container is created, `postStartCommand` runs every time container starts
2. **Named Volumes**: Persistent storage for `node_modules`, `.venv`, `vendor/bundle` across container restarts  
3. **Entrypoint Scripts**: Smart detection and installation of dependencies based on project files
4. **Multi-tool Support**: Single container supporting multiple package managers per language

This pattern is the foundation of GitHub Codespaces, VS Code DevContainers, and most modern cloud development environments.

## File Structure for Examples

```
docs/examples/
├── nodejs-backend/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   ├── src/
│   │   └── index.js
│   └── README.md
├── python-cli/
│   ├── Dockerfile
│   ├── pyproject.toml
│   ├── poetry.lock
│   ├── requirements.txt  # Alternative approach
│   ├── src/
│   │   └── main.py
│   └── README.md
├── rails-fullstack/
│   ├── Dockerfile
│   ├── Gemfile
│   ├── Gemfile.lock
│   ├── config/
│   ├── app/
│   └── README.md
└── go-microservices/
    ├── Dockerfile
    ├── go.mod
    ├── go.sum
    ├── cmd/
    │   └── main.go
    └── README.md
```

## Success Metrics

- Examples demonstrate real-world dependency patterns
- Build times remain reasonable (< 5 minutes for typical projects)
- Container startup times are acceptable (< 30 seconds)
- Documentation clearly explains trade-offs and choices
- Developers can easily adapt examples to their projects

## Next Steps

1. Start with Phase 1: Create realistic example projects with proper dependency files
2. Update one language example at a time to validate approach
3. Gather feedback on build performance and developer experience
4. Iterate based on real-world usage patterns
5. Document lessons learned and best practices

## Key Changes from User Feedback

✅ **Entrypoint-Only Pattern**: Removed ALL static build-time dependency examples. ALL patterns now use smart entrypoint scripts.

✅ **Volume-Backed Storage**: Added comprehensive package manager configuration for volume-backed caches and dependency storage.

✅ **Language-Specific Updates**:
- **Python**: Good approach with global tools vs project-specific dependencies via entrypoint ✅  
- **Ruby**: Removed Gemfile/Gemfile.lock copying during build - entrypoint only ✅
- **Go**: Removed build-time dependency installation - only entrypoint dependency handling ✅

✅ **Package Manager Cache Configuration**: Added detailed environment variable configuration for all package managers to use volume-backed storage locations.

## The /tmp Advantage: Brilliant Simplification

✅ **Single Volume**: `docker-compose.yml` just needs `- package_cache:/tmp` instead of 10+ volumes

✅ **Self-Configuring**: Each language configures its own `/tmp/npm`, `/tmp/pip`, `/tmp/bundle` subdirectory  

✅ **Agent-Intuitive**: Agents can easily understand and manage `/tmp/npm` vs complex paths like `/workspace/.pip-cache`

✅ **Unix Standard**: `/tmp` is the conventional location for temporary/cache data

✅ **Easy Cleanup**: `rm -rf /tmp/npm` clears just npm cache, `rm -rf /tmp/*` clears everything

✅ **Persistent**: Volume-backed `/tmp` preserves caches across container restarts but allows selective cleanup

This plan ensures our container is perfectly suited for **agent-driven development** where agents dynamically install, upgrade, and switch dependencies during runtime without breaking the container environment.
