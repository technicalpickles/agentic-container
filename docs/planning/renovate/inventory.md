# Agentic Container Version Inventory for Renovate

## Complete Version Specification Inventory

### 1. **Dockerfile Build Arguments** (ARG declarations)
**Location**: `Dockerfile` lines 7-15
```dockerfile
ARG NODE_VERSION=24.8.0
ARG PYTHON_VERSION=3.13.7
ARG RUBY_VERSION=3.4.5
ARG GO_VERSION=1.25.1
ARG AST_GREP_VERSION=0.39.5
ARG LEFTHOOK_VERSION=1.13.0
ARG UV_VERSION=0.8.17
ARG CLAUDE_CODE_VERSION=1.0.0
ARG CODEX_VERSION=2.0.0
```

**Also in cookbook Dockerfiles**:
- `docs/cookbooks/rails-fullstack/Dockerfile` - `ARG RUBY_VERSION=3.4.5`
- `docs/cookbooks/go-microservices/Dockerfile` - `ARG GO_VERSION=1.23.5`

### 2. **Docker Base Images** (FROM statements)
**Locations**:
```dockerfile
# Main Dockerfile
FROM ubuntu:24.04 AS builder
FROM ubuntu:24.04 AS standard

# Cookbook extensions
FROM ghcr.io/technicalpickles/agentic-container:latest
```

**Files**: Dockerfile, all cookbook Dockerfiles

### 3. **GitHub Actions Versions** (@v syntax)
**File**: `.github/workflows/build-test-publish.yml`
```yaml
uses: actions/checkout@v4
uses: docker/setup-buildx-action@v3
uses: docker/login-action@v3
uses: docker/metadata-action@v5
uses: docker/build-push-action@v5
uses: actions/upload-artifact@v4
uses: actions/download-artifact@v4
```

**File**: `.github/workflows/lint-and-validate.yml`
```yaml
uses: actions/checkout@v4
uses: jbergstroem/hadolint-gh-action@v1.13.0
uses: ibiqlik/action-yamllint@v3.0.2
uses: aquasecurity/setup-trivy@v0.2.3
uses: github/codeql-action/upload-sarif@v3
```

**Files**: `.github/workflows/docs-and-maintenance.yml`, `.github/workflows/size-analysis.yml`
```yaml
uses: actions/checkout@v4
uses: actions/github-script@v7
```

### 4. **Trivy Version** (explicit tool versions)
**File**: `.github/workflows/lint-and-validate.yml`
```yaml
with:
  version: v0.66.0
```

### 5. **Mise Tool Versions**
**File**: `mise.toml`
```toml
[tools]
hadolint = "latest"
goss = "latest" 
yamllint = "latest"
trivy = "latest"
```

### 6. **Node.js Dependencies**
**File**: `package.json`
```json
{
  "devDependencies": {
    "prettier": "^3.2.5"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

### 7. **Download URLs with Versions**
**File**: `Dockerfile` line 38
```dockerfile
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/spinel-coop/rv/releases/download/v0.1.1/rv-installer.sh
```

**File**: `scripts/analyze-image-size.sh`
```bash
DIVE_VERSION="${DIVE_VERSION:-0.12.0}"
download_url="https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_${os}_${arch}.tar.gz"
```

### 8. **Package Manager Install Commands**
**Various locations**:
- `mise install tool@version` patterns in cookbooks
- `npm install -g package@version` in templates
- `go install github.com/air-verse/air@latest` in cookbooks
- `pip install --no-cache-dir package` (no versions pinned)

## Renovate Out-of-the-Box Capabilities

### ✅ **Fully Supported** (No configuration needed)

1. **GitHub Actions** - Native support for `@v` syntax updates
2. **Node.js Dependencies** - Complete package.json support including devDependencies and engines
3. **Docker Base Images** - FROM ubuntu:24.04 will be updated automatically
4. **Docker Hub/Registry Images** - All ghcr.io and docker.io images

### ⚠️ **Partially Supported** (Needs configuration)

1. **Docker Build Arguments (ARGs)** - Requires custom regex managers
2. **GitHub Release URLs** - Needs github-releases datasource configuration
3. **Download URLs with versions** - Requires regex managers for patterns like `/releases/download/v${VERSION}/`

### ❌ **Not Supported** (Complex workarounds needed)

1. **Mise tool versions in toml** - No native mise.toml manager
2. **Shell script embedded versions** - Like DIVE_VERSION in scripts
3. **Dynamic version references** - Variables used in multiple places
4. **Tool-specific install commands** - `go install @latest`, `mise install tool@version`

## Files Grouped by Renovate Support Level

### **Native Support (Works immediately)**
- `package.json` / `package-lock.json` - Node.js dependencies
- `.github/workflows/*.yml` - GitHub Actions versions
- All `Dockerfile*` files - Base image tags (FROM statements)

### **Needs Custom Configuration**
- `Dockerfile` - ARG version declarations
- `docs/cookbooks/*/Dockerfile` - ARG versions
- Download URL patterns in Dockerfiles and scripts

### **Requires Workarounds**
- `mise.toml` - Tool versions (could use regex manager)
- `scripts/*.sh` - Embedded version variables
- Tool install commands across cookbooks

## Implementation Priority Recommendations

### **Phase 1 - Easy Wins** (High value, low effort)
1. GitHub Actions versions (automatic)
2. Node.js dependencies (automatic)  
3. Docker base images (automatic)

### **Phase 2 - Custom Managers** (Medium effort, medium value)
1. Docker ARG versions with regex managers
2. GitHub release download URLs
3. Specific tool version patterns

### **Phase 3 - Complex Cases** (High effort, lower value)
1. Mise tool versions in toml
2. Shell script embedded versions
3. Cross-file version consistency
