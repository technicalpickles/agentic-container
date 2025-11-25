# Optimized CI Strategy for Agentic Container

## Executive Summary

This document outlines a comprehensive strategy to optimize Docker caching and
build performance in the agentic-container CI pipeline. The proposed unified
workflow eliminates redundant builds, maximizes layer caching, and ensures
cookbook extensions are tested before publishing.

## Current State Analysis

### Current Workflows

- `build-and-publish.yml`: Builds and publishes base images
- `test-cookbooks.yml`: Tests cookbook extensions with independent base image
  builds

### Identified Issues

1. **Redundant Builds**: 8 total builds (2 base + 6 cookbook matrix builds)
2. **No Test Gating**: Images can publish even if cookbook tests fail
3. **Inefficient Caching**: Each cookbook test rebuilds the same base image
4. **Missing Layer Sharing**: Dev variant doesn't optimally reuse standard
   layers
5. **Branch Confusion**: Workflows reference unused `develop` branch

### Performance Impact

- **Current CI Usage**: ~40-60 runner minutes per push
- **Build Times**: 25-30 min cold, 15-20 min warm
- **Cache Efficiency**: Suboptimal due to parallel redundant builds

## Proposed Optimized Architecture

### Core Strategy: Hybrid Workflow Approach

```
┌─ lint-and-validate.yml (fast feedback, 2-3 min)
│  └─ Hadolint + YAML validation + Security scan
│
├─ build-test-publish.yml (core pipeline, 15-20 min)
│  └─ Build Standard → (Build Dev + Test Cookbooks) → Publish (main only)
│                  ↓        ↓              ↓
│           Cache layers  Reuse layers  Use standard image
│                           ↖_____parallel_____↗
│
└─ docs-and-maintenance.yml (maintenance, 3-5 min)
   └─ Update docs + Dependency updates + Cleanup
```

**Workflow Separation Rationale:**

- **Fast feedback**: Lint failures show immediately in separate status check
- **Clean concerns**: Different permissions, triggers, and failure modes
- **Independent scaling**: Optimize each workflow separately
- **Better visibility**: Clear status checks for different types of issues

### Workflow Design

#### Workflow 1: `lint-and-validate.yml` (2-3 min)

**Purpose**: Fast failure for obvious issues, independent quality checks
**Triggers**: `push`, `pull_request`

```yaml
jobs:
  hadolint:
    - Lint all Dockerfiles (main, cookbooks, templates)
    - Report issues as annotations

  validate-configs:
    - YAML validation on goss test files
    - Validate workflow syntax
    - Check for missing required files

  security-scan:
    - Dockerfile security analysis
    - Dependency vulnerability scan (when applicable)
```

#### Workflow 2: `build-test-publish.yml` (15-20 min)

**Purpose**: Core build, test, and publish pipeline **Triggers**: `push` (main),
`pull_request`

```yaml
jobs:
  build-standard: (8-12 min)
    - Multi-arch build (linux/amd64, linux/arm64)
    - Enhanced GitHub Actions caching with scope isolation
    - Export image metadata for downstream jobs

  parallel-validation: (5-8 min)
    build-dev:
      - Depends on: build-standard
      - Reuses ~80% of layers from standard build
      - Only builds dev-specific additions

    test-cookbooks:
      - Depends on: build-standard
      - Matrix strategy: 6 cookbooks in parallel
      - Uses pre-built standard image (no rebuild!)
      - Leverages goss self-installation approach

  publish: (2-3 min)
    - Depends on: parallel-validation (both jobs)
    - Only runs on main branch push
    - Publishes both standard and dev variants
    - Uses cached builds (no rebuild)
```

#### Workflow 3: `docs-and-maintenance.yml` (3-5 min)

**Purpose**: Documentation updates and maintenance tasks **Triggers**: `push`
(main), `schedule` (weekly)

```yaml
jobs:
  update-docs:
    - Update README with latest tags and sizes
    - Generate cookbook documentation
    - Commit changes with [skip ci]

  maintenance:
    - Weekly dependency updates check
    - Clean up old cache entries
    - Image size monitoring and reporting
```

## Key Optimizations

### 1. Workflow Separation Benefits

- **Fast feedback**: Lint issues appear immediately (2-3 min vs waiting for full
  build)
- **Independent failure modes**: Build failures don't block security scans
- **Cleaner status checks**: Different concerns show as separate GitHub checks
- **Optimized permissions**: Each workflow has minimal required permissions

### 2. Eliminate Redundant Builds

