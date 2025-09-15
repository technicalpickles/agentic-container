# User Management in agentic-container

This document explains the user management patterns used in the agentic-container and the reasoning behind design decisions.

## Overview

The agentic-container uses a **dual-user pattern** with explicit USER switching to balance security, functionality, and simplicity:

- **`root` user**: For operations requiring system-level permissions
- **`agent` user (UID 1001)**: Default non-root user for development and runtime

## Design Decision: Explicit USER Switching

### Background

During development, we investigated two approaches for managing permissions in extension Dockerfiles:

1. **Group-based permissions**: Create a shared group allowing both root and agent users to write to tool directories
2. **Explicit USER switching**: Use `USER root` for privileged operations, `USER agent` for everything else

### Investigation Results

We implemented and tested a group-based approach using a `mise` group (GID 2000) with the following setup:

```dockerfile
# Group-based approach (tested but not adopted)
RUN groupadd --gid 2000 mise \
    && usermod -aG mise root \
    && usermod -aG mise agent \
    && chgrp -R mise /usr/local/share/mise /etc/mise \
    && chmod -R g+ws /usr/local/share/mise /etc/mise
```

**Findings:**
- ✅ Basic operations worked (listing tools, using pre-installed tools)
- ✅ Most file operations succeeded with group permissions
- ❌ Complex lock file operations failed during `mise install` of new tools
- ❌ Tool-specific permission requirements created edge cases
- ❌ Debugging permission issues was more complex

### Final Decision: Explicit USER Switching

We chose **explicit USER switching** for the following reasons:

#### Advantages
1. **Predictable**: Clear when operations run with which privileges
2. **Debuggable**: Permission issues are easy to identify and fix
3. **Reliable**: No edge cases with tool-specific permission requirements
4. **Universal**: Works with all tools and package managers
5. **Standard**: Follows established Docker patterns

#### Trade-offs
1. **Slightly more verbose**: Requires explicit `USER root` and `USER vscode` statements
2. **Layer overhead**: Each USER switch creates a small metadata overhead

## Usage Patterns

### Pattern 1: Tool Installation (Requires Root)

Use `USER root` for:
- Installing new language runtimes via mise (`mise install`)  
- Installing global packages (`npm install -g`, `gem install`, etc.)
- Installing system packages (`apt-get install`)
- Writing to system directories

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install new language runtime
USER root
RUN mise install ruby@3.4.1

# Install global packages  
RUN gem install rails bundler

# Install system packages
RUN apt-get update && apt-get install -y postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Switch back to non-root user
USER agent
WORKDIR /workspace
```

### Pattern 2: User-level Operations (vscode user)

No USER switching needed for:
- Installing Python packages (`pip install`)
- Running application commands  
- Creating files in workspace
- Using pre-installed tools

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Python packages install as user by default
RUN pip install click typer rich pydantic

# No USER switching needed
WORKDIR /workspace
```

### Pattern 3: Mixed Operations

When you need both root and user operations:

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# User-level operations first (if any)
RUN pip install requests

# Root operations grouped together
USER root
RUN mise install go@1.23.5 \
    && apt-get update && apt-get install -y postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Switch back for runtime
USER agent

# User-level operations that depend on root installations
RUN go install github.com/air-verse/air@latest

WORKDIR /workspace
```

## Technical Implementation

### User Setup

The base image creates the agent user with:

```dockerfile
ARG USERNAME=agent
ARG USER_UID=1001
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && usermod -aG docker $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME
```

### Key Features

1. **Passwordless sudo**: agent user can use `sudo` without password
2. **Docker group**: agent user can access Docker daemon  
3. **Home directory**: agent user has `/home/agent` home directory
4. **Shell configuration**: Pre-configured with mise activation and development tools

### Directory Ownership

- **System directories**: `/usr/local`, `/etc` owned by root
- **User directories**: `/home/agent`, `/workspace` owned by agent  
- **Tool directories**: `/usr/local/share/mise` owned by root (with group permissions as backup)

## Best Practices

### Extension Dockerfile Guidelines

1. **Default to agent user**: Only use `USER root` when necessary
2. **Group root operations**: Combine multiple root operations in single RUN statement
3. **Always return to agent**: End Dockerfile with `USER agent` 
4. **Document why root is needed**: Comment when root permissions are required

### Example: Well-structured Extension

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# ✅ Good: User-level operations first
RUN pip install fastapi uvicorn

# ✅ Good: Root operations grouped with clear purpose
USER root
RUN mise install go@1.23.5 \
    && go install github.com/air-verse/air@latest \
    # Install system dependencies for the application
    && apt-get update && apt-get install -y postgresql-client redis-tools \
    && rm -rf /var/lib/apt/lists/*

# ✅ Good: Return to non-root user
USER agent
WORKDIR /workspace

# ✅ Good: Runtime operations as non-root user  
CMD ["python", "app.py"]
```

### Anti-patterns to Avoid

```dockerfile
# ❌ Bad: Unnecessary root operations
USER root
RUN pip install requests  # pip works fine as agent user

# ❌ Bad: Forgetting to switch back to agent
USER root
RUN mise install ruby@3.4.1
# Missing: USER agent

# ❌ Bad: Multiple unnecessary switches
USER root
RUN mise install ruby@3.4.1
USER agent
USER root  # Switching back unnecessarily
RUN gem install rails
USER agent
```

## Security Considerations

1. **Principle of least privilege**: Use root only when required
2. **Minimize root time**: Group root operations together
3. **Clean return to user**: Always end with `USER agent`
4. **Sudo available**: agent user can escalate when needed at runtime

## Future Considerations

- **Group permissions remain available**: The base image retains group permission setup for tools that might benefit from it
- **Tool-specific patterns**: Some tools may work better with user ownership vs group permissions
- **Runtime flexibility**: Applications can use sudo for runtime privilege escalation if needed

## Troubleshooting

### Common Permission Issues

**Problem**: `Permission denied` when installing packages
```
RUN gem install rails
# ERROR: Permission denied
```

**Solution**: Use `USER root` for global package installation
```dockerfile
USER root
RUN gem install rails
USER agent
```

**Problem**: Files created as root when they should be owned by agent
```dockerfile
USER root
RUN some-command > /workspace/output.txt  # Wrong: file owned by root
```

**Solution**: Create files as agent user, or change ownership
```dockerfile
USER agent
RUN some-command > /workspace/output.txt  # Correct: file owned by agent
```

## Related Documentation

- [Extension Cookbook](EXTENSION_COOKBOOK.md) - Practical examples of extending the container
- [Usage Guide](USAGE.md) - How to use the container effectively
- [API Documentation](API.md) - Technical container specifications

---

*This document reflects decisions made during container development and testing. The explicit USER switching pattern was chosen after careful evaluation of alternatives, prioritizing reliability and simplicity over minimal verbosity.*
