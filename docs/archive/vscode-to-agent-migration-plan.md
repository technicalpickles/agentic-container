# Migration Plan: Change User from `vscode` to `agent`

## Purpose
This document outlines the comprehensive plan to rename the container user from `vscode` to `agent` throughout the agentic-container project.

## Created
2025-01-15

## Context
The current container uses `vscode` as the non-root user name, which was appropriate when this was conceived as a VS Code devcontainer. However, the project has evolved into a general-purpose agentic development environment, so the user name should reflect this broader purpose.

## Impact Analysis
The change affects **12 files** across the project:
- 1 main `Dockerfile`
- 6 example Dockerfiles 
- 5 documentation files
- Test scripts in the scratch area

### Files Found with `vscode` References
```
docs/examples/README.md
docs/examples/multistage-production/Dockerfile
docs/examples/react-frontend/Dockerfile
docs/examples/rails-fullstack/Dockerfile
docs/examples/go-microservices/Dockerfile
docs/examples/nodejs-backend/Dockerfile
Dockerfile
README.md
docs/API.md
docs/USAGE.md
docs/planning/phase1-implementation-plan.md
docs/user-management.md
```

## Detailed Changes Required

### 1. Main Dockerfile Changes
**File**: `Dockerfile` (Line 158)

**Current**:
```dockerfile
ARG USERNAME=vscode
ARG USER_UID=1001
ARG USER_GID=$USER_UID
```

**Change to**:
```dockerfile
ARG USERNAME=agent
ARG USER_UID=1001
ARG USER_GID=$USER_UID
```

**Impact**: This single change automatically updates all references to `$USERNAME` throughout the Dockerfile, including:
- User and group creation
- Home directory setup (`/home/agent`)
- Shell configuration files (`.bashrc`, `.bash_profile`, `.profile`)
- Sudo configuration file (`/etc/sudoers.d/agent`)
- Git configuration setup
- All path references

### 2. Example Dockerfiles (6 files)

#### docs/examples/multistage-production/Dockerfile
**Line 9**: `USER vscode` → `USER agent`

#### docs/examples/react-frontend/Dockerfile  
**Line 8**: `USER vscode` → `USER agent`

#### docs/examples/rails-fullstack/Dockerfile
**Line 12**: `USER vscode` → `USER agent`

#### docs/examples/go-microservices/Dockerfile
**Line 8**: `USER vscode` → `USER agent`

#### docs/examples/nodejs-backend/Dockerfile
**Line 13**: `USER vscode` → `USER agent`

#### docs/examples/python-cli/Dockerfile
**Need to check**: May also have `USER vscode` reference

### 3. Documentation Updates

#### README.md
**Line 368-370**: Update devcontainer.json example
```json
"customizations": {
  "vscode": {
    "extensions": ["ms-python.python", "ms-vscode.vscode-typescript-next"]
  }
}
```
**Note**: The key "vscode" here refers to VS Code editor customizations, not the user. This should likely remain as-is.

#### docs/API.md
**Lines 185, 197**: Update build argument documentation
- Change default value from `vscode` to `agent` in tables
- **Line 234**: Update file structure example from `/home/vscode/` to `/home/agent/`

#### docs/USAGE.md
**Lines 43, 44**: Update volume mount examples
```yaml
- ~/.gitconfig:/home/vscode/.gitconfig:ro
- ~/.ssh:/home/vscode/.ssh:ro
```
**Change to**:
```yaml
- ~/.gitconfig:/home/agent/.gitconfig:ro  
- ~/.ssh:/home/agent/.ssh:ro
```

**Lines 136, 151-158**: Update other path references
- Change username default from `vscode` to `agent` in documentation table
- Update all example volume mount paths

**Line 352**: Update cache volume example
```yaml
- python-packages:/home/vscode/.cache/pip
```
**Change to**:
```yaml
- python-packages:/home/agent/.cache/pip
```

#### docs/examples/README.md  
**Line 61**: Update user permissions example
```
- **User permissions**: USER root/USER vscode patterns
```
**Change to**:
```
- **User permissions**: USER root/USER agent patterns
```

#### docs/planning/phase1-implementation-plan.md
**Line 124**: Update example
```dockerfile
ARG USERNAME=vscode
```
**Change to**:
```dockerfile
ARG USERNAME=agent
```

#### docs/user-management.md  
**Major Update Required**: This file has extensive references to the `vscode` user throughout

**Key changes needed**:
- **Line 10**: "vscode user (UID 1001)" → "agent user (UID 1001)"
- **Line 19**: "both root and vscode users" → "both root and agent users"  
- **Line 29**: "usermod -aG mise vscode" → "usermod -aG mise agent"
- **Line 81, 120, 163, 184**: Multiple `USER vscode` → `USER agent` in code examples
- **Line 135**: `ARG USERNAME=vscode` → `ARG USERNAME=agent` in technical implementation section
- **Line 142, 149, 155**: References to vscode user in explanatory text
- **Multiple lines**: Path references `/home/vscode` → `/home/agent`
- **Line 216, 236, 239, 251**: More `USER vscode` → `USER agent` examples
- **Comments and explanations**: All descriptive text referencing the vscode user

**Scope**: ~25+ references need updating across the entire document

### 4. Docker Compose Configuration
**File**: `docker-compose.yml`

**Current**: Uses hardcoded `user: "1001:1001"`
**Action**: No changes required - this will continue to work since we're keeping the same UID/GID

**Optional Enhancement**: Could make this more explicit with variables, but not necessary.

### 5. Scratch Area Updates

