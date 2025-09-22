# Renovate Configuration Validation Guide

This document outlines our comprehensive approach to validating Renovate configurations both locally and in CI/CD pipelines.

## Overview

Our validation strategy includes multiple layers to ensure configuration quality:

1. **Syntax validation** - JSON5 format correctness
2. **Official validation** - Renovate's built-in validator
3. **Pattern validation** - Custom regex pattern testing
4. **Security scanning** - Configuration safety checks
5. **Coverage analysis** - Ensures all version patterns are handled

## Local Validation

### Quick Validation (Developers)

```bash
# Fast validation before committing (Docker-only)
./scripts/validate-renovate.sh --quick
```

### Comprehensive Validation

```bash
# Full validation with pattern testing (Docker-only)
./scripts/validate-renovate.sh

# Pattern-only validation for debugging
./scripts/validate-renovate.sh --pattern-only
```

### Pre-commit Hooks

Install pre-commit hooks to validate automatically:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually (uses Docker-only validation)
pre-commit run --files .github/renovate.json5
```

## CI/CD Validation

Our GitHub Actions workflow (`.github/workflows/validate-renovate.yml`) runs:

### On Every Push/PR
- Quick validation (Docker-only: syntax + official validator)
- Comprehensive validation (Docker-only: patterns + analysis)
- Security scanning
- Version coverage analysis

### On Configuration Changes
- Enhanced pattern validation (conditional)
- Additional coverage analysis

### Weekly Schedule
- Configuration drift detection
- Ongoing validation health checks

## Validation Layers Explained

### 1. Syntax Validation
- **Tool**: `json5` npm package
- **Purpose**: Ensures JSON5 format is valid
- **Speed**: Very fast (~1s)

### 2. Official Validation
- **Tool**: `renovate-config-validator` via Docker (Docker-only)
- **Purpose**: Renovate's built-in validation
- **Catches**: Schema errors, deprecated options, invalid configurations  
- **Speed**: Fast (~5s)
- **Reliability**: No Node.js ES module conflicts

### 3. Pattern Validation
- **Tool**: Custom scripts with grep/regex
- **Purpose**: Tests that custom managers will match actual files
- **Validates**: 
  - Dockerfile ARG patterns
  - Script version patterns  
  - GitHub Actions version patterns
  - mise.toml tool versions

### 4. Security Scanning
- **Checks**: 
  - Automerge safety (patch-only)
  - Reasonable rate limits
  - Update scheduling
  - Dependency dashboard enabled

### 5. Coverage Analysis
- **Purpose**: Ensures all version declarations have corresponding patterns
- **Reports**: Files with versions vs. configured patterns

## Best Practices Implemented

### ✅ Multi-layered Validation
- Docker-only official validator + custom validation
- Syntax + semantic + pattern validation  
- Security + coverage analysis

### ✅ Performance Optimized
- Fast validation first
- Expensive operations only when needed
- Conditional dry-run based on changes

### ✅ Developer Experience
- Clear status messages with colors
- Helpful error messages
- Quick local validation script
- Pre-commit integration

### ✅ CI Efficiency
- Parallel job execution
- Timeout protection
- Smart change detection
- Weekly drift prevention

## Troubleshooting

### Common Issues

**ES Module Conflicts (ERR_REQUIRE_ESM)**
```bash
# If you get ES module errors with npx, use Docker instead:
docker run --rm -v "$PWD:/usr/src/app" ghcr.io/renovatebot/renovate:latest renovate-config-validator "/usr/src/app/.github/renovate.json5"

# This is now our default approach in scripts
```

**"Renovate configuration validation failed"**
```bash
# Run detailed validation with Docker
docker run --rm -v "$PWD:/usr/src/app" ghcr.io/renovatebot/renovate:latest renovate-config-validator "/usr/src/app/.github/renovate.json5"

# Or with npx (may have ES module issues)
npx --yes --package renovate -- renovate-config-validator .github/renovate.json5
```

**"No custom patterns detected"**
- Verify your Dockerfile has `ARG VERSION=` declarations
- Check that file paths match the `fileMatch` patterns
- Run pattern validation to see what's detected

**"Pre-commit hook failing"**
```bash
# Update pre-commit hooks
pre-commit autoupdate

# Run specific hook
pre-commit run renovate-config-validator --files .github/renovate.json5
```

## Integration with Development Workflow

### Before Committing
1. Run `./scripts/validate-renovate.sh --quick`
2. Pre-commit hooks automatically validate (Docker-only)
3. Fix any issues before pushing

### During PR Review
1. GitHub Actions runs full validation
2. Check validation status in PR
3. Review security and coverage reports

### After Merge
1. Weekly validation ensures ongoing health
2. Renovate App uses validated configuration
3. Monitor dependency dashboard for results

## Extending Validation

To add validation for new pattern types:

1. **Add pattern to renovate.json5**
2. **Update pattern validation** in `validate-renovate.sh`
3. **Test locally** with `./scripts/validate-renovate.sh`
4. **Verify in CI** that new patterns are detected

This comprehensive approach ensures configuration quality while maintaining developer productivity and CI efficiency.
