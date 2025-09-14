# Contributing to Agentic Container

Thank you for your interest in contributing to agentic-container! This document provides guidelines and information for contributors.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Code Style](#code-style)
- [Testing](#testing)
- [Documentation](#documentation)

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Docker Desktop or Docker Engine installed
- Git configured with your GitHub account
- Basic understanding of Docker and containerization
- Familiarity with shell scripting (for tooling contributions)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

```bash
git clone https://github.com/YOUR_USERNAME/agentic-container.git
cd agentic-container
```

3. Add the upstream remote:

```bash
git remote add upstream https://github.com/ORIGINAL_OWNER/agentic-container.git
```

## Development Setup

### Build and Test Locally

Build all image targets:

```bash
# Build specific targets
docker build --target base -t agentic-container:base .
docker build --target tools -t agentic-container:tools .
docker build --target dev -t agentic-container:dev .

# Test the images
docker run --rm -it agentic-container:base which mise
docker run --rm -it agentic-container:tools starship --version
docker run --rm -it agentic-container:dev mise list
```

### Test Extension Scripts

Test the helper scripts:

```bash
# Test extend-image script
./scripts/extend-image.sh init base
./scripts/extend-image.sh build test-image:latest

# Test publish script (dry run)
./scripts/publish-extended-image.sh \
  --dry-run \
  --language python@3.11 \
  base \
  test/my-image:v1.0.0
```

### Development Environment

Use the container for development:

```bash
docker-compose up -d dev
docker-compose exec dev bash

# Or use VS Code Dev Containers
# Open in VS Code and select "Reopen in Container"
```

## Contributing Guidelines

### Types of Contributions

We welcome several types of contributions:

1. **Bug Fixes**: Fix issues in existing functionality
2. **Feature Additions**: Add new capabilities or tools
3. **Language Support**: Add support for new programming languages  
4. **Templates**: Create new templates for specific use cases
5. **Documentation**: Improve or add documentation
6. **Testing**: Add or improve tests

### Language Additions

To add support for a new programming language:

1. **Research latest stable versions** using sites like [endoflife.date](https://endoflife.date/)
2. **Create a build stage** in the Dockerfile:

```dockerfile
FROM base AS newlang-stage
# Install the language runtime using mise or direct installation
RUN mise install newlang@X.Y.Z
```

3. **Create a single-language target**:

```dockerfile
FROM tools AS newlang
COPY --from=newlang-stage $MISE_DATA_DIR/installs/newlang $MISE_DATA_DIR/installs/newlang
RUN mise use -g newlang@X.Y.Z
```

4. **Update the full dev target** to include the new language
5. **Update GitHub Actions workflow** to build the new target
6. **Add documentation** for the new language

### Tool Additions

To add development tools:

1. **Check if available via mise**: `mise list-remote TOOL_NAME`
2. **Add to appropriate stage**:

```dockerfile
FROM base AS tool-stage
RUN mise install tool@latest

# Or for tools not in mise
RUN curl -sSL https://install-script.com | sh
```

3. **Update documentation** with the new tool

### Template Creation

To create new templates:

1. **Create template file**: `templates/Dockerfile.your-template`
2. **Document the template** in README.md
3. **Test the template** thoroughly
4. **Update extension scripts** if needed

## Pull Request Process

### Before Submitting

1. **Ensure your code follows** our style guidelines
2. **Test your changes** thoroughly
3. **Update documentation** as needed
4. **Add or update tests** for your changes
5. **Run linting and formatting** tools

### Submitting the PR

1. **Create a feature branch**:

```bash
git checkout -b feature/your-feature-name
```

2. **Make your changes** and commit them:

```bash
git add .
git commit -m "feat: add support for Rust language runtime"
```

3. **Push to your fork**:

```bash
git push origin feature/your-feature-name
```

4. **Create a Pull Request** on GitHub

### PR Requirements

Your pull request must:

- [ ] **Build successfully** on all targets
- [ ] **Include tests** for new functionality  
- [ ] **Update documentation** for user-facing changes
- [ ] **Follow commit message conventions**
- [ ] **Be based on the latest main branch**

### Commit Message Convention

We use conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (no functional changes)
- `refactor`: Code refactoring
- `test`: Adding or modifying tests
- `chore`: Build process or auxiliary tool changes

Examples:
```
feat(docker): add Rust language support
fix(scripts): resolve extension script path issue
docs(readme): update usage examples
```

## Code Style

### Dockerfile Style

Follow these guidelines for Dockerfile changes:

```dockerfile
# Use descriptive comments and section headers
# =============================================================================
# SECTION NAME: Brief description
# =============================================================================

# Group related RUN commands to minimize layers
RUN apt-get update && apt-get install -y \
    package1 \
    package2 \
    # Comments for complex packages
    package3 \
    && rm -rf /var/lib/apt/lists/*

# Use specific versions where possible
RUN mise install python@3.11.5 node@20.0.0

# Maintain consistent indentation (4 spaces)
```

### Shell Script Style

Follow these guidelines for shell scripts:

```bash
#!/usr/bin/env bash

# Script header with description
# script-name.sh - Brief description of what the script does

set -euo pipefail

# Use meaningful variable names
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_REGISTRY="${BASE_REGISTRY:-ghcr.io/your-repo/agentic-container}"

# Function documentation
show_help() {
    cat << EOF
Usage: script-name.sh [OPTIONS]
Brief description
EOF
}

# Error handling
main() {
    local argument="${1:-}"
    
    if [[ -z "$argument" ]]; then
        echo "ERROR: Argument required" >&2
        exit 1
    fi
    
    # Implementation
}

main "$@"
```

### Documentation Style

- Use clear, concise language
- Include code examples for complex concepts
- Organize content with headers and TOCs
- Use tables for structured information
- Keep line length reasonable (~100 characters)

## Testing

### Manual Testing

Before submitting, test your changes:

```bash
# Build all affected targets
docker build --target base -t test-base .
docker build --target your-new-target -t test-new .

# Test functionality
docker run --rm test-base which mise
docker run --rm test-new your-new-command --version

# Test extension scripts
./scripts/extend-image.sh init your-new-target
./scripts/extend-image.sh build test-extended:latest
```

### Integration Testing

Test with realistic scenarios:

```bash
# Test dev container workflow
docker-compose -f docker-compose.yml up -d
docker-compose exec dev bash -c "mise list && python --version && node --version"

# Test template usage
cp templates/Dockerfile.your-template ./test/
cd test && docker build -f Dockerfile.your-template .
```

### Testing Checklist

- [ ] **All image targets build** successfully
- [ ] **Language runtimes work** as expected  
- [ ] **Tools are accessible** and functional
- [ ] **Extension scripts work** with your changes
- [ ] **Templates build and run** correctly
- [ ] **Documentation is accurate** and complete

## Documentation

### What to Document

Document your changes if they:

- Add new functionality or tools
- Change existing behavior  
- Introduce new configuration options
- Add new templates or examples
- Modify the extension API

### Documentation Locations

- **README.md**: User-facing features and quick start
- **docs/USAGE.md**: Detailed usage examples
- **docs/API.md**: Technical reference and API details
- **Inline comments**: Complex code explanations
- **Script help**: Command-line tool documentation

### Documentation Style

- Start with purpose and use cases
- Provide working examples  
- Explain configuration options
- Include troubleshooting information
- Link to related documentation

## Getting Help

- **Questions**: Use GitHub Discussions
- **Bug Reports**: Open a GitHub Issue
- **Feature Requests**: Open a GitHub Issue with the "enhancement" label
- **Security Issues**: Email maintainers directly (see SECURITY.md)

## Recognition

Contributors are recognized in:

- GitHub commit history
- Release notes for significant contributions  
- CONTRIBUTORS.md file (if created)

Thank you for contributing to agentic-container! 🚀
