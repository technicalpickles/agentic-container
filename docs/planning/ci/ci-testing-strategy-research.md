# CI Testing Strategy Research for Agentic Container

## Purpose
Research and document CI testing strategies for ensuring our Docker examples in `docs/examples` work correctly.

## Current State Analysis

### What We Have Now
- **Current CI**: GitHub Actions workflow that builds and publishes container images (standard and dev targets)
- **Example Testing**: Basic `test-extensions.sh` script that:
  - Builds the Dockerfile
  - Runs basic container startup tests
  - Tests mise functionality
  - Checks working directory accessibility
  - Validates user permissions
- **Examples Structure**: 6 different Dockerfile patterns:
  - `python-cli/` - pip package usage
  - `nodejs-backend/` - npm + system packages
  - `rails-fullstack/` - mise install Ruby + gems
  - `go-microservices/` - mise install Go + go install
  - `react-frontend/` - npm global tools
  - `multistage-production/` - multi-stage builds

### Current Test Approach
The existing `test-extensions.sh` script provides basic validation:
```bash
# Basic tests it runs:
1. Docker build succeeds
2. Container starts successfully
3. mise command works
4. /workspace directory accessible
5. User permissions check (non-root preferred)
```

## Gaps in Current Testing

1. **No systematic validation of installed packages** - We verify mise works but don't test if specific packages are properly installed
2. **No command execution testing** - Examples show commands like `npm install -g typescript` but we don't verify they work
3. **No integration with main CI pipeline** - The test script exists but isn't run automatically
4. **Limited cross-platform testing** - No ARM64 validation of examples
5. **No static analysis** - No linting of Dockerfiles
6. **No documentation validation** - README examples aren't automatically tested

## Research: Docker Container Testing Tools & Frameworks

### 1. Dockerfile Linting Tools

#### Hadolint
- **Purpose**: Dockerfile static analysis and linting
- **Features**: 
  - Checks for best practices
  - Security vulnerability detection
  - Performance optimization suggestions
  - GitHub Actions integration available
- **Usage**: Can be integrated into CI to catch issues before building
- **Example**: 
```yaml
- name: Dockerfile Lint
  uses: hadolint/hadolint-action@v3.1.0
  with:
    dockerfile: Dockerfile
```

### 2. Container Runtime Testing Tools

Based on research, here are key tools for testing Docker containers:

#### Goss + dgoss
- **Purpose**: Quick and easy server testing/validation
- **Features**:
  - YAML-based test specifications
  - Can test files, packages, services, ports, users, etc.
  - `dgoss` wrapper specifically for Docker containers
  - Fast execution
- **Example test file** (`goss.yaml`):
```yaml
package:
  python3:
    installed: true
  nodejs:
    installed: true
file:
  /usr/local/bin/mise:
    exists: true
    mode: "0755"
command:
  "python3 --version":
    exit-status: 0
    stdout:
      - "Python 3"
  "node --version":
    exit-status: 0
    stdout:
      - "v"
user:
  agent:
    exists: true
    groups:
      - agent
```

#### Container Structure Test (Google)
- **Purpose**: Validate container structure and contents
- **Features**:
  - YAML/JSON configuration
  - Command tests, file existence tests, metadata tests
  - Can test multiple images at once
- **Example config**:
```yaml
schemaVersion: 2.0.0
commandTests:
  - name: "Python version"
    command: ["python3", "--version"]
    expectedOutput: ["Python 3.*"]
  - name: "Node version"
    command: ["node", "--version"]
    expectedOutput: ["v.*"]
fileExistenceTests:
  - name: "mise binary exists"
    path: "/usr/local/bin/mise"
    shouldExist: true
```

### 3. Integration Testing Frameworks

#### Testcontainers
- **Purpose**: Integration testing with real containers
- **Languages**: Available for Java, .NET, Python, Node.js, Go, etc.
- **Use case**: For testing applications that depend on services (databases, message queues, etc.)
- **Not ideal for our use case** - More for application testing than Dockerfile validation

### 4. Documentation Testing Tools

