# Cookbook Testing Templates

This directory contains template files to help you add goss testing to new
cookbook examples.

## Quick Start

### 1. Create goss.yaml Configuration

For a new cookbook (e.g., `my-new-cookbook`):

```bash
# From project root
cd docs/cookbooks/my-new-cookbook

# Copy and customize the goss configuration
cp ../_templates/goss-template.yaml goss.yaml
```

### 2. Customize goss.yaml

Edit `goss.yaml` to test the specific tools/packages your Dockerfile installs:

- **Remove** the template examples you don't need
- **Add** tests for your specific packages/tools
- **Verify** commands, file paths, and expected output

### 3. Test Your Configuration

```bash
# Build and test your cookbook with unified script
cd /project/root
./scripts/test-dockerfile.sh docs/cookbooks/my-new-cookbook/Dockerfile
```

## Template Files

### `goss-template.yaml`

- **Starting template** with common tests and examples
- **Language-specific examples** commented out for easy copying
- **Consistent baseline** tests (workspace, user, git, mise)
- **Extensible** - add your own tests as needed

## Unified Testing

All cookbooks use the **unified test script** at `scripts/test-dockerfile.sh`:

```bash
# Test any cookbook Dockerfile
./scripts/test-dockerfile.sh docs/cookbooks/<cookbook-name>/Dockerfile [--cleanup]

# Examples
./scripts/test-dockerfile.sh docs/cookbooks/python-cli/Dockerfile
./scripts/test-dockerfile.sh docs/cookbooks/nodejs-backend/Dockerfile --cleanup
```

**Benefits of unified approach:**

- ✅ **Single source of truth** - One script to maintain
- ✅ **Complete workflow** - Builds, tests, and cleans up automatically
- ✅ **Consistent behavior** - Same testing logic for all cookbooks
- ✅ **No image management** - Always tests what you build
- ✅ **Better error handling** - Centralized improvements benefit all

## Testing Strategy

### What to Test

✅ **Tool availability** - Can execute installed commands ✅ **Package
functionality** - Can import/use installed packages ✅ **File permissions** -
Workspace and key files have correct permissions ✅ **User setup** - Running as
agent user with correct groups ✅ **Development tools** - git, mise, and other
base tools work

### What NOT to Test

❌ **Build process** - test-extensions.sh already covers this ❌ **Internal
implementation details** - Focus on user-visible functionality ❌
**Performance** - Keep tests fast and focused on correctness

## Examples

See existing cookbook implementations:

- `docs/cookbooks/python-cli/` - Python package testing
- `docs/cookbooks/nodejs-backend/` - Node.js + TypeScript + system packages

## Architecture

The testing approach uses **container self-installation**:

1. Container installs goss using mise (architecture-agnostic)
2. Container runs tests directly (no volume mounting issues)
3. Works identically on ARM64/x86_64 and in CI
4. No host dependencies beyond Docker

This solves the traditional dgoss architecture compatibility problems while
maintaining the benefits of goss testing.

## Base Test Reuse (No YAML include)

Base validation for standard/dev targets is automatically included at test time.
You do not need to add any YAML `include` directives in your cookbook
`goss.yaml`.

How it works:

- The unified test script mounts multiple goss files and runs goss with repeated
  `-g` flags.
- For standard base: `goss/base-common.yaml` + `goss/standard.yaml` are merged.
- For dev base: `goss/base-common.yaml` + `goss/standard.yaml` + `goss/dev.yaml`
  are merged.
- Your cookbook’s `goss.yaml` is also included.

What you should do:

- Keep cookbook `goss.yaml` focused on cookbook-specific tests only.
- If your cookbook is based on the dev target, the script detects it from your
  `Dockerfile` and includes dev base tests automatically.

## Preview Included Base Tests (Dry Run)

You can preview which goss files will be composed and the exact command that
would run without executing anything by setting `DRY_RUN=true`:

```bash
# Preview cookbook test composition
DRY_RUN=true ./scripts/test-dockerfile.sh docs/cookbooks/<cookbook-name>/Dockerfile

# Preview base target composition (standard or dev)
DRY_RUN=true ./scripts/test-dockerfile.sh standard
DRY_RUN=true ./scripts/test-dockerfile.sh dev
```
