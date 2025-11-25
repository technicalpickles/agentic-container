# Example Goss Test Configurations

## Purpose

Provide concrete examples of what Goss test configurations would look like for
each of our Docker examples.

## Goss Testing Overview

Goss is a YAML-based server testing framework. For Docker containers, we use
`dgoss` which:

1. Builds the Docker image
2. Runs the container
3. Executes the tests inside the running container
4. Reports results

## Example Test Files

### 1. Python CLI Example (`python-cli/goss.yaml`)

```yaml
# python-cli/goss.yaml - Test Python development environment
command:
  # Verify Python is available and working
  'python3 --version':
    exit-status: 0
    stdout:
      - 'Python 3'
    timeout: 5000

  # Verify pip packages are installed
  'pip list':
    exit-status: 0
    stdout:
      - 'click'
      - 'typer'
      - 'rich'
      - 'pydantic'
    timeout: 5000

  # Test that packages can be imported
  ? 'python3 -c ''import click, typer, rich, pydantic; print("All packages
    imported successfully")'''
  : exit-status: 0
    stdout:
      - 'All packages imported successfully'
    timeout: 10000

  # Verify click CLI works
  "python3 -c 'import click; print(click.__version__)'":
    exit-status: 0
    stdout:
      - '.*' # Any version string
    timeout: 5000

# Verify user setup
user:
  agent:
    exists: true
    groups:
      - 'agent'

# Verify workspace directory
file:
  /workspace:
    exists: true
    filetype: directory
    owner: 'agent'

  # Verify mise is available
  /usr/local/bin/mise:
    exists: true
    mode: '0755'
```

### 2. Node.js Backend Example (`nodejs-backend/goss.yaml`)

```yaml
# nodejs-backend/goss.yaml - Test Node.js development environment
command:
  # Verify Node.js is working
  'node --version':
    exit-status: 0
    stdout:
      - 'v' # Starts with 'v' (e.g., v18.17.0)
    timeout: 5000

  # Verify npm is working
  'npm --version':
    exit-status: 0
    timeout: 5000

  # Verify global packages are installed
  'npm list -g --depth=0 typescript':
    exit-status: 0
    stdout:
      - 'typescript'
    timeout: 10000

  'npm list -g --depth=0 @types/node':
    exit-status: 0
    stdout:
      - '@types/node'
    timeout: 10000

  'npm list -g --depth=0 ts-node':
    exit-status: 0
    stdout:
      - 'ts-node'
    timeout: 10000

  'npm list -g --depth=0 nodemon':
    exit-status: 0
    stdout:
      - 'nodemon'
    timeout: 10000

  # Test TypeScript compiler works
  'tsc --version':
    exit-status: 0
    stdout:
      - 'Version'
    timeout: 5000

  # Test ts-node works
  'ts-node --version':
    exit-status: 0
    timeout: 5000

  # Test nodemon works
  'nodemon --version':
    exit-status: 0
    timeout: 5000

  # Verify PostgreSQL client is available (system dependency)
  'psql --version':
    exit-status: 0
    stdout:
      - 'psql'
    timeout: 5000

# Verify system packages
package:
  postgresql-client:
    installed: true

# User verification
user:
  agent:
    exists: true
    groups:
      - 'agent'

# File verification
file:
  /workspace:
    exists: true
    filetype: directory
    owner: 'agent'

  /usr/local/bin/mise:
    exists: true
    mode: '0755'
```

### 3. Go Microservices Example (`go-microservices/goss.yaml`)

