# Branch Protection and Auto-Merge Setup Guide

This guide helps you configure GitHub branch protection rules and auto-merge
functionality to ensure all CI checks pass before allowing merges.

## Current CI Status Checks

Based on your workflows, these are the status checks that should be required:

### From `lint-and-validate.yml`:

- `Lint Dockerfiles` (hadolint job)
- `Lint YAML files` (yamllint job)
- `Security Scan` (security-scan job)

### From `build-test-publish.yml`:

- `Build Standard Image` (build-standard job)
- `Cookbook Tests Summary` (test-cookbooks-summary job)

**Note:** The `parallel-validation` job uses a matrix strategy that creates
multiple individual checks like
`Parallel Validation (test-cookbooks, Test Cookbooks, python-cli)`. Rather than
requiring each individual matrix job, we require the `Cookbook Tests Summary`
job which waits for all parallel jobs to complete and fails if any cookbook test
fails.

## Step 1: Configure Branch Protection Rules

### Via GitHub Web Interface:

1. Go to your repository settings:
   `https://github.com/YOUR_ORG/agentic-container/settings/branches`

2. Click "Add rule" or edit the existing rule for `main` branch

3. Configure these settings:

   **Basic Protection:**
   - ✅ Restrict pushes that create files larger than 100 MB
   - ✅ Require a pull request before merging
     - ✅ Require approvals: `1` (or more as needed)
     - ✅ Dismiss stale PR approvals when new commits are pushed
     - ✅ Require review from code owners (if you have CODEOWNERS)
     - ✅ Allow specified actors to bypass pull request requirements (optional)

   **Status Checks:**
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging

   **Required Status Checks** (add these exact names):

   ```
   Lint Dockerfiles
   Lint YAML files
   Security Scan
   Build Standard Image
   Cookbook Tests Summary
   ```

   **Additional Settings:**
   - ✅ Require conversation resolution before merging
   - ✅ Require signed commits (if using commit signing)
   - ✅ Include administrators (applies rules to admins too)
   - ✅ Allow force pushes: Everyone (or restrict as needed)
   - ✅ Allow deletions: Disabled

### Via GitHub CLI (Alternative Method):

```bash
# Install GitHub CLI if not already installed
# brew install gh  # macOS
# gh auth login   # Authenticate

# Create branch protection rule
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --raw-field required_status_checks='{"strict":true,"contexts":["Lint Dockerfiles","Lint YAML files","Security Scan","Build Standard Image","Cookbook Tests Summary"]}' \
  --raw-field enforce_admins='{"enabled":true}' \
  --raw-field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --raw-field restrictions='null' \
  --raw-field required_conversation_resolution='{"enabled":true}'
```

## Step 2: Enable Auto-Merge

### Repository Settings:

1. Go to `https://github.com/YOUR_ORG/agentic-container/settings`
2. Scroll to "Pull Requests" section
3. ✅ Enable "Allow auto-merge"

### Using Auto-Merge on PRs:

Once enabled, on any pull request:

1. **Via Web Interface:**
   - Click the dropdown arrow next to "Merge pull request"
   - Select "Enable auto-merge"
   - Choose merge type (merge commit, squash, rebase)
   - The PR will auto-merge once all required checks pass

2. **Via GitHub CLI:**

   ```bash
   # Enable auto-merge on a PR
   gh pr merge --auto --squash PR_NUMBER

   # Or with merge commit
   gh pr merge --auto --merge PR_NUMBER
   ```

3. **Via Comment on PR:**
   ```bash
   # Add this comment to enable auto-merge (if you have a bot configured)
   /merge
   ```

## Step 3: Verify Configuration

### Test the Protection Rules:

1. Create a test branch and PR
2. Verify you cannot merge while checks are running
3. Verify you cannot merge if any check fails
4. Verify auto-merge works when all checks pass

### Check Current Protection Status:

```bash
# View current branch protection settings
gh api repos/{owner}/{repo}/branches/main/protection | jq '.'

# List required status checks
gh api repos/{owner}/{repo}/branches/main/protection/required_status_checks | jq '.contexts'
```

## Step 4: Optional Enhancements

### 1. Auto-merge Bot (GitHub Actions)

Create `.github/workflows/auto-merge.yml`:

