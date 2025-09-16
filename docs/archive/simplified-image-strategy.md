# Simplified Image Strategy

**Created**: 2025-01-15  
**Status**: Planning  
**Scope**: Simplification of agentic-container image strategy and maintenance approach

## Overview

This document outlines the simplified approach for agentic-container, moving away from maintaining multiple language-specific variants to a single maintained base image with clear extension patterns.

## Strategic Shift

### From: Complex Multi-Variant Approach
- Multiple maintained images: minimal, standard, ruby, node, python, go, dev
- 7 different build targets in CI/CD
- Complex tagging strategy with size-based and language-specific variants
- High maintenance burden for language version updates

### To: Simple Base + Extension Pattern
- **One maintained image**: `standard` target (tagged as `latest`)
- **One example image**: `dev` target (kitchen sink, not actively maintained)
- **Clear extension documentation**: How to add languages via mise
- **Minimal maintenance burden**: Focus on one solid foundation

## New Structure

### Built and Maintained Images

| Image | Tag | Size | Contents | Maintenance Level |
|-------|-----|------|----------|-------------------|
| `standard` | `latest`, `v1.2.3` | ~750MB | Ubuntu + mise + starship + dev tools | **Actively maintained** |
| `dev` | `dev` | ~2.2GB | Standard + all languages | **Example only** - not updated |

### Removed Images
- ~~`minimal`~~ - Users can extend `latest` if they need smaller base
- ~~`ruby`~~ - Users extend `latest` + `RUN mise install ruby@3.4.5`
- ~~`node`~~ - Users extend `latest` + `RUN mise install node@24.8.0`  
- ~~`python`~~ - Users extend `latest` + `RUN mise install python@3.13.7`
- ~~`go`~~ - Users extend `latest` + `RUN mise install go@1.25.1`

## User Experience

### Primary Use Case: Extension Pattern
```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Add languages and configure in a single RUN to minimize layers
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0 && \
    bash -c 'eval "$(mise activate bash)" && \
        pip install fastapi requests && \
        npm install -g typescript'
```

### Quick Start: Kitchen Sink Example
```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:dev
# Already has Python, Node, Ruby, Go installed
# Use for quick prototyping, not production
```

### Tag Strategy
```
ghcr.io/technicalpickles/agentic-container:
├── latest        → standard target (main maintained image)
├── v1.2.3        → versioned releases of standard
├── main          → bleeding edge standard 
└── dev           → kitchen sink example (not maintained)
```

## Benefits of This Approach

### For Maintainers
- **Reduced complexity**: 2 build targets instead of 7
- **Focused maintenance**: One image to keep updated with latest tools
- **Simpler CI/CD**: Minimal build matrix, faster builds
- **Clear responsibility**: Standard image quality vs dev example usage

### For Users  
- **Predictable experience**: One well-maintained base to learn
- **Flexible extension**: Get exactly the languages you need
- **Clear documentation**: Extension patterns instead of variant selection
- **No breaking changes**: Extension approach is stable across updates

### For Project Health
- **Sustainable maintenance**: Focus energy on one excellent base
- **Better testing**: Thorough testing of standard + extension patterns
- **Clearer value proposition**: Solid foundation + flexibility

## Implementation Changes Needed

### 1. Dockerfile Restructuring
```dockerfile
# Remove these stages:
# - minimal (merge into standard)  
# - ruby, node, python, go (individual variants)
# - ruby-stage, node-stage, python-stage, go-stage (if not needed for dev)

# Keep these stages:
# - standard (becomes the main target)
# - dev (example only, can use simplified approach)
```

### 2. GitHub Actions Simplification
```yaml
# Before: 7 targets
strategy:
  matrix:
    target: [minimal, standard, dev, ruby, node, python, go]

# After: 2 targets  
strategy:
  matrix:
    target: [standard, dev]
```

### 3. Documentation Updates
- Update README to focus on extension patterns
- Revise examples to use `latest` instead of `minimal`
- Add clear guidance on when to use `dev` vs extend `latest`
- Create extension cookbook with common language combinations

### 4. Example File Updates
- `docs/examples/extend-minimal-fullstack.dockerfile` → use `latest`
- Add more extension examples for common combinations
- Update `test-extensions.sh` to test against `latest`

## Migration Strategy

### Phase 1: Simplify Build (Week 1)
1. **Update Dockerfile**
   - Remove minimal, individual language stages
   - Ensure standard target has everything needed
   - Test that dev target still builds correctly

2. **Update GitHub Actions**
   - Reduce matrix to [standard, dev]
   - Update tag generation
   - Test build pipeline

3. **Update Examples**
   - Change extension examples to use `latest`
   - Test all examples still work

### Phase 2: Documentation (Week 1-2)
1. **Update README**
   - Focus on extension pattern
   - Clear guidance on `latest` vs `dev` usage
   - Migration guide for existing users

2. **Create Extension Cookbook**
   - Common language combinations
   - Best practices for Dockerfile extension
   - Examples for specific use cases

### Phase 3: Deprecation Communication (Ongoing)
1. **Announce changes** in releases
2. **Provide migration examples** for each removed variant
3. **Keep old tags available** during transition period

## Success Metrics

### Maintenance Simplification
- **CI build time**: Should decrease with fewer targets
- **Update frequency**: Can update standard more frequently  
- **Issue complexity**: Fewer variant-specific issues

### User Experience
- **Documentation clarity**: Single clear path for users
- **Extension adoption**: Users successfully extending `latest`
- **Support requests**: Fewer "which image should I use" questions

## Risk Mitigation

### User Confusion During Transition  
- **Clear migration documentation** with exact replacements
- **Deprecation notices** on removed tags (if possible)
- **Examples for every removed variant**

### Functionality Loss
- **Test extension patterns** thoroughly before removing variants
- **Ensure mise works reliably** for language installation
- **Document any edge cases** in extension cookbook

### Breaking Changes
- **Keep existing tags working** during transition period
- **Provide exact Dockerfile replacements** for each removed variant
- **Use semantic versioning** to communicate changes

## Future Considerations

### Extension Tooling
- Could provide helper scripts for common language combinations
- Consider `extend-image.sh` enhancements for popular patterns
- Documentation on optimizing extended images

### User Feedback Integration
- Monitor which extension patterns are most common
- Consider adding convenience features to standard based on usage
- Iterate based on actual user needs vs theoretical use cases

---

**Decision**: Move forward with simplified approach focused on single maintained `standard` image plus extension patterns.

**Next Steps**: Begin Phase 1 implementation with Dockerfile and CI/CD updates.
