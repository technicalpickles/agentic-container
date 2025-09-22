# Renovate Docker Wrappers

Convenient wrapper scripts that hide Docker complexity for running Renovate tools.

## Usage

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

## Environment Variables

The `renovate` wrapper automatically passes through these environment variables to Docker:

- `GITHUB_TOKEN`
- `RENOVATE_TOKEN` 
- `LOG_LEVEL`
- `RENOVATE_CONFIG_FILE`
- `RENOVATE_DRY_RUN`

## Benefits

- ✅ **No ES Module Conflicts** - Runs in isolated Docker environment
- ✅ **Simple Interface** - No need to remember Docker commands
- ✅ **Environment Handling** - Automatically passes through required env vars
- ✅ **Path Handling** - Correctly mounts volumes for file access
- ✅ **Consistent Versions** - Always uses same Renovate version as validation