```yaml
name: Auto-merge approved PRs
on:
  pull_request_target:
    types: [labeled, synchronize, opened, edited, ready_for_review]
  pull_request_review:
    types: [submitted]
  check_suite:
    types: [completed]

jobs:
  auto-merge:
    runs-on: ubuntu-latest
    if: >
      github.event.pull_request.draft == false && (
        contains(github.event.pull_request.labels.*.name, 'auto-merge') ||
        github.event.pull_request.user.login == 'dependabot[bot]'
      )
    steps:
      - name: Enable auto-merge
        uses: peter-evans/enable-pull-request-automerge@v3
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          pull-request-number: ${{ github.event.pull_request.number }}
          merge-method: squash
```

### 2. Dependabot Auto-merge

Add to `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: 'npm'
    directory: '/'
    schedule:
      interval: 'weekly'
    # Auto-merge minor and patch updates
    open-pull-requests-limit: 5
    reviewers:
      - 'your-username'
    labels:
      - 'dependencies'
      - 'auto-merge' # This triggers auto-merge workflow
```

## Understanding Matrix Jobs and Status Checks

### Why We Don't Require Individual Matrix Jobs

Your `parallel-validation` job uses GitHub Actions matrix strategy, which
creates multiple individual checks:

```yaml
strategy:
  matrix:
    include:
      - job: test-cookbooks
        cookbook: python-cli
      - job: test-cookbooks
        cookbook: nodejs-backend
      # ... more cookbooks
```

This creates status checks like:

- `Parallel Validation (test-cookbooks, Test Cookbooks, python-cli)`
- `Parallel Validation (test-cookbooks, Test Cookbooks, nodejs-backend)`
- `Parallel Validation (test-cookbooks, Test Cookbooks, go-microservices)`
- etc.

### The Problem with Requiring Matrix Jobs

If we required all individual matrix jobs as status checks, we'd have several
issues:

1. **Fragile Configuration**: Adding/removing cookbooks would require updating
   branch protection rules
2. **Long Status Check Lists**: With 6+ cookbooks, we'd have 6+ individual
   checks to manage
3. **Maintenance Overhead**: Each cookbook change requires infrastructure
   updates

### The Solution: Summary Jobs

Instead, we use the **`Cookbook Tests Summary`** job which:

✅ **Waits for all matrix jobs** using `needs: parallel-validation` ✅ **Fails
if any cookbook test fails** using
`if: needs.parallel-validation.result != 'success'` ✅ **Provides a single
status check** that represents all cookbook testing ✅ **Scales automatically**
when cookbooks are added/removed

This pattern is recommended by GitHub for matrix job workflows.

## Troubleshooting

### Common Issues:

1. **Status check names don't match:**
   - Check exact job names in your workflow files
   - Use GitHub API to see actual status check names:
     ```bash
     gh api repos/{owner}/{repo}/commits/COMMIT_SHA/check-runs
     ```

2. **Checks not being required:**
   - Ensure the branch protection rule is active
   - Check that status check names match exactly
   - Verify workflows are running on pull requests

3. **Auto-merge not working:**
   - Confirm auto-merge is enabled in repository settings
   - Check that all required status checks pass
   - Ensure PR has required approvals

4. **Matrix jobs causing issues:**
   - Your parallel validation uses a matrix - make sure the summary job passes
   - Individual matrix jobs may not show as separate status checks

### Debug Commands:

```bash
# Check branch protection status
gh api repos/{owner}/{repo}/branches/main/protection

# List all status checks for a commit
gh api repos/{owner}/{repo}/commits/COMMIT_SHA/check-runs

# View PR merge requirements
gh pr view PR_NUMBER --json mergeStateStatus,mergeable,mergeabilityChecks
```

## Best Practices

1. **Start with fewer required checks** and add more as needed
2. **Test the configuration** with a draft PR first
3. **Document the process** for your team
4. **Consider using labels** like "auto-merge" for selective automation
5. **Monitor failed checks** and improve CI reliability
6. **Keep status check names stable** across workflow updates

## Next Steps

1. Apply these settings to your main branch
2. Test with a sample PR
3. Train your team on the new workflow
4. Consider additional automation based on your needs
5. Update this documentation as you refine the process
