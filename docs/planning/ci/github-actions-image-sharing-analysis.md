# GitHub Actions: Sharing Docker Images Between Jobs

## Current State Analysis

Looking at your existing `.github/workflows/build-and-publish.yml`, you're
already using:

- **Docker Layer Caching**: `cache-from: type=gha` and
  `cache-to: type=gha,mode=max`
- **Job Dependencies**: `update-docs` job has `needs: build`
- **Multi-platform builds**: `linux/amd64,linux/arm64`
- **Workflow chaining**: `size-analysis.yml` triggers after main build completes

## Options for Image Sharing

### 1. Registry Approach (Push/Pull) ⭐ RECOMMENDED

**How it works**: Build job pushes to registry, test jobs pull from registry

**Pros**:

- Clean separation of concerns
- Works reliably across different runners
- Leverages existing registry infrastructure
- Supports multi-platform seamlessly
- Can reuse images across workflow runs

**Cons**:

- Requires registry push/pull (bandwidth + time)
- Need registry credentials in test jobs
- Slightly more complex setup

**Example Implementation**:

```yaml
jobs:
  build-base-image:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push base image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          target: standard
          push: true
          tags: ghcr.io/${{ github.repository }}:test-${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  test-examples:
    needs: build-base-image
    runs-on: ubuntu-latest
    strategy:
      matrix:
        example: [python-cli, nodejs-backend, go-microservices]
    steps:
      - uses: actions/checkout@v4
      - name: Test example against built image
        run: |
          cd docs/examples/${{ matrix.example }}
          # Use the built image as base
          sed -i 's|ghcr.io/technicalpickles/agentic-container:latest|ghcr.io/${{ github.repository }}:test-${{ github.sha }}|g' Dockerfile
          docker build -t test-${{ matrix.example }} .
          # Run goss tests...
```

### 2. Docker Layer Cache + Build in Each Job

**How it works**: Each job builds the image but shares layers via GitHub Actions
cache

**Pros**:

- No registry dependency for sharing
- Leverages existing cache setup
- Each job is independent
- Fast rebuilds due to layer caching

**Cons**:

- Duplicate build steps
- Cache misses can be expensive
- More CI time if cache is cold

**Example**:

```yaml
jobs:
  test-examples:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        example: [python-cli, nodejs-backend]
    steps:
      - uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build base image (cached)
        uses: docker/build-push-action@v5
        with:
          context: .
          target: standard
          load: true
          tags: agentic-container:test
          cache-from: type=gha
          # Don't push, just build locally

      - name: Test example
        run: |
          cd docs/examples/${{ matrix.example }}
          sed -i 's|ghcr.io/technicalpickles/agentic-container:latest|agentic-container:test|g' Dockerfile
          docker build -t test-${{ matrix.example }} .
```

### 3. Docker Artifacts (Save/Load)

**How it works**: Build job saves image as tar, uploads as artifact, test jobs
download and load

**Pros**:

- No registry required
- Complete image sharing
- Works offline/in private environments

**Cons**:

- Large artifacts (images can be GB+)
- Slow upload/download times
- GitHub Actions artifact limits
- No layer sharing between jobs

**Example**:

```yaml
jobs:
  build-base-image:
    runs-on: ubuntu-latest
    steps:
      - name: Build and save image
        run: |
          docker build -t agentic-container:test .
          docker save agentic-container:test > base-image.tar

      - name: Upload image artifact
        uses: actions/upload-artifact@v4
        with:
          name: base-image
          path: base-image.tar

  test-examples:
    needs: build-base-image
    runs-on: ubuntu-latest
    steps:
      - name: Download base image
        uses: actions/download-artifact@v4
        with:
          name: base-image

      - name: Load base image
        run: docker load < base-image.tar
```

### 4. Build Matrix with Dependencies

**How it works**: Use job outputs and matrix dependencies

**Pros**:

- GitHub Actions native approach
- Clean job organization
- Good for complex dependencies

**Cons**:

- More complex workflow structure
- Still need to solve actual image sharing

## Performance Comparison

| Approach               | Build Time | Transfer Time | Complexity | Reliability |
| ---------------------- | ---------- | ------------- | ---------- | ----------- |
| **Registry Push/Pull** | 1x         | ~30s-2min     | Medium     | High        |
| **Cache + Rebuild**    | 1x per job | ~10-30s       | Low        | High        |
| **Docker Artifacts**   | 1x         | ~2-5min       | Medium     | Medium      |
| **Build Matrix**       | 1x         | Varies        | High       | Medium      |

## Recommended Approach for Your Use Case

### For Testing Examples: Registry Approach

**Why this works best for you**:

