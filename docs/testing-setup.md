# Testing Tools Setup

This document describes how to set up the testing tools for the
agentic-container project.

## Overview 🎯

We use **goss** for comprehensive container validation testing with a
**container-based approach**:

- **goss**: Validates server configurations and Docker containers
- **Container self-installation**: Each container installs its own goss binary
  using mise

## Approach ✨

Our testing strategy is **self-contained and architecture-agnostic**:

1. **Container installs goss using mise** (no host dependencies)
2. **No architecture compatibility issues** (ARM64/x86_64 handled automatically)
3. **No volume mounting problems** (embedded script approach)
4. **Consistent across development and CI**

## Installation

### Local Development

From the project root:

```bash
# Installs goss for local use (optional - containers install their own)
mise install
```

### Per-Cookbook Testing

Each cookbook directory has:

- `goss.yaml` - Test configuration for comprehensive validation
- Tests are run using the unified `scripts/test-dockerfile.sh` script

## Usage

### Testing a cookbook example

```bash
# Build and test a cookbook (from project root)
./scripts/test-dockerfile.sh docs/cookbooks/python-cli/Dockerfile

# Test with cleanup
./scripts/test-dockerfile.sh docs/cookbooks/python-cli/Dockerfile --cleanup
```

### Adding tests to a new cookbook

```bash
# 1. Copy goss template
cd docs/cookbooks/my-new-cookbook
cp ../_templates/goss-template.yaml goss.yaml

# 2. Customize goss.yaml for your cookbook
# Edit goss.yaml to test your specific packages/tools

# 3. Test your configuration (from project root)
cd /project/root
./scripts/test-dockerfile.sh docs/cookbooks/my-new-cookbook/Dockerfile
```

### How it works internally

The `test-dockerfile.sh` script:

1. **Builds the Docker image** from the provided Dockerfile
2. **Tests basic functionality** (startup, working directory)
3. **Runs comprehensive goss tests** using pre-installed goss
4. **Reports detailed results** with clear success/failure indicators
5. **Cleans up test image** (optional with --cleanup flag)

### Creating new tests

1. Create a `goss.yaml` file in the cookbook directory:

```yaml
command:
  'python3 --version':
    exit-status: 0
    stdout:
      - 'Python 3'

file:
  /workspace:
    exists: true
    mode: '0755'

user:
  agent:
    exists: true
    groups:
      - agent
```

2. Test using the unified script from project root

## Unified Testing Approach

### Consolidated Script

We use a **single unified script** for all Dockerfile testing:

- **`./scripts/test-dockerfile.sh`** - Builds Docker images and runs
  comprehensive goss tests
- **Single entry point** - No need for separate build and test scripts
- **Complete workflow** - Build → Test → Report → Cleanup (optional)

### Usage Pattern

```bash
# Standard pattern for all testing
./scripts/test-dockerfile.sh <dockerfile-path> [--cleanup]

# Examples:
./scripts/test-dockerfile.sh docs/cookbooks/python-cli/Dockerfile
./scripts/test-dockerfile.sh my-custom-app.dockerfile --cleanup
```

## CI Integration

For CI (GitHub Actions):

```yaml
- name: Test cookbook examples
  run: |
    # Build and test with unified script
    ./scripts/test-dockerfile.sh docs/cookbooks/${{ matrix.example }}/Dockerfile --cleanup
```

## Success Metrics ✅

**Phase 2 Complete**: Both pilot cookbooks implemented

- ✅ **python-cli**: 23/23 tests passing
- ✅ **nodejs-backend**: 27/27 tests passing
- ✅ Container self-installs goss using mise
- ✅ No architecture compatibility issues
- ✅ Template files for easy adoption
- ✅ Individual test scripts per cookbook
- ✅ Ready for CI integration and expansion to other cookbooks

## Architecture Benefits

✨ **No host/container architecture mismatches**
✨ **No complex volume mounting**
✨ **Uses existing mise infrastructure**
✨ **Works identically in development and CI**
✨ **Self-documenting test specifications**
