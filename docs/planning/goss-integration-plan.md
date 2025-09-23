# Goss Testing Integration Plan for Standard and Dev Targets

**Created**: 2025-01-22  
**Status**: Research and Planning Complete  
**Goal**: Integrate goss tests for standard and dev targets, enable cookbook reuse

## Executive Summary

This plan outlines how to add comprehensive goss testing for the main Dockerfile's `standard` and `dev` targets, integrate them into CI, and enable cookbooks to reuse these base tests. The approach builds on the existing successful cookbook testing infrastructure while adding base image validation.

## Current State Analysis

### Existing Goss Testing Infrastructure ✅

**Strengths:**
- **Container self-installation**: Each container installs goss using mise (solves architecture issues)
- **Unified test script**: `scripts/test-dockerfile.sh` handles all testing logic
- **Comprehensive validation**: 23 tests passing for python-cli cookbook
- **CI integration**: Cookbook testing fully integrated into GitHub Actions
- **Template system**: `docs/cookbooks/_templates/goss-template.yaml` for new cookbooks

**Current Cookbook Testing Flow:**
1. Build cookbook extension image from base image
2. Run `./scripts/test-dockerfile.sh <cookbook> <image>`
3. Script mounts goss.yaml and runs comprehensive validation
4. All tests must pass for CI success

### Dockerfile Target Analysis

**Standard Target (Lines 76-247):**
- **Base**: Ubuntu 24.04
- **Core Tools**: git, curl, vim, nano, jq, ripgrep, fd-find, tree, htop
- **System Tools**: dumb-init, sudo, procps, locales
- **Container Tools**: Docker CLI, docker-compose-plugin
- **AI Tools**: GitHub CLI, Claude Code, Codex, Copilot, Goose, OpenCode
- **Version Managers**: mise, rv
- **Languages**: Node.js, Python (via mise)
- **Agent Tools**: ast-grep, uv/uvx, goss (via mise)
- **Shell**: starship prompt
- **User**: agent (UID 1001, GID 1001)
- **Groups**: agent, docker, mise
- **Workspace**: /workspace (owned by agent)

**Dev Target (Lines 255-278):**
- **Inherits**: Everything from standard target
- **Additional Languages**: Ruby, Go, lefthook (via mise)
- **Same user/workspace setup**

## Proposed Implementation Plan

### Phase 1: Create Base Goss Test Files

#### 1.1 File Structure
```
/
├── goss/
│   ├── standard.yaml          # Tests for standard target
│   ├── dev.yaml              # Tests for dev target  
│   └── base-common.yaml      # Shared tests between standard/dev
├── docs/cookbooks/
│   ├── _templates/
│   │   ├── goss-template.yaml
│   │   ├── goss-standard-base.yaml  # Template for cookbooks extending standard
│   │   └── goss-dev-base.yaml       # Template for cookbooks extending dev
│   └── [existing cookbooks]/
└── scripts/
    └── test-dockerfile.sh     # Enhanced to support base targets
```

#### 1.2 Standard Target Tests (`goss/standard.yaml`)

**Core System Validation:**
```yaml
# Test essential system commands
command:
  "git --version":
    exit-status: 0
    stdout: ["git version"]
  "curl --version":
    exit-status: 0
    stdout: ["curl"]
  "vim --version":
    exit-status: 0
    stdout: ["VIM"]
  "jq --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]
  "ripgrep --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]
  "fd --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]

# Test container tools
  "docker --version":
    exit-status: 0
    stdout: ["Docker version"]
  "docker compose version":
    exit-status: 0
    stdout: ["Docker Compose version"]

# Test AI coding agents
  "claude --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]
  "codex --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]
  "gh --version":
    exit-status: 0
    stdout: ["gh version"]
  "goose --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]
  "opencode --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]

# Test version managers
  "mise --version":
    exit-status: 0
    stdout: [/\d{4}\.\d+\.\d+/]
  "rv --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]

# Test languages (installed via mise)
  "node --version":
    exit-status: 0
    stdout: [/v\d+\.\d+\.\d+/]
  "python3 --version":
    exit-status: 0
    stdout: ["Python 3"]
  "npm --version":
    exit-status: 0
    stdout: [/\d+\.\d+\.\d+/]
  "pip --version":
    exit-status: 0
    stdout: ["pip"]

# Test agent tools
  "ast-grep --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]
  "uv --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]
  "goss --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]

# Test shell prompt
  "starship --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]

# Test file structure
file:
  /workspace:
    exists: true
    filetype: directory
    mode: "0755"
  /usr/local/share/mise:
    exists: true
    filetype: directory
  /etc/mise:
    exists: true
    filetype: directory
  /home/agent:
    exists: true
    filetype: directory
    mode: "0755"

# Test user setup
user:
  agent:
    exists: true
    uid: 1001
    gid: 1001
    groups:
      - agent
      - docker
      - mise
    home: "/home/agent"
    shell: "/bin/bash"

# Test environment
env:
  MISE_DATA_DIR:
    value: "/usr/local/share/mise"
  MISE_CONFIG_DIR:
    value: "/etc/mise"
  MISE_CACHE_DIR:
    value: "/tmp/mise-cache"
  PATH:
    contains: ["/usr/local/share/mise/shims"]
```

