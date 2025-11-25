# Renovate Auto-Merge Strategy

**Date:** 2025-11-25 **Status:** Implemented

## Problem

Renovate creates many individual PRs that pass CI but require manual merging.
Recent examples:

- PR #95 (ast_grep 0.39.9 → 0.40.0, minor update) - manually merged
- PR #80 (codex 0.50.0 → 0.63.0, minor update) - manually merged
- PRs #102-106: Five claude_code updates over 4 days, each requiring attention

Current configuration only auto-merges patch updates. Minor updates require
manual intervention despite comprehensive CI coverage (goss tests,
multi-platform builds, cookbook validation, security scans).

## Solution

Trust CI completely and eliminate manual merging through aggressive auto-merge
policy with daily batching.

### Configuration Changes

**1. Daily scheduling** (`.github/renovate.json5:5`)

```json5
schedule: ["before 6am"],
```

Runs Renovate once daily at 6am (America/New_York timezone), batching updates
detected in the same run. This enables the existing "Development dependencies"
group to work properly.

**2. Auto-merge patch and minor updates** (`.github/renovate.json5:54-58`)

```json5
{
  description: 'Auto-merge patch and minor updates',
  matchUpdateTypes: ['patch', 'minor'],
  automerge: true,
  automergeType: 'pr',
}
```

Previously only merged `["patch"]`. Now includes minor version bumps (e.g.,
0.39.x → 0.40.0).

**3. Clarify merge strategy** (`.github/renovate.json5:260-263`)

```json5
// Global automerge disabled - packageRules override this for specific update types
automerge: false,
automergeType: "pr",
automergeStrategy: "squash",
```

Added comment explaining that packageRules override global setting. Changed
strategy from "merge" to "squash" to match observed behavior.

## Expected Behavior

**Before:**

- Continuous PR creation as updates detected
- Individual PRs per dependency (claude_code, uv, lefthook separate)
- Only patch updates auto-merge
- Manual merge required for minor updates

**After:**

- Daily batch at 6am collects all available updates
- Dependencies group according to existing rules (Development dependencies)
- Both patch and minor updates auto-merge after CI passes (~2 minutes)
- Major updates still require manual review

**Example transformation:**

- Before: 5 separate claude_code PRs over 4 days (v2.0.49, 50, 51, 52, 53)
- After: 1 PR daily with multiple updates grouped (claude_code + uv + lefthook)

## Safety

All merges require CI to pass:

- Build standard image (multi-platform)
- Test standard and dev targets with goss
- Test all 6 cookbooks (python-cli, nodejs-backend, rails-fullstack, etc.)
- Security scans (Trivy)
- Lint validation (hadolint, yamllint)

Major version updates (e.g., 1.x → 2.x) continue to require manual review.

## Monitoring

After deployment, monitor:

- Grouped PR behavior (are updates batching as expected?)
- Auto-merge success rate (CI pass → merge within 2 minutes)
- False positive rate (bad updates that passed CI)

If issues arise, can add stability periods or adjust grouping strategy.