#### DocToc
- **Purpose**: Automatically generate table of contents for markdown files
- **Usage**: Can be integrated into CI to ensure consistent documentation

#### Markdown Linting
- **Tools**: `markdownlint`, `remark-lint`
- **Purpose**: Ensure consistent markdown formatting and catch common errors

#### Doc Detective
- **Purpose**: Parse documentation and run tests against procedures
- **Features**: Can step through documentation procedures and validate they work
- **Use case**: Perfect for testing our README examples

#### Vale
- **Purpose**: Syntax-aware prose linter
- **Features**: Enforce style and consistency in documentation
- **Use case**: Maintain documentation quality standards

## Recommended CI Testing Strategy

### Phase 1: Enhanced Dockerfile Testing
1. **Add Hadolint** to CI pipeline for static analysis
2. **Enhance test-extensions.sh** with more specific validations
3. **Create test specs** for each example using Goss or Container Structure Test

### Phase 2: Automated Example Testing
1. **Matrix strategy** in GitHub Actions to test all examples
2. **Cross-platform testing** (AMD64 + ARM64)
3. **Package validation** - ensure installed tools actually work

### Phase 3: Documentation Validation  
1. **Link checking** in documentation
2. **Code block extraction and testing** from README examples
3. **Automated documentation updates** when examples change

## Detailed Implementation Plan

### 1. Immediate Wins (Week 1)

#### Add Hadolint to CI Pipeline
```yaml
# Add to .github/workflows/build-and-publish.yml
jobs:
  lint-dockerfiles:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Lint main Dockerfile
      uses: hadolint/hadolint-action@v3.1.0
      with:
        dockerfile: Dockerfile
    - name: Lint example Dockerfiles
      run: |
        find docs/examples -name "Dockerfile" -exec hadolint {} \;
```

#### Enhance test-extensions.sh
Add specific tests for each example type:
- Python: Verify `pip list` shows expected packages
- Node.js: Test `npm list -g` and specific tools work
- Go: Verify `go version` and installed packages
- Ruby: Test `gem list` and rails commands

### 2. Systematic Container Testing (Week 2)

#### Choose Primary Tool: Goss + dgoss
**Reasoning**: 
- Simpler setup than Container Structure Test
- YAML configuration matches our style
- Fast execution
- Wide adoption in Docker community

#### Create Goss Test Files
For each example, create a corresponding `goss.yaml`:

**python-cli/goss.yaml**:
```yaml
command:
  "python3 --version":
    exit-status: 0
    stdout: ["Python 3"]
  "pip list":
    exit-status: 0
    stdout:
      - "click"
      - "typer"
      - "rich"
      - "pydantic"
user:
  agent:
    exists: true
file:
  /workspace:
    exists: true
    filetype: directory
```

**nodejs-backend/goss.yaml**:
```yaml
command:
  "node --version":
    exit-status: 0
    stdout: ["v"]
  "npm list -g typescript":
    exit-status: 0
  "which psql":
    exit-status: 0
package:
  postgresql-client:
    installed: true
user:
  agent:
    exists: true
```

### 3. CI Integration (Week 3)

#### New GitHub Actions Job
```yaml
jobs:
  test-examples:
    runs-on: ubuntu-latest
    needs: build
    strategy:
      matrix:
        example:
          - python-cli
          - nodejs-backend
          - rails-fullstack
          - go-microservices
          - react-frontend
          - multistage-production
        platform:
          - linux/amd64
          # - linux/arm64  # Add later for cross-platform testing
    steps:
    - uses: actions/checkout@v4
    - name: Install goss and dgoss
      run: |
        curl -fsSL https://goss.rocks/install | sh
        sudo cp goss /usr/local/bin/
        curl -fsSL https://raw.githubusercontent.com/aelsabbahy/goss/master/extras/dgoss/dgoss -o dgoss
        chmod +x dgoss
        sudo mv dgoss /usr/local/bin/
    
    - name: Test ${{ matrix.example }}
      run: |
        cd docs/examples/${{ matrix.example }}
        if [ -f goss.yaml ]; then
          # Build image
          docker build -t test-${{ matrix.example }} .
          # Run goss tests
          dgoss run test-${{ matrix.example }}
        else
          echo "No goss.yaml found, falling back to basic test"
          ../test-extensions.sh Dockerfile
        fi
```