#### 1.3 Dev Target Tests (`goss/dev.yaml`)

**Inherits Standard + Additional Languages:**
```yaml
# Include standard tests
include:
  - standard.yaml

# Additional language tests
command:
  "ruby --version":
    exit-status: 0
    stdout: [/ruby \d+\.\d+/]
  "gem --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]
  "go version":
    exit-status: 0
    stdout: [/go version go\d+\.\d+/]
  "lefthook --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]

# Additional file tests
file:
  /usr/local/share/mise/installs/ruby:
    exists: true
    filetype: directory
  /usr/local/share/mise/installs/go:
    exists: true
    filetype: directory
  /usr/local/share/mise/installs/lefthook:
    exists: true
    filetype: directory
```

#### 1.4 Base Common Tests (`goss/base-common.yaml`)

**Shared validation between standard and dev:**
```yaml
# Common system validation
command:
  "dumb-init --version":
    exit-status: 0
    stdout: [/\d+\.\d+/]
  "sudo --version":
    exit-status: 0
    stdout: ["Sudo version"]

# Common file structure
file:
  /usr/local/bin/mise:
    exists: true
    filetype: file
    mode: "0755"
  /usr/local/bin/rv:
    exists: true
    filetype: file
    mode: "0755"
  /usr/local/bin/starship:
    exists: true
    filetype: file
    mode: "0755"

# Common environment
env:
  DEBIAN_FRONTEND:
    value: "noninteractive"
  TERM:
    value: "xterm-256color"
  LANG:
    value: "en_US.UTF-8"
  LC_ALL:
    value: "en_US.UTF-8"
```

### Phase 2: Enhanced Test Script

#### 2.1 Enhanced `scripts/test-dockerfile.sh`

**New capabilities:**
- Support for testing base targets (`standard`, `dev`)
- Automatic goss file detection for base targets
- Enhanced CI mode for base target testing
- Better error messages and guidance

**New usage patterns:**
```bash
# Test standard target
./scripts/test-dockerfile.sh standard

# Test dev target  
./scripts/test-dockerfile.sh dev

# Test cookbook (existing)
./scripts/test-dockerfile.sh docs/cookbooks/python-cli/Dockerfile

# CI mode for base targets
./scripts/test-dockerfile.sh standard test-standard:latest
./scripts/test-dockerfile.sh dev test-dev:latest
```

**Enhanced logic:**
```bash
# Detect target type
if [[ "$dockerfile" == "standard" ]] || [[ "$dockerfile" == "dev" ]]; then
    # Base target testing
    goss_file="goss/$dockerfile.yaml"
    target_name="$dockerfile"
elif [[ "$dockerfile" == *"/cookbooks/"* ]]; then
    # Cookbook testing (existing logic)
    cookbook_name=$(basename "$(dirname "$dockerfile")")
    goss_file="$(dirname "$dockerfile")/goss.yaml"
    target_name="$cookbook_name"
else
    # Custom dockerfile testing
    goss_file="$(dirname "$dockerfile")/goss.yaml"
    target_name="$(basename "$dockerfile")"
fi
```

### Phase 3: CI Integration

#### 3.1 Enhanced GitHub Actions Workflow

**New matrix jobs for base target testing:**
```yaml
strategy:
  matrix:
    include:
      # Existing cookbook testing
      - job: test-cookbooks
        name: Test Cookbooks
        cookbook: python-cli
        condition: ${{ needs.detect-changes.outputs.base-dockerfile == 'true' || contains(needs.detect-changes.outputs.changed-cookbooks, 'python-cli') }}
      
      # New base target testing
      - job: test-standard
        name: Test Standard Target
        target: standard
        condition: ${{ needs.detect-changes.outputs.base-dockerfile == 'true' || github.event_name == 'schedule' }}
      - job: test-dev
        name: Test Dev Target  
        target: dev
        condition: ${{ needs.detect-changes.outputs.base-dockerfile == 'true' || github.event_name == 'schedule' }}
```

**New CI steps:**
```yaml
- name: Test base target
  if: matrix.job == 'test-standard' || matrix.job == 'test-dev'
  run: |
    echo "🧪 Testing ${{ matrix.target }} target..."
    ./scripts/test-dockerfile.sh ${{ matrix.target }} test-${{ matrix.target }}:latest
```

