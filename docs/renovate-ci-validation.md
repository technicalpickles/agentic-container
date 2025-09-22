# Renovate CI Validation Strategy

## Overview

This document describes the comprehensive CI validation strategy for our Renovate configuration, going beyond simple regex pattern testing to validate actual version detection and expected PR creation behavior.

## Validation Components

### 1. Pattern Validation (`scripts/validate-renovate-ci.sh --pattern-only`)

**Fast validation (< 30 seconds)** that checks:
- Configuration file exists and is syntactically valid
- Regex patterns match actual version declarations in codebase
- Expected number of patterns are detected

**Use case:** Quick feedback during development

### 2. Version Detection Validation (`scripts/validate-renovate-ci.sh --detection-only`)

**Comprehensive validation (2-5 minutes)** that:
- Creates test scenarios with known outdated versions
- Runs Renovate dry-run against test files
- Parses output to verify Renovate detects updates
- Validates expected PR creation behavior

**Use case:** Thorough validation when Renovate config changes

### 3. Real-World Validation (`scripts/validate-renovate-ci.sh`)

**Full validation suite** that includes:
- Pattern validation
- Version detection validation
- Current version vs. latest release checking
- Configuration integrity validation
- Expected behavior analysis

**Use case:** Complete confidence before deploying configuration changes

## CI Integration Strategy

### GitHub Actions Workflows

#### 1. `.github/workflows/validate-renovate.yml`

Triggered on:
- Push to `main` or `renovate/**` branches (when config files change)
- Pull requests (when config files change)  
- Weekly schedule (Monday 6 AM) - configuration drift detection
- Manual workflow dispatch

**Jobs:**

1. **`validate-config`** - Runs comprehensive validation
2. **`validate-syntax`** - JSON5 syntax validation with json5 tool
3. **`check-version-coverage`** - Analyzes pattern coverage
4. **`security-scan`** - Security configuration review

### Smart Validation Triggers

The CI uses intelligent triggering to balance thoroughness with performance:

```yaml
# Fast validation always runs
- name: Run pattern validation (fast)  
  run: ./scripts/validate-renovate-ci.sh --pattern-only

# Expensive dry-run only on config changes
- name: Detect configuration changes
  id: changes
  run: |
    if git diff --name-only HEAD~1 HEAD | grep -q '.github/renovate.json5'; then
      echo "renovate_config_changed=true" >> $GITHUB_OUTPUT
    fi

- name: Run Renovate dry-run validation (on config changes)
  if: steps.changes.outputs.renovate_config_changed == 'true'
  run: ./scripts/validate-renovate-ci.sh --detection-only
```

## Real Configuration Testing

### Using Actual Repository Files

The validation runs Renovate dry-run against the actual repository using the real `.github/renovate.json5` configuration:

- **Real Dockerfiles**: Tests against actual `Dockerfile`, `docs/cookbooks/*/Dockerfile`
- **Real Scripts**: Tests against actual `scripts/*.sh` files  
- **Real Workflows**: Tests against actual `.github/workflows/*.yml` files
- **Real Dependencies**: Tests against actual `package.json`, `mise.toml`

### Validation Logic

1. **Run Renovate dry-run** using actual `.github/renovate.json5` config
2. **Parse output** for:
   - Custom manager matches (`ARG.*VERSION`)
   - Standard manager detection (`package.json`, `FROM.*:`)
   - Update availability detection
   - File processing confirmation
3. **Validate expected behavior** matches real configuration

## Expected Validation Results

### Successful Validation Output

```
✅ PASS: Configuration file exists at .github/renovate.json5
ℹ️  INFO: Found 6 language runtime ARG declarations
ℹ️  INFO: Found 3 development tool ARG declarations
ℹ️  INFO: Running Renovate dry-run with actual configuration...
✅ PASS: Renovate dry-run completed successfully
ℹ️  INFO: Processing 9 Dockerfile(s), 5 script(s)
✅ PASS: Custom managers detected 9 ARG version patterns
✅ PASS: Standard managers detected 3 dependencies
ℹ️  INFO: nodejs/node: 24.8.0 → 24.9.0 available
✅ PASS: Renovate configuration has valid JSON5 syntax
ℹ️  INFO: Total custom patterns configured: 10
✅ PASS: Comprehensive Renovate validation complete!
```