```yaml
# go-microservices/goss.yaml - Test Go development environment
command:
  # Verify Go is installed and working
  'go version':
    exit-status: 0
    stdout:
      - 'go version go1.23.5'
    timeout: 5000

  # Verify Go environment
  'go env GOPATH':
    exit-status: 0
    timeout: 5000

  'go env GOROOT':
    exit-status: 0
    timeout: 5000

  # Verify air (live reload tool) is installed
  'air -v':
    exit-status: 0
    stdout:
      - 'air' # Should contain "air" in version output
    timeout: 5000

  # Test that Go can build a simple program
  ? 'echo ''package main; import "fmt"; func main() { fmt.Println("Hello Go")
    }'' > /tmp/test.go && go run /tmp/test.go'
  : exit-status: 0
    stdout:
      - 'Hello Go'
    timeout: 10000

  # Verify mise can see Go
  'mise current go':
    exit-status: 0
    stdout:
      - '1.23.5'
    timeout: 5000

# User verification
user:
  agent:
    exists: true
    groups:
      - 'agent'

# File verification
file:
  /workspace:
    exists: true
    filetype: directory
    owner: 'agent'

  /usr/local/bin/mise:
    exists: true
    mode: '0755'

  # Verify Go binary is available
  /home/agent/.local/share/mise/installs/go/1.23.5/bin/go:
    exists: true
    mode: '0755'
```

### 4. Rails Fullstack Example (`rails-fullstack/goss.yaml`)

```yaml
# rails-fullstack/goss.yaml - Test Ruby/Rails development environment
command:
  # Verify Ruby is installed via mise
  'mise current ruby':
    exit-status: 0
    stdout:
      - '3' # Should be Ruby 3.x
    timeout: 5000

  # Verify Ruby works
  'ruby --version':
    exit-status: 0
    stdout:
      - 'ruby 3'
    timeout: 5000

  # Verify gem works
  'gem --version':
    exit-status: 0
    timeout: 5000

  # Test basic Ruby functionality
  'ruby -e ''puts "Ruby is working"''':
    exit-status: 0
    stdout:
      - 'Ruby is working'
    timeout: 5000

  # Verify bundler is available
  'bundle --version':
    exit-status: 0
    stdout:
      - 'Bundler version'
    timeout: 5000

# User verification
user:
  agent:
    exists: true
    groups:
      - 'agent'

# File verification
file:
  /workspace:
    exists: true
    filetype: directory
    owner: 'agent'

  /usr/local/bin/mise:
    exists: true
    mode: '0755'
```

### 5. React Frontend Example (`react-frontend/goss.yaml`)

```yaml
# react-frontend/goss.yaml - Test React/frontend development environment
command:
  # Verify Node.js
  'node --version':
    exit-status: 0
    stdout:
      - 'v'
    timeout: 5000

  # Verify npm
  'npm --version':
    exit-status: 0
    timeout: 5000

  # Verify global frontend tools are installed
  'npm list -g --depth=0 @vitejs/create-app':
    exit-status: 0
    stdout:
      - '@vitejs/create-app'
    timeout: 10000

  'npm list -g --depth=0 create-react-app':
    exit-status: 0
    stdout:
      - 'create-react-app'
    timeout: 10000

  'npm list -g --depth=0 eslint':
    exit-status: 0
    stdout:
      - 'eslint'
    timeout: 10000

  'npm list -g --depth=0 prettier':
    exit-status: 0
    stdout:
      - 'prettier'
    timeout: 10000

  # Test that tools work
  'create-react-app --version':
    exit-status: 0
    timeout: 5000

  'eslint --version':
    exit-status: 0
    timeout: 5000

  'prettier --version':
    exit-status: 0
    timeout: 5000

# User verification
user:
  agent:
    exists: true
    groups:
      - 'agent'

# File verification
file:
  /workspace:
    exists: true
    filetype: directory
    owner: 'agent'

  /usr/local/bin/mise:
    exists: true
    mode: '0755'
```

### 6. Multistage Production Example (`multistage-production/goss.yaml`)

```yaml
# multistage-production/goss.yaml - Test multistage build result
command:
  # Verify Python is available (from runtime stage)
  "python3 --version":
    exit-status: 0
    stdout:
      - "Python 3"
    timeout: 5000

  # Verify runtime dependencies are installed
  "pip list":
    exit-status: 0
    stdout:
      - "requests"  # Should be installed in runtime stage
    timeout: 5000

  # Verify requests can be imported
  "python3 -c 'import requests; print(requests.__version__)'":
    exit-status: 0
    timeout: 5000

  # Verify build tools are NOT present (they should be in builder stage only)
  "pip list":
    exit-status: 0
    stdout:
      - "!wheel"      # Should NOT contain wheel
      - "!setuptools"  # Should NOT contain setuptools
    timeout: 5000

# User verification
user:
  agent:
    exists: true
    groups:
      - "agent"

# File verification
file:
  /workspace:
    exists: true
    filetype: directory
    owner: "agent"

  /usr/local/bin/mise:
    exists: true
    mode: "0755"
```