#### 3.2 CI Flow Integration

**Build → Test → Publish Flow:**
1. **Build Standard**: Build standard target, export for testing
2. **Build Dev**: Build dev target (if base dockerfile changed)
3. **Test Standard**: Run goss tests on standard target
4. **Test Dev**: Run goss tests on dev target  
5. **Test Cookbooks**: Test all cookbooks (existing)
6. **Publish**: Publish successful builds

### Phase 4: Cookbook Reuse Strategy

#### 4.1 Base Test Templates

**Standard Base Template (`docs/cookbooks/_templates/goss-standard-base.yaml`):**
```yaml
# Include standard target tests
include:
  - ../../../goss/standard.yaml

# Cookbook-specific tests
command:
  # Add your cookbook-specific tool tests here
  # Examples:
  # "your-tool --version":
  #   exit-status: 0
  #   stdout: [/\d+\.\d+/]

# Add cookbook-specific file tests
file:
  # Add your cookbook-specific files here
```

**Dev Base Template (`docs/cookbooks/_templates/goss-dev-base.yaml`):**
```yaml
# Include dev target tests  
include:
  - ../../../goss/dev.yaml

# Cookbook-specific tests
command:
  # Add your cookbook-specific tool tests here

# Add cookbook-specific file tests
file:
  # Add your cookbook-specific files here
```

#### 4.2 Cookbook Migration Strategy

**For existing cookbooks:**
1. **Option A**: Keep existing tests, add base validation
2. **Option B**: Migrate to base templates for consistency

**For new cookbooks:**
1. Use base templates as starting point
2. Add cookbook-specific tests
3. Inherit all base validation automatically

#### 4.3 Template Usage Examples

**Creating a new Python cookbook:**
```bash
cd docs/cookbooks/my-python-cookbook
cp ../_templates/goss-standard-base.yaml goss.yaml

# Edit goss.yaml to add Python-specific tests
# Standard target tests are automatically included
```

**Creating a new multi-language cookbook:**
```bash
cd docs/cookbooks/my-multi-lang-cookbook  
cp ../_templates/goss-dev-base.yaml goss.yaml

# Edit goss.yaml to add cookbook-specific tests
# Dev target tests (including all languages) are automatically included
```

## Implementation Benefits

### 1. Comprehensive Base Validation ✅
- **Standard target**: Validates all core tools, AI agents, languages
- **Dev target**: Validates standard + additional languages (Ruby, Go)
- **Consistent testing**: Same validation approach across all targets

### 2. CI Integration ✅
- **Parallel testing**: Base targets and cookbooks test in parallel
- **Change detection**: Only test what changed
- **Build validation**: Ensure base images work before cookbook testing

### 3. Cookbook Reuse ✅
- **Template system**: Easy creation of new cookbooks
- **Base inheritance**: Cookbooks automatically get base validation
- **Consistency**: All cookbooks use same base validation approach

### 4. Developer Experience ✅
- **Local testing**: `./scripts/test-dockerfile.sh standard`
- **Clear feedback**: Comprehensive test results and error messages
- **Easy debugging**: Failed tests show exactly what's wrong

### 5. Maintenance Benefits ✅
- **Single source of truth**: Base tests defined once, reused everywhere
- **Version validation**: Ensure all tools are correct versions
- **Regression prevention**: Catch breaking changes in base images

## File Structure Summary

```
/
├── goss/                           # NEW: Base target tests
│   ├── standard.yaml              # Standard target validation
│   ├── dev.yaml                   # Dev target validation  
│   └── base-common.yaml           # Shared base tests
├── docs/cookbooks/
│   ├── _templates/
│   │   ├── goss-template.yaml     # EXISTING: Generic template
│   │   ├── goss-standard-base.yaml # NEW: Standard base template
│   │   └── goss-dev-base.yaml     # NEW: Dev base template
│   └── [cookbooks]/               # EXISTING: Individual cookbooks
├── scripts/
│   └── test-dockerfile.sh         # ENHANCED: Support base targets
└── .github/workflows/
    └── build-test-publish.yml     # ENHANCED: Base target testing
```

## Next Steps

1. **Create base goss test files** (`goss/standard.yaml`, `goss/dev.yaml`)
2. **Enhance test script** to support base targets
3. **Update CI workflow** to test base targets
4. **Create base templates** for cookbook reuse
5. **Test implementation** with existing cookbooks
6. **Document new usage patterns** in README and docs

This plan provides a comprehensive, maintainable approach to testing base images while enabling cookbook reuse and maintaining the existing successful testing infrastructure.