1. **Already using GHCR**: Your workflow already pushes to `ghcr.io`
2. **Multi-platform support**: You're building ARM64 + AMD64
3. **Existing caching**: You already have optimal Docker layer caching
4. **Clean separation**: Test jobs can be completely independent

**Implementation Strategy**:

```yaml
name: Build and Test Container Images

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # Build the base image for testing
  build-test-image:
    runs-on: ubuntu-latest
    outputs:
      test-tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata for test image
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=raw,value=test-${{ github.sha }}

      - name: Build and push test image
        uses: docker/build-push-action@v5
        with:
          context: .
          target: standard
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          # Only build AMD64 for testing (faster)
          platforms: linux/amd64

  # Lint all Dockerfiles
  lint-dockerfiles:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint main Dockerfile
        uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: Dockerfile
      - name: Lint example Dockerfiles
        run: find docs/examples -name "Dockerfile" -exec hadolint {} \;

  # Test all examples
  test-examples:
    needs: [build-test-image, lint-dockerfiles]
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        example:
          - python-cli
          - nodejs-backend
          - go-microservices
          - rails-fullstack
          - react-frontend
          - multistage-production

    steps:
      - uses: actions/checkout@v4

      - name: Install goss and dgoss
        run: |
          curl -fsSL https://goss.rocks/install | sh
          sudo cp goss /usr/local/bin/
          curl -fsSL https://raw.githubusercontent.com/aelsabbahy/goss/master/extras/dgoss/dgoss -o dgoss
          chmod +x dgoss && sudo mv dgoss /usr/local/bin/

      - name: Test ${{ matrix.example }} example
        run: |
          cd docs/examples/${{ matrix.example }}

          # Update Dockerfile to use test image
          sed -i 's|ghcr.io/technicalpickles/agentic-container:latest|${{ needs.build-test-image.outputs.test-tag }}|g' Dockerfile

          # Run goss tests if available, otherwise basic test
          if [ -f goss.yaml ]; then
            echo "Running goss tests for ${{ matrix.example }}"
            dgoss run test-${{ matrix.example }}
          else
            echo "Running basic test for ${{ matrix.example }}"
            ../test-extensions.sh Dockerfile --cleanup
          fi

      - name: Cleanup test images
        if: always()
        run: |
          docker image prune -f
          docker rmi test-${{ matrix.example }} 2>/dev/null || true

  # Clean up test image after all tests complete
  cleanup-test-image:
    needs: [build-test-image, test-examples]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Delete test image from registry
        run: |
          # Note: This requires a GitHub token with packages:delete scope
          # For now, we can rely on retention policies or manual cleanup
          echo "Test image: ${{ needs.build-test-image.outputs.test-tag }}"
          echo "Would delete test image here (implement with API call)"

  # Your existing production build (unchanged)
  build-production:
    needs: test-examples # Only build production after tests pass
    runs-on: ubuntu-latest
    strategy:
      matrix:
        target: [standard, dev]
    # ... rest of your existing build job
```

## Benefits of This Approach

### Performance

- **Fast parallel execution**: All example tests run simultaneously
- **Shared base image**: Build once, test many times
- **Layer caching**: Leverages existing GHA cache optimizations

### Reliability

- **Isolated tests**: Each example test is independent
- **Consistent environment**: All tests use exact same base image
- **Fail-fast**: Issues caught before production build

### Maintainability

- **Clean separation**: Test workflow separate from production build
- **Easy to extend**: Adding new examples just extends the matrix
- **Clear dependencies**: Test → Production build flow

## Alternative: Simpler Cache-Based Approach

If you prefer to avoid extra registry pushes:

```yaml
jobs:
  test-examples:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        example: [python-cli, nodejs-backend]
    steps:
      - uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # Each job builds base image (but cached layers make it fast)
      - name: Build base image locally
        uses: docker/build-push-action@v5
        with:
          context: .
          target: standard
          load: true # Load into local Docker daemon
          tags: agentic-container:test
          cache-from: type=gha
          platforms: linux/amd64 # Single platform for testing

      - name: Test example
        run: |
          cd docs/examples/${{ matrix.example }}
          sed -i 's|ghcr.io/technicalpickles/agentic-container:latest|agentic-container:test|g' Dockerfile
          # Run tests...
```

**Trade-offs**:

- ✅ No extra registry pushes
- ✅ Simpler setup
- ❌ Builds base image N times (but cached)
- ❌ More total CI time if cache misses

## Recommendation

**Start with the Registry Approach** because:

1. **You're already using GHCR** - minimal new infrastructure
2. **Guaranteed consistency** - exact same image tested everywhere
3. **Better scalability** - easy to add cross-platform testing later
4. **Cleaner separation** - test and production builds independent

The 30-60 seconds for registry push/pull is worth the reliability and
consistency benefits.

---

_Ready to implement whichever approach you prefer!_
