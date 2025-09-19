# Extension Examples

This directory contains **Dockerfile extension patterns** showing different ways to extend the `agentic-container` base image. Each example demonstrates a specific pattern or approach, not complete applications.

## 🛠️ Dockerfile Extension Patterns

### [Python Development](./python-cli/)
**Pattern**: pip package manager usage  
**Dockerfile**: [`python-cli/Dockerfile`](python-cli/Dockerfile)

Shows how to add Python packages via pip (Python already pre-installed).

### [Node.js Development](./nodejs-backend/)
**Pattern**: npm global installs + system packages  
**Dockerfile**: [`nodejs-backend/Dockerfile`](nodejs-backend/Dockerfile)

Shows npm global package installation and adding system dependencies via apt.

### [Ruby Development](./rails-fullstack/)
**Pattern**: mise install new language + gem packages  
**Dockerfile**: [`rails-fullstack/Dockerfile`](rails-fullstack/Dockerfile)

Shows how to install Ruby via mise and add packages with gem.

### [Go Development](./go-microservices/)
**Pattern**: mise install + go install packages  
**Dockerfile**: [`go-microservices/Dockerfile`](go-microservices/Dockerfile)

Shows installing Go via mise and adding Go packages with `go install`.

### [Frontend Development](./react-frontend/)
**Pattern**: npm global tools  
**Dockerfile**: [`react-frontend/Dockerfile`](react-frontend/Dockerfile)

Shows installing frontend development tools globally via npm.

### [Multi-Stage Build](./multistage-production/)
**Pattern**: Build vs Runtime stages  
**Dockerfile**: [`multistage-production/Dockerfile`](multistage-production/Dockerfile)

Shows multi-stage Docker builds for optimized production images.

## 🧪 Testing Extensions

Test any of these patterns:

```bash
# Test a specific pattern (from project root)
./scripts/test-dockerfile.sh docs/cookbooks/python-cli/Dockerfile

# Test with cleanup
./scripts/test-dockerfile.sh docs/cookbooks/go-microservices/Dockerfile --cleanup
```

## 🔑 Key Patterns Demonstrated

- **Using pre-installed languages**: Python, Node.js come ready to use
- **Installing new languages**: Use `mise install language@version`  
- **Package managers**: pip, npm, gem, go install
- **System packages**: apt-get for system dependencies
- **User permissions**: USER root/USER agent patterns
- **Multi-stage builds**: Separate build and runtime environments

## 🎯 Focus

These examples focus on **how to write Dockerfiles**, not on application code. Each demonstrates a specific extension pattern you can adapt for your needs.

---

**Keep it simple. Focus on the Docker patterns, not the applications.**