## GitHub Actions Integration Example

Here's how these tests would be integrated into our CI pipeline:

```yaml
# .github/workflows/test-examples.yml
name: Test Example Dockerfiles

on:
  push:
    branches: [main, develop]
    paths:
      - 'docs/examples/**'
      - 'Dockerfile'
  pull_request:
    branches: [main]
    paths:
      - 'docs/examples/**'
      - 'Dockerfile'

jobs:
  test-examples:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false # Don't stop other tests if one fails
      matrix:
        example:
          - python-cli
          - nodejs-backend
          - go-microservices
          - rails-fullstack
          - react-frontend
          - multistage-production

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install goss and dgoss
        run: |
          # Install goss
          curl -fsSL https://goss.rocks/install | sh
          sudo cp goss /usr/local/bin/

          # Install dgoss
          curl -fsSL https://raw.githubusercontent.com/aelsabbahy/goss/master/extras/dgoss/dgoss -o dgoss
          chmod +x dgoss
          sudo mv dgoss /usr/local/bin/

      - name: Build base image locally (for testing)
        run: |
          docker build -t agentic-container:latest .

      - name: Test ${{ matrix.example }} example
        run: |
          cd docs/examples/${{ matrix.example }}

          # Update Dockerfile to use local base image for testing
          sed -i 's|ghcr.io/technicalpickles/agentic-container:latest|agentic-container:latest|g' Dockerfile

          # Run tests if goss.yaml exists, otherwise fall back to basic test
          if [ -f goss.yaml ]; then
            echo "Running goss tests for ${{ matrix.example }}"
            dgoss run ${{ matrix.example }}-test
          else
            echo "No goss.yaml found, running basic test for ${{ matrix.example }}"
            ../test-extensions.sh Dockerfile --cleanup
          fi

      - name: Cleanup test images
        if: always()
        run: |
          docker image prune -f
          docker rmi ${{ matrix.example }}-test 2>/dev/null || true
```

## Usage Instructions

### Running Tests Locally

1. **Install goss and dgoss**:

   ```bash
   # Install goss
   curl -fsSL https://goss.rocks/install | sh
   sudo cp goss /usr/local/bin/

   # Install dgoss
   curl -fsSL https://raw.githubusercontent.com/aelsabbahy/goss/master/extras/dgoss/dgoss -o dgoss
   chmod +x dgoss && sudo mv dgoss /usr/local/bin/
   ```

2. **Test a specific example**:

   ```bash
   cd docs/examples/python-cli
   dgoss run python-cli-test
   ```

3. **Test all examples**:
   ```bash
   for example in python-cli nodejs-backend go-microservices rails-fullstack react-frontend multistage-production; do
     echo "Testing $example..."
     cd docs/examples/$example
     if [ -f goss.yaml ]; then
       dgoss run $example-test
     fi
     cd ../../..
   done
   ```

### Creating New Test Files

When adding a new example:

1. Create the Dockerfile following existing patterns
2. Create a corresponding `goss.yaml` test file
3. Test locally with `dgoss run <image-name>`
4. The CI pipeline will automatically pick up the new test

## Benefits of This Approach

1. **Fast Feedback**: Tests run in seconds, not minutes
2. **Comprehensive**: Tests actual functionality, not just build success
3. **Maintainable**: YAML configuration is readable and version-controlled
4. **Parallel**: Matrix strategy tests all examples simultaneously
5. **Reliable**: Tests what users actually experience

## Next Steps

1. **Choose 1-2 examples** to implement as pilot tests
2. **Validate approach** with actual test runs
3. **Refine test specifications** based on results
4. **Roll out** to remaining examples
5. **Integrate** into main CI pipeline

---

_Example configurations ready for implementation and testing._
