# Renovate Implementation Plan for Agentic Container

## Overview

This plan outlines how to implement [Renovate](https://docs.renovatebot.com/) for the agentic-container project to automate dependency updates across Docker images, GitHub Actions, Node.js packages, and various tool versions.

## Phase 1: Initial Setup (Week 1)

### 1.1 Enable Renovate App
1. Install the [Mend Renovate App](https://github.com/apps/renovate) on the repository
2. Copy `scratch/renovate.json5` to `.github/renovate.json5` in the repository root
3. Create initial onboarding PR to validate configuration

### 1.2 Immediate Benefits (No configuration needed)
✅ **These will work automatically:**
- GitHub Actions version updates (`@v4` → `@v5`)
- Node.js dependencies in `package.json` (`prettier: ^3.2.5`)
- Docker base images (`FROM ubuntu:24.04`)
- Docker registry images (`FROM ghcr.io/technicalpickles/agentic-container:latest`)

### 1.3 Testing and Validation
```bash
# Test the configuration locally (optional)
npm install -g renovate
export GITHUB_TOKEN=your_token
renovate --dry-run your-username/agentic-container
```

## Phase 2: Custom Managers (Week 2-3)

### 2.1 Docker ARG Version Management
The custom regex managers will handle:
```dockerfile
ARG NODE_VERSION=24.8.0      # → Latest Node.js LTS
ARG PYTHON_VERSION=3.13.7    # → Latest Python stable  
ARG RUBY_VERSION=3.4.5       # → Latest Ruby stable
ARG GO_VERSION=1.25.1        # → Latest Go stable
```

**Files affected:**
- `Dockerfile`
- `docs/cookbooks/rails-fullstack/Dockerfile`
- `docs/cookbooks/go-microservices/Dockerfile`

### 2.2 Tool Version Updates
```dockerfile
ARG AST_GREP_VERSION=0.39.5   # → Latest ast-grep release
ARG LEFTHOOK_VERSION=1.13.0   # → Latest lefthook release
ARG UV_VERSION=0.8.17         # → Latest uv release
```

### 2.3 Script Embedded Versions
```bash
DIVE_VERSION="${DIVE_VERSION:-0.12.0}"  # → Latest dive release
```

**Files affected:**
- `scripts/analyze-image-size.sh`

## Phase 3: Advanced Configurations (Week 4)

### 3.1 Mise Tool Versions
```toml
[tools]
hadolint = "latest"    # → Could pin to specific version
goss = "latest"        # → Could pin to specific version
yamllint = "latest"    # → Could pin to specific version
trivy = "latest"       # → Could pin to specific version
```

**Decision needed:** Keep as "latest" or pin to specific versions for reproducibility?

### 3.2 Download URL Patterns
```dockerfile
curl https://github.com/spinel-coop/rv/releases/download/v0.1.1/rv-installer.sh
#                                                        ^^^^^
# This version will be automatically updated
```

### 3.3 GitHub Actions Tool Versions
```yaml
- name: Install Trivy
  uses: aquasecurity/setup-trivy@v0.2.3
  with:
    version: v0.66.0  # ← This will be updated
```

## Configuration Customization

### Scheduling Options
Current config schedules updates:
- Weekday mornings (before 6am)
- Weekends (any time)

**Alternative schedules:**
```json5
// Less frequent (weekly)
"schedule": ["before 6am on monday"]

// More frequent (daily)
"schedule": ["before 6am every day"]

// Business hours only
"schedule": ["after 9am and before 5pm every weekday"]
```

### Automerge Settings
Current: Conservative (manual approval required)

**More aggressive automerge:**
```json5
"packageRules": [
  {
    "matchUpdateTypes": ["patch", "pin", "digest"],
    "automerge": true
  }
]
```

### Grouping Strategies
Current: Groups related updates to reduce PR noise

**Alternative: Separate all updates:**
```json5
"groupName": null  // Each dependency gets its own PR
```

## Monitoring and Maintenance

### 1. Dependency Dashboard
- Enabled at `/issues` with title "🤖 Dependency Updates Dashboard"
- Shows pending updates, failed updates, and configuration issues

### 2. PR Management
- Maximum 3 concurrent PRs
- Maximum 2 PRs per hour
- Semantic commit messages
- Automatic labeling

### 3. Security Alerts
- Vulnerability alerts enabled
- OSV (Open Source Vulnerabilities) database integration
- Security updates get higher priority

## Testing Strategy

### 1. Validation Workflow
Each Renovate PR should trigger:
- Dockerfile linting (hadolint)
- YAML validation (yamllint)  
- Container builds and tests
- Cookbook validation with goss tests

### 2. Rollback Plan
```bash
# If a version update breaks something:
git revert <renovate-commit-hash>

# Or pin to previous version temporarily:
ARG NODE_VERSION=24.7.0  # Was 24.8.0
```

### 3. Manual Override
```bash
# Build with specific version for testing
docker build --build-arg NODE_VERSION=24.9.0 -t test .
```

## Expected Outcomes

### Before Renovate
- Manual version tracking across 50+ version specifications
- Inconsistent update cadence
- Security vulnerabilities may go unnoticed
- Time-consuming dependency research

### After Renovate  
- Automated PRs for 80%+ of version updates
- Consistent security patch application
- Grouped updates reduce notification noise
- Dependency dashboard provides overview
- Semantic versioning and changelog integration

## Troubleshooting Common Issues

### 1. Rate Limiting
If hitting GitHub API limits:
```json5
"prConcurrentLimit": 2,    // Reduce from 3
"prHourlyLimit": 1         // Reduce from 2
```

### 2. False Positives
If Renovate detects versions incorrectly:
```json5
"ignorePaths": ["**/test/**", "**/examples/**"]
```

### 3. Version Conflicts
If multiple files need coordination:
```json5
"packageRules": [
  {
    "matchPackagePatterns": ["NODE_VERSION", "node"],
    "groupName": "Node.js ecosystem"
  }
]
```

## Cost-Benefit Analysis

### Setup Cost
- Initial configuration: 4-8 hours
- Testing and validation: 2-4 hours  
- Team training: 1-2 hours

### Ongoing Maintenance
- Review PRs: 15-30 minutes/week
- Configuration adjustments: 1-2 hours/month
- Troubleshooting: 1-2 hours/quarter

### Benefits
- Reduced manual dependency tracking: **5+ hours/month saved**
- Faster security patch application: **Immediate**
- Reduced human error in version management: **Significant**
- Better dependency visibility: **Continuous**

**ROI**: Positive within first month of implementation.

## Next Steps

1. **Review the configuration** in `scratch/renovate.json5`
2. **Customize scheduling and automerge** settings based on your preferences
3. **Install the Renovate App** on your GitHub repository
4. **Copy the configuration** to `.github/renovate.json5`
5. **Monitor the onboarding PR** and dependency dashboard
6. **Fine-tune settings** based on initial results

The configuration is designed to be conservative initially - you can always make it more aggressive as you build confidence in the automation.
