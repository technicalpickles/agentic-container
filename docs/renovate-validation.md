# Renovate Configuration Validation

This document provides a comprehensive guide to validating Renovate
configurations both locally and in CI/CD pipelines.

## Quick Start

### Fast Validation (Recommended for Development)

```bash
# Quick validation (syntax + official validator) - ~10 seconds
./scripts/validate-renovate.sh --quick

# Full validation (includes pattern testing) - ~30 seconds
./scripts/validate-renovate.sh

# Pattern-only validation (for debugging)
./scripts/validate-renovate.sh --pattern-only
```

### Pre-commit Integration

```bash
# Install pre-commit hooks for automatic validation
pip install pre-commit
pre-commit install

# Manual run
pre-commit run --files .github/renovate.json5
```

## Validation Layers

Our validation strategy includes multiple layers to ensure configuration
quality:

### 1. Syntax Validation

- **Tool**: `json5` npm package
- **Purpose**: Ensures JSON5 format is valid
- **Speed**: Very fast (~1s)

### 2. Official Validation

- **Tool**: `renovate-config-validator` via Docker
- **Purpose**: Renovate's built-in validation
- **Catches**: Schema errors, deprecated options, invalid configurations
- **Speed**: Fast (~5s)
- **Reliability**: No Node.js ES module conflicts

### 3. Pattern Validation

- **Tool**: Custom scripts with grep/regex
- **Purpose**: Tests that custom managers will match actual files
- **Validates**:
  - Dockerfile ARG patterns (`ARG NODE_VERSION=`, etc.)
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

## Local Development Workflow

### Before Committing Changes

1. **Quick validation**: `./scripts/validate-renovate.sh --quick`
2. **Pre-commit hooks**: Automatically run on commit
3. **Fix issues**: Address any validation failures before pushing

### Adding New Version Patterns

When adding new tools or version patterns:

1. **Add to Renovate config** (`.github/renovate.json5`)
2. **Update validation expectations** (script will detect automatically)
3. **Test locally** with `./scripts/validate-renovate.sh`
4. **Verify in CI** that new patterns are detected

Example:

```javascript
// 1. Add to renovate.json5 customManagers
{
  "matchStrings": [
    "ARG\\s+(?<depName>NEW_TOOL_VERSION)=(?<currentValue>\\d+\\.\\d+\\.\\d+)"
  ],
  "datasourceTemplate": "github-releases",
  "packageNameTemplate": {"NEW_TOOL_VERSION": "owner/repo"}
}

// 2. Add the actual version declaration to your Dockerfile
echo "ARG NEW_TOOL_VERSION=1.2.3" >> Dockerfile
```

## CI/CD Integration

### GitHub Actions Workflow

Our workflow (`.github/workflows/validate-renovate.yml`) runs:

**Triggered on:**

- Push to `main` or `renovate/**` branches (when config files change)
- Pull requests (when config files change)
- Weekly schedule (Monday 6 AM) - configuration drift detection
- Manual workflow dispatch

**Jobs:**

- **Full validation**: Runs comprehensive validation using Docker-only approach
- **Timeout protection**: 10-minute limit prevents hanging
- **Smart triggering**: Only runs on relevant file changes

### Performance Optimization

- **Fast validation first**: Quick syntax and official validation
- **Conditional execution**: Expensive operations only when needed
- **Docker-only approach**: Eliminates ES module conflicts
- **Parallel execution**: Multiple validation layers run concurrently

## Docker Wrappers

We provide convenient wrapper scripts in `bin/` that hide Docker complexity:

### Config Validation

```bash
# Validate default config (.github/renovate.json5)
./bin/renovate-config-validator

# Validate specific config file
./bin/renovate-config-validator path/to/renovate.json

# Via npm script
npm run renovate-config-validator
```

### Run Renovate

```bash
# Check version
./bin/renovate --version

# Dry run (requires GITHUB_TOKEN)
GITHUB_TOKEN=your_token ./bin/renovate --dry-run repo-name

# Via npm script
npm run renovate -- --version
```

### Environment Variables

The wrappers automatically pass through these environment variables:

