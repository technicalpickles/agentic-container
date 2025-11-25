# Branch Protection Update Instructions

After PR #113 is merged and validated, update branch protection rules to use only the unified CI Summary check.

## Current State (Before)

**Required status checks (8 total):**
1. Build Standard Image
2. CI Summary
3. Lint Dockerfiles
4. Lint YAML files
5. Security Scan
6. Test Base Target (dev)
7. Test Base Target (standard)
8. Validate Renovate Configuration

**Problem:** These checks come from multiple workflows. When path filters prevent workflows from running, required checks don't appear, blocking PRs.

## Target State (After)

**Required status checks (1 total):**
1. CI Summary

**Why:** CI Summary now waits for and aggregates all checks from all workflows, providing a single source of truth for merge readiness.

## Update Steps

### Via GitHub Web UI

1. Navigate to: https://github.com/technicalpickles/agentic-container/settings/branches
2. Click "Edit" on the `main` branch protection rule
3. Scroll to "Require status checks to pass before merging"
4. In the search box, remove these checks:
   - Build Standard Image
   - Lint Dockerfiles
   - Lint YAML files
   - Security Scan
   - Test Base Target (dev)
   - Test Base Target (standard)
   - Validate Renovate Configuration
5. Ensure "CI Summary" is selected
6. Click "Save changes"

### Via GitHub CLI

```bash
# Get current protection rules
gh api repos/technicalpickles/agentic-container/branches/main/protection > current_protection.json

# Update required checks (remove all except CI Summary)
gh api --method PUT repos/technicalpickles/agentic-container/branches/main/protection/required_status_checks \
  -f strict=false \
  -f contexts[]='CI Summary'

# Verify the change
gh api repos/technicalpickles/agentic-container/branches/main/protection/required_status_checks
```

## Validation After Update

After changing branch protection, validate:

1. **Test with PR #110:**
   ```bash
   gh pr view 110 --json mergeable
   # Should show: "mergeable": "MERGEABLE"
   ```

2. **Check required checks:**
   ```bash
   gh api repos/technicalpickles/agentic-container/branches/main/protection/required_status_checks \
     --jq '.contexts[]'
   # Should output only: CI Summary
   ```

3. **Create test PR:**
   - Make a trivial change (like updating README)
   - Verify only "CI Summary" is required
   - Verify it passes and PR is mergeable

## Rollback Procedure

If issues arise after updating branch protection:

### Quick Rollback (Restore All Checks)

```bash
gh api --method PUT repos/technicalpickles/agentic-container/branches/main/protection/required_status_checks \
  -f strict=false \
  -f contexts[]='Build Standard Image' \
  -f contexts[]='CI Summary' \
  -f contexts[]='Lint Dockerfiles' \
  -f contexts[]='Lint YAML files' \
  -f contexts[]='Security Scan' \
  -f contexts[]='Test Base Target (dev)' \
  -f contexts[]='Test Base Target (standard)' \
  -f contexts[]='Validate Renovate Configuration'
```

### Restore from Backup

```bash
# If you saved current_protection.json above:
gh api --method PUT repos/technicalpickles/agentic-container/branches/main/protection \
  --input current_protection.json
```

## Timeline

1. ✅ PR #113 created - unified CI Summary implementation
2. ⏳ Wait for PR #113 to pass all checks
3. ⏳ Merge PR #113
4. ⏳ Monitor for 24-48 hours (5-10 PRs)
5. ⏳ **Then** update branch protection rules
6. ⏳ Verify PR #110 becomes mergeable

**Do not rush step 5** - ensure CI Summary is working reliably first.

## Expected Impact

**Positive:**
- ✅ Simpler branch protection configuration
- ✅ PRs no longer blocked by non-applicable checks
- ✅ Single check to monitor in PR status
- ✅ Faster PR feedback (no false blocks)

**Considerations:**
- CI Summary must be reliable (single point of failure)
- Wait times may be slightly longer (waits for all checks)
- Need good monitoring/alerting on CI Summary failures

## Monitoring

After update, monitor:

```bash
# Check CI Summary success rate
gh api repos/technicalpickles/agentic-container/actions/workflows/build-test-publish.yml/runs \
  --jq '.workflow_runs[] | select(.name == "Build, Test, and Publish") | {conclusion, jobs_url}'

# Look for patterns of failures
gh run list --workflow="Build, Test, and Publish" --limit 50 --json conclusion,databaseId
```

## Questions / Issues

If you encounter issues after updating:

1. Check CI Summary logs for wait timeouts
2. Verify all workflows are triggering correctly
3. Check for rate limiting issues with wait-on-check-action
4. Consider reverting to old branch protection temporarily
5. Review `.github/TESTING_CI_SUMMARY.md` for debugging tips

## Success Criteria

Branch protection update is successful when:

- ✅ Only "CI Summary" is required
- ✅ PR #110 can merge
- ✅ Test PRs with various change types all behave correctly
- ✅ No false negatives (bad PRs merging)
- ✅ No false positives (good PRs blocked)
- ✅ Team feedback is positive
