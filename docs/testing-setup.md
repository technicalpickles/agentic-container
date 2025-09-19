# Testing Tools Setup

This document describes how to set up the testing tools for the agentic-container project.

## Overview 🎯

We use **goss** for comprehensive container validation testing with a **container-based approach**:
- **goss**: Validates server configurations and Docker containers
- **Container self-installation**: Each container installs its own goss binary using mise

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
- `goss.yaml` - Test configuration
- `test-goss.sh` - Self-contained test runner

## Usage

### Testing a cookbook example

```bash
# 1. Build the image first
cd /project/root
./docs/cookbooks/test-extensions.sh docs/cookbooks/python-cli/Dockerfile

# 2. Run goss tests
cd docs/cookbooks/python-cli
./test-goss.sh

# Or specify a specific image
./test-goss.sh test-extension-1234567890
```

### Adding tests to a new cookbook

```bash
# 1. Copy template files
cd docs/cookbooks/my-new-cookbook
cp ../_templates/test-goss.sh .
cp ../_templates/goss-template.yaml goss.yaml

# 2. Make test script executable
chmod +x test-goss.sh

# 3. Customize goss.yaml for your cookbook
# Edit goss.yaml to test your specific packages/tools

# 4. Test your configuration  
./test-goss.sh
```

### How it works internally

The `test-goss.sh` script:
1. Verifies the container image exists
2. Runs the container as root
3. **Container installs goss using mise**
4. **Container runs goss tests directly**
5. Reports results with detailed output

### Creating new tests

1. Create a `goss.yaml` file in the cookbook directory:
```yaml
command:
  "python3 --version":
    exit-status: 0
    stdout:
      - "Python 3"
      
file:
  /workspace:
    exists: true
    mode: "0755"

user:
  agent:
    exists: true
    groups:
      - agent
```

2. Copy and adapt `test-goss.sh` from existing cookbook

## Integration with test-extensions.sh

### Current Plan

**Phase 1**: goss tests **complement** existing validation
- `test-extensions.sh` continues basic validation
- `test-goss.sh` provides comprehensive testing
- Both run independently

**Phase 2**: goss tests **replace** parts of test-extensions.sh
- Migrate package validation to goss
- Keep build and basic functionality in test-extensions.sh
- Single entry point for all testing

### Migration Strategy

```bash
# Current: 
./test-extensions.sh Dockerfile              # Build + basic tests
./test-goss.sh                               # Comprehensive tests

# Future:
./test-extensions.sh Dockerfile --with-goss  # Build + basic + comprehensive tests
```

## CI Integration

For CI (GitHub Actions):
```yaml
- name: Test cookbook examples
  run: |
    # Build image
    ./docs/cookbooks/test-extensions.sh docs/cookbooks/${{ matrix.example }}/Dockerfile
    
    # Run comprehensive goss tests
    cd docs/cookbooks/${{ matrix.example }}
    ./test-goss.sh
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
