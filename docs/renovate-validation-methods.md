# Renovate Configuration Validation Methods

## Quick Reference

### ✅ Recommended: Consolidated Docker-Only Script

```bash
# Quick validation (syntax + official validator)
./scripts/validate-renovate.sh --quick

# Full validation (syntax + official + patterns + analysis)
./scripts/validate-renovate.sh

# Pattern validation only (for debugging)
./scripts/validate-renovate.sh --pattern-only
```

### 🐳 Direct Docker Method (Advanced)

```bash
# Direct Docker validation (used internally by our script)
docker run --rm -v "$PWD:/usr/src/app" ghcr.io/renovatebot/renovate:latest renovate-config-validator "/usr/src/app/.github/renovate.json5"
```

### 🤖 GitHub Actions Integration

```yaml
# Our consolidated approach
- name: Quick Validation
  run: ./scripts/validate-renovate.sh --quick

- name: Full Validation  
  run: ./scripts/validate-renovate.sh
```

## ES Module Issues (Solved)

**Previous Error:** `Error [ERR_REQUIRE_ESM]: require() of ES Module ... not supported`

**Cause:** Node.js package compatibility conflicts between CommonJS and ES modules in Renovate dependencies

**✅ Solution:** Docker-only approach eliminates all ES module conflicts

## Our Project Setup

- **Consolidated Script**: `./scripts/validate-renovate.sh` (Docker-only, all modes)
- **Quick Mode**: `--quick` for fast validation (syntax + official)
- **Full Mode**: Default comprehensive validation (patterns + analysis)  
- **GitHub Actions**: Uses consolidated script for all validation
- **Pre-commit**: Automatic quick validation on commit

## Documentation Sources

- **Official Docs**: [docs.renovatebot.com/config-validation/](https://docs.renovatebot.com/config-validation/)
- **Docker Image**: `ghcr.io/renovatebot/renovate:latest`
- **GitHub Action**: [rinchsan/renovate-config-validator](https://github.com/marketplace/actions/renovate-config-validator)