#### scratch/mise-group-permissions-solution.md
**Lines to update**:
- Line 11: "the vscode user" → "the agent user"
- Line 15: "root and vscode users" → "root and agent users" 
- Line 25: "Add vscode user to mise group" → "Add agent user to mise group"
- Line 28: "usermod -aG docker,mise $USERNAME" (already parameterized, just update comment)
- Line 48: User shell config references
- Line 67: "Root and vscode users" → "Root and agent users"
- Line 82: "vscode user" → "agent user" 
- Line 84: "vscode user" → "agent user"

#### scratch/test-mise-group-permissions.sh
**Lines to update**:
- Line 7: "both root and vscode users" → "both root and agent users"
- Comments throughout that reference vscode user

### 6. Mise Group Permissions Compatibility
**Status**: ✅ **No changes needed**

The mise group permissions solution is already parameterized:
```dockerfile
usermod -aG docker,mise $USERNAME
```

This will automatically work for the `agent` user since it uses the `$USERNAME` variable.

## Implementation Strategy

### Phase 1: Core Dockerfile Changes (Low Risk)
1. **Main Dockerfile**: Change `ARG USERNAME=vscode` to `ARG USERNAME=agent`
2. **Example Dockerfiles**: Change all `USER vscode` to `USER agent` (5-6 files)  
3. **Test Build**: Verify container builds successfully

### Phase 2: Documentation Updates (Medium Effort)
4. **User Management Documentation**: Update docs/user-management.md (~25+ references - highest priority)
5. **API Documentation**: Update build arguments table and file structure examples
6. **Usage Documentation**: Update all volume mount path examples
7. **README**: Review and update any user references
8. **Planning Documentation**: Update examples

### Phase 3: Scratch Area Updates (Low Priority)
9. **Test Scripts**: Update comments and documentation references
10. **Permission Documentation**: Update user references in mise solution docs

### Phase 4: Validation and Testing
11. **Build Testing**: Test complete container build process
12. **Functional Testing**: Test mise permissions with new `agent` user
13. **Example Testing**: Verify all example Dockerfiles build
14. **Integration Testing**: Run test scripts to ensure full functionality

## Validation Steps

### Pre-Change Testing Checklist
```bash
# Build current image
docker build -t agentic-container:vscode-test .

# Test basic functionality
docker run --rm -it agentic-container:vscode-test bash -c "
  echo 'User:' \$(whoami)
  echo 'Groups:' \$(groups)
  echo 'Home dir:' \$HOME
  ls -la /home/
  mise --version
  mise ls
"

# Test mise permissions
docker run --rm -it agentic-container:vscode-test ./scratch/test-mise-group-permissions.sh
```

### Post-Change Testing Checklist
```bash
# Build new image
docker build -t agentic-container:agent-test .

# Test basic functionality
docker run --rm -it agentic-container:agent-test bash -c "
  echo 'User:' \$(whoami)
  echo 'Groups:' \$(groups)  
  echo 'Home dir:' \$HOME
  ls -la /home/
  mise --version
  mise ls
"

# Test mise permissions
docker run --rm -it agentic-container:agent-test ./scratch/test-mise-group-permissions.sh

# Test specific functionality
docker run --rm -it agentic-container:agent-test bash -c "
  mise use -g python@latest
  mise install ast-grep@latest
  npm install -g is-online
  npm uninstall -g is-online
"
```

### Example Dockerfile Testing
```bash
# Test each example builds successfully
for example in multistage-production react-frontend rails-fullstack go-microservices nodejs-backend python-cli; do
  echo "Testing $example..."
  docker build -f docs/examples/$example/Dockerfile -t test-$example .
  echo "$example: ✅ PASSED"
done
```

## Risk Assessment

### Low Risk (Safe Changes)
- **Main Dockerfile ARG change**: Already parameterized throughout with `$USERNAME`
- **Example Dockerfiles**: Simple `USER` statement changes
- **Docker compose**: No changes needed, uses UID/GID

### Medium Risk (Requires Careful Review)
- **Documentation updates**: Many path references, but no functional impact
- **Volume mount examples**: Important for user guidance but not functional

### No Risk
- **Mise group permissions**: Already parameterized, will work unchanged
- **Container functionality**: Same UID/GID maintains all permissions
- **Tool installations**: No impact on installed software or configurations

## Rollback Plan
If issues are discovered:
1. Change `ARG USERNAME=agent` back to `ARG USERNAME=vscode` in main Dockerfile
2. Revert example Dockerfiles `USER agent` to `USER vscode`
3. Rebuild image
4. All other changes are documentation-only and don't affect functionality

## Benefits of This Change

### Immediate Benefits
1. **Better naming alignment**: User name reflects the project's purpose as an agentic development environment
2. **Reduced confusion**: No longer implies VS Code dependency
3. **Cleaner branding**: Matches the "agentic-container" project name

### Long-term Benefits  
1. **Future-proofing**: Better foundation for agent-specific tooling and features
2. **Contributor clarity**: Makes the intended use case immediately obvious
3. **Documentation consistency**: Aligns all references with the project mission

## Key Insights from Analysis

1. **Well-parameterized design**: The original Dockerfile's use of `$USERNAME` variable makes this change much safer and easier than it could have been

2. **Minimal functional impact**: This is primarily a naming change - all permissions, group memberships, and functionality remain identical

3. **Documentation-heavy**: Most changes are in documentation and examples, which have no runtime impact

4. **Mise compatibility**: The group-based permissions solution already handles this change automatically

## Conclusion

This migration is low-risk due to the well-parameterized design of the original Dockerfile. The primary effort is in updating documentation and examples to maintain consistency. The functional container behavior will remain identical, just with a more appropriate user name that reflects the project's evolution into a general-purpose agentic development environment.
