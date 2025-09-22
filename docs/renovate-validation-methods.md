# Renovate Configuration Validation Methods

## Quick Reference

### ✅ Recommended: Docker Method (No ES Module Issues)

```bash
# Basic validation
docker run --rm -v "$PWD:/usr/src/app" ghcr.io/renovatebot/renovate:latest renovate-config-validator "/usr/src/app/.github/renovate.json5"

# With detailed output
docker run --rm -v "$PWD:/usr/src/app" ghcr.io/renovatebot/renovate:latest renovate-config-validator "/usr/src/app/.github/renovate.json5"
```

### ⚠️ Alternative: NPX Method (May Have ES Module Conflicts)

```bash
# Basic validation (may fail with ES module errors)
npx --yes --package renovate -- renovate-config-validator .github/renovate.json5

# Strict validation
npx --yes --package renovate -- renovate-config-validator --strict .github/renovate.json5
```

### 🤖 GitHub Actions Integration

```yaml
# Reliable Docker-based validation
- name: Validate Renovate Config
  run: |
    docker run --rm -v "$PWD:/usr/src/app" ghcr.io/renovatebot/renovate:latest \
      renovate-config-validator "/usr/src/app/.github/renovate.json5"

# Alternative: GitHub Action (may have compatibility issues)  
- name: Validate Renovate Config
  uses: rinchsan/renovate-config-validator@main
  with:
    pattern: '*.json5'
```

## Problem with ES Modules

**Error:** `Error [ERR_REQUIRE_ESM]: require() of ES Module ... not supported`

**Cause:** Node.js package compatibility conflicts between CommonJS and ES modules in Renovate dependencies

**Solution:** Use Docker-based validation which runs in a controlled environment

## Our Project Setup

- **Local Quick Validation**: `./scripts/validate-renovate-local.sh` (Docker first, npx fallback)
- **CI Comprehensive**: `./scripts/validate-renovate-ci.sh` (Docker + pattern validation)
- **GitHub Actions**: Docker-based validation in workflow
- **Pre-commit**: Automatic validation on commit

## Documentation Sources

- **Official Docs**: [docs.renovatebot.com/config-validation/](https://docs.renovatebot.com/config-validation/)
- **Docker Image**: `ghcr.io/renovatebot/renovate:latest`
- **GitHub Action**: [rinchsan/renovate-config-validator](https://github.com/marketplace/actions/renovate-config-validator)