- `GITHUB_TOKEN`
- `RENOVATE_TOKEN`
- `LOG_LEVEL`
- `RENOVATE_CONFIG_FILE`
- `RENOVATE_DRY_RUN`

### Benefits

- ✅ **No ES Module Conflicts** - Runs in isolated Docker environment
- ✅ **Simple Interface** - No need to remember Docker commands
- ✅ **Environment Handling** - Automatically passes through required env vars
- ✅ **Consistent Versions** - Always uses same Renovate version as validation

## Expected Validation Output

### Successful Validation

```
✅ PASS: Configuration file exists at .github/renovate.json5
ℹ️  INFO: Found 6 language runtime ARG declarations
ℹ️  INFO: Found 3 development tool ARG declarations
✅ PASS: Renovate configuration has valid JSON5 syntax
✅ PASS: Renovate configuration passed official validation
✅ PASS: Custom managers detected 9 ARG version patterns
✅ PASS: Standard managers detected 3 dependencies
✅ PASS: Comprehensive Renovate validation complete!
```

### Configuration Quality Metrics

- ✅ All version declarations have matching Renovate patterns
- ✅ Grouping reduces PR noise (individual PRs → logical groups)
- ✅ Automerge only applies to safe updates (patches, dev dependencies)
- ✅ Rate limiting prevents overwhelming reviewers

## Troubleshooting

### Common Issues

**"Renovate configuration validation failed"**

```bash
# Run detailed validation with Docker
./bin/renovate-config-validator

# Or directly with Docker
docker run --rm -v "$PWD:/usr/src/app" ghcr.io/renovatebot/renovate:latest renovate-config-validator "/usr/src/app/.github/renovate.json5"
```

**"No custom patterns detected"**

- Verify your Dockerfile has `ARG VERSION=` declarations
- Check that file paths match the `fileMatch` patterns
- Run pattern validation: `./scripts/validate-renovate.sh --pattern-only`

**"Pre-commit hook failing"**

```bash
# Update pre-commit hooks
pre-commit autoupdate

# Run specific hook
pre-commit run renovate-config-validator --files .github/renovate.json5
```

**ES Module Conflicts (Historical)**

- **Issue**: `Error [ERR_REQUIRE_ESM]: require() of ES Module ... not supported`
- **Solution**: Our Docker-only approach eliminates all ES module conflicts
- **Status**: ✅ Resolved - no longer an issue

### Debug Commands

```bash
# Run validation with detailed output
./scripts/validate-renovate.sh --verbose

# Test specific patterns manually
grep -rE "ARG\s+NODE_VERSION=" . --include="*Dockerfile*"

# Validate JSON5 syntax only
json5 .github/renovate.json5

# Direct Docker validation
docker run --rm -v "$PWD:/usr/src/app" ghcr.io/renovatebot/renovate:latest renovate-config-validator "/usr/src/app/.github/renovate.json5"
```

### Performance Considerations

- **Pattern validation**: < 30 seconds, minimal resources
- **Full validation**: 30-60 seconds, requires Docker and network access
- **Weekly validation**: Detects configuration drift without development
  overhead
- **CI timeout**: 10-minute limit prevents hanging builds

## Integration with Development Workflow

### During Development

1. Use `--quick` mode for fast feedback
2. Pre-commit hooks catch issues early
3. Full validation before pushing complex changes

### During PR Review

1. GitHub Actions runs full validation automatically
2. Check validation status in PR checks
3. Review security and coverage reports in output

### After Merge

1. Weekly validation ensures ongoing configuration health
2. Renovate App uses validated configuration
3. Monitor dependency dashboard for actual update behavior

## Maintenance

### Regular Tasks

- **Weekly**: Review validation results from scheduled runs
- **Monthly**: Update validation patterns for new tools
- **Quarterly**: Review and optimize validation performance

### Extending Validation

To add validation for new pattern types:

1. **Add pattern to renovate.json5**
2. **Test locally** with `./scripts/validate-renovate.sh`
3. **Verify in CI** that new patterns are detected
4. **Update documentation** if needed

This comprehensive validation approach ensures configuration quality while
maintaining developer productivity and CI efficiency.
