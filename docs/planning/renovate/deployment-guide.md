# Renovate Phase 1 Setup Instructions

## ✅ Configuration Complete

The Renovate configuration has been successfully copied from `scratch/renovate.json5` to `.github/renovate.json5`. This configuration includes:

- **Automatic updates** for GitHub Actions, Docker base images, Node.js dependencies
- **Custom regex managers** for Docker ARG versions (NODE_VERSION, PYTHON_VERSION, etc.)
- **Tool version tracking** for ast-grep, lefthook, uv, dive, and trivy
- **Conservative automerge** settings (only patch updates for GitHub Actions and dev dependencies)
- **Dependency dashboard** for overview and management
- **Rate limiting** to avoid overwhelming the repository (max 3 concurrent PRs, 2 per hour)

## 🚀 Next Steps: Install Renovate App

### 1. Install the Mend Renovate App

1. **Go to the GitHub App installation page:**
   - Visit: https://github.com/apps/renovate
   - Click **"Install"**

2. **Choose installation scope:**
   - Select **"Only select repositories"**
   - Choose `agentic-container` repository
   - Click **"Install"**

3. **Grant permissions:**
   - Renovate will request permissions to:
     - Read repository contents
     - Create pull requests
     - Read and write issues (for dependency dashboard)
     - Read repository metadata

### 2. Verify Installation

After installation, Renovate will:

1. **Create an onboarding PR** within 1-2 hours with title like:
   ```
   Configure Renovate
   ```

2. **Show detected dependencies** in the PR description, including:
   - GitHub Actions versions
   - Docker base images
   - Node.js packages from package.json
   - Custom ARG versions from Dockerfiles

3. **Create dependency dashboard issue** with title:
   ```
   🤖 Dependency Updates Dashboard
   ```

### 3. Review and Merge Onboarding PR

1. **Check the onboarding PR** for:
   - Correct detection of dependencies
   - No unexpected changes to configuration
   - Proper branch naming (`renovate/configure`)

2. **Merge the onboarding PR** to activate Renovate

3. **Monitor the dependency dashboard** at:
   ```
   https://github.com/your-username/agentic-container/issues
   ```

## 🔧 Testing Configuration (Optional)

### Local Validation

**Quick Validation (Recommended):**
```bash
# Run the comprehensive validation script
./scripts/validate-renovate-config.sh
```

**Full Dry Run Test (Optional):**
```bash
# Renovate is installed as dev dependency
# Set GitHub token (needs repo access)
export GITHUB_TOKEN=your_personal_access_token

# Run dry-run to see what Renovate would do
npx renovate --dry-run your-username/agentic-container

# Or run with more verbose output
npx renovate --dry-run --log-level debug your-username/agentic-container
```

### Expected Output

The dry run should show:
- Detection of GitHub Actions in `.github/workflows/`
- Detection of Docker base images in Dockerfiles
- Detection of Node.js dependencies in `package.json`
- Custom ARG versions from regex managers
- Tool versions in scripts and workflows

## 📊 What Happens Next

### Immediate Benefits (Week 1)
- **GitHub Actions updates**: `actions/checkout@v3` → `actions/checkout@v4`
- **Docker base images**: `ubuntu:22.04` → `ubuntu:24.04`
- **Node.js dependencies**: Automatic patch and minor updates
- **Security alerts**: Immediate notification of vulnerabilities

### Custom Managers (Week 2-3)
- **Language runtime versions**: NODE_VERSION, PYTHON_VERSION updates
- **Tool versions**: ast-grep, lefthook, uv version updates
- **Script embedded versions**: dive version in analyze-image-size.sh

### Expected PR Volume
- **Initial week**: 5-10 PRs (catching up on outdated dependencies)
- **Ongoing**: 2-5 PRs per week (depending on update frequency)
- **Grouped updates**: Related changes combined to reduce noise

## 🛠 Troubleshooting

### If Onboarding PR Doesn't Appear
1. Check repository permissions in GitHub App settings
2. Verify `.github/renovate.json5` is in the default branch
3. Check Renovate logs in the GitHub App dashboard

### If Too Many PRs Are Created
1. Adjust rate limiting in `.github/renovate.json5`:
   ```json5
   "prConcurrentLimit": 2,  // Reduce from 3
   "prHourlyLimit": 1       // Reduce from 2
   ```

### If Configuration Errors Occur
1. Check the dependency dashboard issue for error messages
2. Validate JSON5 syntax at https://jsonlint.com/
3. Review Renovate logs in the GitHub App dashboard

## 📈 Success Metrics

After 1 week, you should see:
- ✅ Dependency dashboard issue created
- ✅ 3-8 dependency update PRs created
- ✅ At least 1 security update (if any exist)
- ✅ Proper grouping of related updates
- ✅ Semantic commit messages and PR titles

The configuration is designed to be conservative initially. You can make it more aggressive (more automerge, higher frequency) as you build confidence in the automation.