### Expected CI Behavior

When Renovate configuration is working correctly, the CI should:

1. **Pattern Validation**: Detect all version patterns in codebase
2. **Detection Validation**: Confirm Renovate recognizes outdated versions
3. **Syntax Validation**: Ensure JSON5 is valid and converts to JSON
4. **Coverage Analysis**: Verify patterns cover actual version declarations
5. **Security Scan**: Confirm safe automerge and rate limiting settings

## Maintenance Guidelines

### Adding New Version Patterns

When adding new tools or version patterns:

1. **Add to Renovate config** (`.github/renovate.json5`)
2. **Update validation script** to check for the new pattern
3. **Add test scenario** with known outdated version
4. **Update documentation** with expected behavior

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

// 2. Add to validation script pattern detection
new_tool_matches=$(grep -rE "ARG\s+NEW_TOOL_VERSION=" . --include="*Dockerfile*" | wc -l)

// 3. Add the actual version declaration to your Dockerfile
echo "ARG NEW_TOOL_VERSION=1.2.3" >> Dockerfile
```

### Troubleshooting Failed Validation

#### Common Issues

1. **Pattern not matching**: Check regex escaping and file paths
2. **Dry-run timeout**: Normal in CI - validation continues with partial results
3. **API rate limits**: GitHub API calls may hit rate limits in CI
4. **Version detection fails**: Check datasource and packageNameTemplate

#### Debug Steps

```bash
# Run validation locally with debug output
LOG_LEVEL=debug ./scripts/validate-renovate-ci.sh

# Test specific patterns
grep -rE "ARG\s+NODE_VERSION=" . --include="*Dockerfile*"

# Validate JSON5 syntax
json5 .github/renovate.json5

# Manual dry-run test with actual config
RENOVATE_CONFIG_FILE=.github/renovate.json5 npx renovate --dry-run=full --platform=local .
```

### Performance Considerations

#### Optimization Strategies

1. **Conditional execution**: Only run expensive validation on config changes
2. **Timeout limits**: Prevent hanging in CI environments
3. **Caching**: Use Node.js cache for npm dependencies
4. **Parallel jobs**: Run syntax and pattern validation concurrently

#### Resource Usage

- **Pattern validation**: < 30 seconds, minimal resources
- **Full validation**: 2-5 minutes, requires Node.js and network access
- **Weekly validation**: Detects configuration drift without overhead

## Integration with Renovate Deployment

This validation strategy is designed to work with the Renovate deployment phases:

### Phase 1: Pre-Installation Validation
- **Before** installing Mend Renovate App
- Validates configuration will work correctly
- Prevents common setup issues

### Phase 2: Post-Installation Validation  
- **After** Renovate App is installed
- Monitors actual PR creation matches expectations
- Validates grouping and automerge behavior

### Phase 3: Ongoing Monitoring
- Weekly validation detects configuration drift
- PR analysis confirms expected behavior
- Performance monitoring ensures CI efficiency

## Success Metrics

### Configuration Quality
- ✅ All version declarations have matching Renovate patterns
- ✅ Grouping reduces PR noise (7-10 individual PRs → 3-4 groups)
- ✅ Automerge only applies to safe updates (patches, dev dependencies)
- ✅ Rate limiting prevents overwhelming reviewers

### CI Performance
- ✅ Pattern validation completes in < 30 seconds
- ✅ Full validation completes in < 5 minutes  
- ✅ No false positives or flaky test failures
- ✅ Clear feedback on configuration issues

### Developer Experience
- ✅ Fast feedback during Renovate config development
- ✅ Clear documentation for adding new patterns
- ✅ Helpful error messages for troubleshooting
- ✅ Confidence in production deployment

This validation strategy ensures our Renovate configuration works correctly before installation and continues working as the codebase evolves.
