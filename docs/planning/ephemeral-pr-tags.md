## Ephemeral PR Image Tags Strategy

Created: 2025-09-23

### Purpose
Use short‑lived, per‑PR Docker image tags in GHCR so downstream CI jobs can pull the exact image built in the PR without shipping large tar artifacts. This speeds up PR validation, simplifies sharing across jobs, and keeps multi‑arch publishing logic unchanged for `main`.

### Goals
- **Build once per PR** and **reuse via registry pull** across jobs.
- **Avoid large artifacts** (tar uploads/downloads) for same‑repo PRs.
- **Keep fork safety**: don’t expose registry credentials to forked PRs.
- **Remain deterministic** by pinning downstream tests to the PR image tag.

### Tag format
- `ghcr.io/${{ github.repository }}:pr-${{ github.event.number }}-${{ github.sha }}`
- Scope: single‑arch (`linux/amd64`) on PRs to enable quick build and pull.
- Lifetime: deleted when PR closes/merges; otherwise auto‑GC via cleanup job.

---

## Implementation Plan

### 1) Update base build job to push ephemeral PR tags (same‑repo PRs only)
- Add a conditional login and push. Keep `load: false` on PRs that push.
- Continue multi‑arch push on `main` as is.

```yaml
# In .github/workflows/build-test-publish.yml → build-standard job
permissions:
  contents: read
  packages: write

- name: Log in to GHCR (same-repo PRs only)
  if: github.event_name == 'pull_request' && github.event.pull_request.head.repo.fork == false
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}

- name: Build PR image (push ephemeral tag)
  if: github.event_name == 'pull_request' && github.event.pull_request.head.repo.fork == false
  uses: docker/build-push-action@v6
  with:
    context: .
    target: standard
    platforms: linux/amd64
    push: true
    load: false
    tags: ghcr.io/${{ github.repository }}:pr-${{ github.event.number }}-${{ github.sha }}
    cache-from: |
      type=gha,scope=standard-${{ github.ref_name }}
      type=gha,scope=standard-main
    cache-to: type=gha,mode=max,scope=standard-${{ github.ref_name }}

# Keep existing main-branch multi-arch build/push logic unchanged
```

Notes:
- This replaces the tar artifact for same‑repo PRs. For forks, see Step 3.

### 2) Make cookbook `Dockerfile`s base-image overridable
- Add an `ARG` so test builds can point to the PR image.

```dockerfile
# Example change in docs/cookbooks/*/Dockerfile
ARG BASE_IMAGE=ghcr.io/technicalpickles/agentic-container:main
FROM ${BASE_IMAGE}
```

Downstream build usage:

```yaml
- name: Build cookbook extension image (same-repo PR)
  if: github.event_name == 'pull_request' && github.event.pull_request.head.repo.fork == false
  run: |
    docker pull ghcr.io/${{ github.repository }}:pr-${{ github.event.number }}-${{ github.sha }}
    docker build \
      -f docs/cookbooks/${{ matrix.cookbook }}/Dockerfile \
      --build-arg BASE_IMAGE=ghcr.io/${{ github.repository }}:pr-${{ github.event.number }}-${{ github.sha }} \
      -t test-extension-${{ matrix.cookbook }}:latest .
```

### 3) Fork PR fallback: rebuild with caches (no registry write)
- For forks, skip login/push. Each dependent job rebuilds quickly using `type=gha` caches. This avoids large artifacts and keeps secrets safe.

```yaml
- name: Build cookbook extension image (fork PR fallback)
  if: github.event_name == 'pull_request' && github.event.pull_request.head.repo.fork == true
  env:
    DOCKER_BUILDKIT: "1"
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    docker build \
      --target standard \
      -t pr-base-local:latest \
      --secret id=github_token,env=GITHUB_TOKEN \
      --build-arg BUILDKIT_INLINE_CACHE=1 \
      --cache-from type=gha,scope=standard-${{ github.ref_name }} \
      --cache-from type=gha,scope=standard-main \
      --cache-to type=gha,mode=max,scope=standard-${{ github.ref_name }} \
      .
    docker build \
      -f docs/cookbooks/${{ matrix.cookbook }}/Dockerfile \
      --build-arg BASE_IMAGE=pr-base-local:latest \
      -t test-extension-${{ matrix.cookbook }}:latest .
```

Optional: keep the current tar path as a secondary fallback if cache hit rates are poor, but prefer cache‑based rebuilds to avoid large artifacts.

### 4) Base target tests consume PR image directly
- Replace artifact usage with a direct pull/retag on same‑repo PRs.

```yaml
- name: Pull PR image for base tests (same-repo PR)
  if: github.event_name == 'pull_request' && github.event.pull_request.head.repo.fork == false && matrix.target == 'standard'
  run: |
    docker pull ghcr.io/${{ github.repository }}:pr-${{ github.event.number }}-${{ github.sha }}
    docker tag ghcr.io/${{ github.repository }}:pr-${{ github.event.number }}-${{ github.sha }} test-standard:latest
```

### 5) Cleanup strategy for ephemeral tags
- Create a small workflow that runs on `pull_request` `types: [closed]` to delete the PR tag.
- Alternatively, run a nightly cleanup that scans open PRs and deletes any `pr-<num>-*` tags whose PR is closed.

```yaml
name: Cleanup PR Images
on:
  pull_request:
    types: [closed]
permissions:
  contents: read
  packages: write
jobs:
  delete-pr-image:
    runs-on: ubuntu-latest
    steps:
      - name: Delete PR image tag(s)
        uses: dataaxiom/ghcr-cleanup-action@v1
        with:
          delete-tags: pr-${{ github.event.pull_request.number }}
```

Note: The action needs `packages: write`. For wildcard/regex or cross‑repo cleanup, use a PAT with `write:packages` and `delete:packages` scopes as documented.

---

## Security & Permissions
- Only push ephemeral images when `fork == false` to avoid exposing credentials.
- Use repository‑scoped `GITHUB_TOKEN` with `packages: write` in relevant jobs.
- Keep using secret mounts (`--secret id=github_token`) during builds to protect against rate limits.

## Performance Considerations
- Single‑arch images for PRs minimize push/pull time; multi‑arch remains on `main`.
- `type=gha` caches accelerate both initial PR build and fork fallbacks.
- Removing tar artifacts reduces cross‑job transfer and speeds up matrix runs.

## Rollout Steps
1) Update cookbook `Dockerfile`s to accept `ARG BASE_IMAGE` and use it in `FROM`.
2) Add conditional GHCR login + PR push in base build job.
3) Switch base and cookbook tests to pull/tag PR image (same‑repo PRs).
4) Add fork fallback: cached rebuild in dependent jobs; disable registry usage.
5) Add cleanup workflow for PR tag deletion on close.
6) Monitor CI duration; optionally add nightly cleanup and/or registry cache (`type=registry`) if needed.

## Risks & Mitigations
- **Fork PRs slower**: Cached rebuilds mitigate, or retain artifact as last‑resort.
- **Tag bloat**: Cleanup on PR close; nightly GC.
- **Race conditions** (rebases): Use `pr-<num>-<sha>` so tags are immutable per commit.

---

## Appendix: Snippet Recap

- Ephemeral tag: `ghcr.io/${{ github.repository }}:pr-${{ github.event.number }}-${{ github.sha }}`
- Push on same‑repo PRs; pull in downstream jobs.
- Override base image in cookbooks with `ARG BASE_IMAGE`.
- Forks: rebuild + caches, no registry writes, no secrets to untrusted contexts.