### 4. Documentation Testing (Week 4)

#### Add markdown linting
```yaml
jobs:
  lint-docs:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
    - name: Install markdownlint
      run: npm install -g markdownlint-cli
    - name: Lint markdown files
      run: markdownlint docs/ README.md CONTRIBUTING.md
```

#### Add link checking
```yaml
    - name: Check links
      uses: gaurav-nelson/github-action-markdown-link-check@v1
      with:
        use-quiet-mode: 'yes'
        use-verbose-mode: 'yes'
```

## Tool Comparison Matrix

| Tool | Setup Complexity | Features | Maintenance | Best For |
|------|------------------|----------|-------------|----------|
| **Goss + dgoss** | Low | Runtime testing, YAML config | Low | Quick container validation |
| **Container Structure Test** | Medium | Comprehensive testing | Medium | Complex validation needs |
| **Hadolint** | Very Low | Dockerfile linting | Very Low | Static analysis (essential) |
| **markdownlint** | Low | Markdown consistency | Low | Documentation quality |
| **Enhanced test-extensions.sh** | Low | Custom validation | Medium | Specific test cases |

## Success Metrics

### Phase 1 Success Criteria
- [ ] Hadolint integrated and passing
- [ ] All example Dockerfiles lint cleanly
- [ ] Enhanced test script validates package installations
- [ ] CI fails fast on broken examples

### Phase 2 Success Criteria  
- [ ] Goss tests created for all examples
- [ ] Matrix testing covers all examples
- [ ] Cross-platform testing (AMD64 + ARM64)
- [ ] Test execution time under 10 minutes total

### Phase 3 Success Criteria
- [ ] Documentation links automatically validated
- [ ] Markdown consistently formatted
- [ ] README examples automatically tested
- [ ] Documentation quality gates in place

## Risk Mitigation

### Risk: CI Pipeline Takes Too Long
**Mitigation**: 
- Run linting and documentation tests in parallel
- Cache Docker layers aggressively
- Use matrix strategy to parallelize example testing

### Risk: False Positives from Tool Changes
**Mitigation**:
- Pin tool versions in CI
- Regular review and update of test specifications
- Fallback to basic tests when advanced tests fail

### Risk: Maintenance Overhead
**Mitigation**:
- Start with simple tools (Hadolint, basic Goss tests)
- Automate test generation where possible
- Document test patterns for team understanding

## Resource Requirements

### Time Investment
- **Week 1**: 8 hours (Hadolint + enhanced testing)
- **Week 2**: 12 hours (Goss setup + test creation)
- **Week 3**: 8 hours (CI integration)
- **Week 4**: 6 hours (Documentation testing)
- **Total**: ~34 hours over 4 weeks

### Ongoing Maintenance
- **Monthly**: Review and update test specifications (~2 hours)
- **Per new example**: Create corresponding Goss test (~30 minutes)
- **Tool updates**: Quarterly review of pinned versions (~1 hour)

## Next Steps

1. **Immediate**: Add Hadolint to current CI pipeline
2. **This week**: Enhance test-extensions.sh with package validation
3. **Next week**: Choose between Goss and Container Structure Test
4. **Following week**: Implement chosen tool for 2-3 examples as pilot

---

## Conclusion

The recommended approach provides a layered testing strategy:

1. **Static Analysis** (Hadolint) - Catch issues before building
2. **Build Testing** (Enhanced test script) - Ensure examples build and run
3. **Runtime Validation** (Goss) - Verify containers work as expected
4. **Documentation Quality** (markdownlint, link checking) - Maintain docs

This approach balances thoroughness with maintainability, starting with high-impact, low-effort improvements and building up to comprehensive testing coverage.

*Research completed: Ready for implementation discussion and tool selection.*