- **Before**: 8 builds total (2 base + 6 cookbook matrix builds)
- **After**: 2 builds total in core pipeline (reused across cookbook tests)
- **Savings**: 75% reduction in build operations

### 3. Parallel Execution Optimization

- **Before**: Sequential dev build → cookbook tests (8-13 min total)
- **After**: Parallel dev build + cookbook tests (5-8 min total)
- **Savings**: 3-5 minutes by running tests while dev builds

### 4. Enhanced Caching Strategy

```yaml
# Standard build caching
cache-from: |
  type=gha,scope=standard-${{ github.ref_name }}
  type=gha,scope=standard-main
cache-to: type=gha,mode=max,scope=standard-${{ github.ref_name }}

# Dev build caching
cache-from: |
  type=gha,scope=dev-${{ github.ref_name }}
  type=gha,scope=dev-main
  type=gha,scope=standard-${{ github.ref_name }}
cache-to: type=gha,mode=max,scope=dev-${{ github.ref_name }}
```

### 4. Build Sequencing for Maximum Reuse

1. **Standard First**: Establishes base layer cache
2. **Parallel Phase**: Dev build + cookbook tests run simultaneously
   - **Dev Extends Standard**: Reuses cached layers, only builds delta
   - **Tests Use Standard**: Zero additional build cost
3. **Critical Time Saving**: 5-8 min saved by running dev build and tests in
   parallel

### 5. Fail-Fast Strategy

- **Lint fails** → Stop immediately (saves ~20 min)
- **Standard build fails** → Stop (saves ~15 min)
- **Any cookbook test fails** → Block publishing (critical safety)

## Performance Projections

### Build Times

| Scenario    | Current   | Optimized | Improvement |
| ----------- | --------- | --------- | ----------- |
| Cold build  | 25-30 min | 18-22 min | 25-30%      |
| Warm build  | 15-20 min | 10-13 min | 30-40%      |
| Incremental | 10-15 min | 6-9 min   | 40-50%      |

### CI Resource Usage

| Metric              | Current   | Optimized          | Savings            |
| ------------------- | --------- | ------------------ | ------------------ |
| Runner minutes/push | 40-60 min | 25-35 min          | 35-40%             |
| Parallel builds     | 8 builds  | 2 builds + 6 tests | Efficiency gain    |
| Cache utilization   | Poor      | High               | Better performance |

## Risk Assessment

### Risks & Mitigations

**Risk**: Single point of failure if standard build fails

- **Mitigation**: Fast lint step catches most issues early
- **Impact**: Acceptable - better than inconsistent state

**Risk**: Longer feedback time for some test failures

- **Mitigation**: Parallel test execution minimizes delay
- **Impact**: Minor - consistent with build-then-test pattern

**Risk**: Increased workflow complexity

- **Mitigation**: Clear job dependencies and documentation
- **Impact**: Low - benefits outweigh complexity

### Benefits

1. **Guaranteed Consistency**: Tests always run against published images
2. **Cost Efficiency**: 35-40% reduction in CI costs
3. **Faster Incremental Builds**: Superior cache utilization
4. **Safety**: Impossible to publish untested images

## Branch Strategy Cleanup

### Current State

- Builds on: `main`, `develop`, PRs
- Publishes on: `main`, `develop`
- Tests on: cookbook-related paths

### Proposed State

- **PRs**: Build + test, never publish
- **Main**: Build + test + publish
- **Remove**: All `develop` references (unused)

### Trigger Optimization

```yaml
on:
  push:
    branches: [main]
    paths-ignore: ['docs/**', 'README.md', '*.md']
  pull_request:
    branches: [main]
    paths-ignore: ['docs/**', 'README.md', '*.md']
```

## Implementation Plan

### Phase 1: Workflow Refactoring (Week 1)

**Tasks**:

- [ ] **Rename existing workflows:**
  - `build-and-publish.yml` → `build-test-publish.yml` (enhanced core pipeline)
  - Extract lint jobs from existing workflows → `lint-and-validate.yml`
  - Extract docs jobs → `docs-and-maintenance.yml`
- [ ] **Enhance build-test-publish.yml:**
  - Integrate cookbook testing from `test-cookbooks.yml`
  - Add parallel-validation job structure
  - Implement enhanced caching strategy with scope isolation
- [ ] **Create lint-and-validate.yml:**
  - Move Hadolint jobs from build workflow
  - Add YAML validation for goss files
  - Add basic security scanning
- [ ] Test refactored workflows on feature branch

**Success Criteria**:

- All three workflows run successfully
- No functional regressions from current workflows
- Lint feedback appears within 2-3 minutes

### Phase 2: Parallel Validation & Optimization (Week 2)

**Tasks**:

- [ ] Run new workflows alongside existing ones
- [ ] Compare performance metrics across workflows
- [ ] Tune caching parameters and scope isolation
- [ ] Validate cookbook testing integration
- [ ] Test parallel execution of dev build + cookbook tests

**Success Criteria**:

- 30-40% improvement in total CI time
- Successful parallel execution of validation jobs
- All cookbook tests pass consistently
- Cache hit rates improve significantly

### Phase 3: Migration & Cleanup (Week 3)

**Tasks**:

- [ ] **Cleanup existing workflows:**
  - Remove original `test-cookbooks.yml` (functionality moved to core pipeline)
  - Clean up any remaining references to unused workflows
- [ ] Update documentation to reflect new workflow structure
- [ ] Remove all `develop` branch references
- [ ] Add workflow status badges for each concern area

**Success Criteria**:

- Three optimized workflows active (lint, build-test-publish, docs-maintenance)
- Clean workflow directory with no redundant files
- Documentation reflects new structure
- Team understands new workflow separation

## Monitoring & Success Metrics

### Key Performance Indicators

1. **Build Time Reduction**: Target 40-50% for incremental changes
2. **CI Cost Savings**: Target 35-40% reduction in runner minutes
3. **Reliability**: Zero untested images published to registry
4. **Developer Experience**: Faster feedback on common issues

### Monitoring Plan

- Track build times via GitHub Actions metrics
- Monitor cache hit rates and effectiveness
- Measure CI cost impact via GitHub billing
- Collect developer feedback on experience

## Technical Implementation Details

### Docker Buildx Configuration

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
  with:
    buildkitd-flags: --allow-insecure-entitlement security.insecure
```

### Cache Strategy Details

- **Scope-based caching**: Separate caches for branches and targets
- **Fallback hierarchy**: Branch → main → clean build
- **Mode optimization**: `mode=max` for comprehensive layer caching
- **Cache retention**: Leverage GitHub's automatic cleanup

### Matrix Testing Optimization

```yaml
strategy:
  fail-fast: false
  matrix:
    cookbook:
      [
        python-cli,
        nodejs-backend,
        go-microservices,
        rails-fullstack,
        react-frontend,
        multistage-production,
      ]
```

### Image Sharing Strategy

- Use `load: true` for local testing
- Export image tarballs as artifacts if needed
- Leverage Docker layer sharing between jobs

## Questions for Implementation

### Workflow Architecture Decisions

1. **Status check requirements**: Should lint-and-validate be required for merge
   protection?
2. **Cross-workflow dependencies**: Should docs-maintenance wait for successful
   builds?
3. **Failure isolation**: How should failures in one workflow affect others?
4. **Rollback strategy**: Keep old workflows during transition period?

### Technical Decisions

1. **Cache retention policy**: How long should build caches persist across
   workflows?
2. **Image sharing**: Use artifacts or registry to share images between
   workflows?
3. **Security scanning**: Block on vulnerabilities or just report?
4. **Cookbook test failures**: Block publishing or just report failure?

### Performance Tuning

1. **Workflow triggers**: Optimize path-based triggering to reduce unnecessary
   runs?
2. **Runner sizing**: Would larger runners improve performance for builds?
3. **Cache scope**: Further optimize cache key strategies across workflows?
4. **Matrix optimization**: Can cookbook testing be further parallelized?

## Conclusion

This optimized CI strategy addresses the core inefficiencies in the current
workflow while ensuring robust testing and safe publishing practices. The
**hybrid workflow approach** provides the best of both worlds: fast feedback
through workflow separation and efficient resource usage through the optimized
core pipeline.

**Key Benefits:**

- **75% reduction in build redundancy** through shared image builds in core
  pipeline
- **Fast feedback** with 2-3 minute lint validation separate from builds
- **Clean separation of concerns** with appropriate permissions and triggers per
  workflow
- **Improved cache utilization** with enhanced scope isolation strategies
- **Guaranteed consistency** between tested and published images

The projected **35-40% reduction in CI costs**, combined with **40-50% faster
incremental builds** and **immediate lint feedback**, will significantly improve
developer productivity while maintaining the high testing standards established
in the current cookbook validation system.

**Next Step**: Implement Phase 1 by refactoring existing workflows using the
hybrid approach, starting with renaming `build-and-publish.yml` to
`build-test-publish.yml` and extracting lint functionality to a separate
workflow.
