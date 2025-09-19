# Cookbook Testing Templates

This directory contains template files to help you add goss testing to new cookbook examples.

## Quick Start

### 1. Copy Template Files

For a new cookbook (e.g., `my-new-cookbook`):

```bash
# From project root
cd docs/cookbooks/my-new-cookbook

# Copy and customize the test script
cp ../_templates/test-goss.sh .
chmod +x test-goss.sh

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
# Build your cookbook image first
cd /project/root
./docs/cookbooks/test-extensions.sh docs/cookbooks/my-new-cookbook/Dockerfile

# Run goss tests
cd docs/cookbooks/my-new-cookbook
./test-goss.sh
```

## Template Files

### `test-goss.sh`
- **Generalized test runner** that works for any cookbook
- **Auto-detects** the latest test image if not specified
- **Helpful error messages** and debugging guidance
- **Self-contained** - containers install their own goss binary

### `goss-template.yaml`  
- **Starting template** with common tests and examples
- **Language-specific examples** commented out for easy copying
- **Consistent baseline** tests (workspace, user, git, mise)
- **Extensible** - add your own tests as needed

## Testing Strategy

### What to Test

✅ **Tool availability** - Can execute installed commands  
✅ **Package functionality** - Can import/use installed packages  
✅ **File permissions** - Workspace and key files have correct permissions  
✅ **User setup** - Running as agent user with correct groups  
✅ **Development tools** - git, mise, and other base tools work

### What NOT to Test

❌ **Build process** - test-extensions.sh already covers this  
❌ **Internal implementation details** - Focus on user-visible functionality  
❌ **Performance** - Keep tests fast and focused on correctness

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

This solves the traditional dgoss architecture compatibility problems while maintaining the benefits of goss testing.
