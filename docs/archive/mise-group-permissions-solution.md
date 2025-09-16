# Mise Group Permissions Solution

## Problem Solved

The agentic-container had multiple mise-related permission issues:
- `mise use -g` failed (couldn't write to `/etc/mise/config.toml`)
- `mise install` failed (couldn't write to `/usr/local/share/mise/installs/`)
- `npm install -g` failed (couldn't write to mise-managed node modules)
- Extensions needed complex USER root/USER vscode patterns to work

The root cause was that mise installations were root-owned but the container runs as the agent user.

## Solution Overview

Implemented a **group-based permission system** using a dedicated `mise` group (GID 2000) that both `root` and `agent` users belong to.

### Key Changes Made

#### 1. Group Creation and User Assignment
```dockerfile
# Create mise group for shared access to directories and add root to it
RUN groupadd --gid 2000 mise \
    && usermod -aG mise root

# Add agent user to mise group during user creation
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && usermod -aG docker,mise $USERNAME
```

#### 2. Directory Permissions
```dockerfile
# Set group ownership and permissions for shared access
RUN mkdir -p $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    && chgrp -R mise $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    && chmod -R g+ws $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    # Ensure parent directories support group creation
    && chgrp mise /usr/local/share && chmod g+ws /usr/local/share
```

#### 3. Default Permissions (umask 002)
```dockerfile
# Set umask for group-writable files in system-wide configs
&& echo 'umask 002' >> /etc/bash.bashrc \
&& echo 'umask 002' >> /etc/profile

# Set umask in user shell configs
echo 'umask 002' >> /home/$USERNAME/.bashrc
echo 'umask 002' >> /home/$USERNAME/.bash_profile  
echo 'umask 002' >> /home/$USERNAME/.profile
```

## Directories with Group Write Access

- `/etc/mise` - Global config directory
- `/usr/local/share/mise` - Main data directory
  - `/usr/local/share/mise/installs/` - Tool installations
  - `/usr/local/share/mise/shims/` - Executable shims  
  - `/usr/local/share/mise/plugins/` - Plugin data
  - `/usr/local/share/mise/downloads/` - Downloaded archives
  - `/usr/local/share/mise/tmp/` - Temporary build files
- `/tmp/mise-cache` - Cache directory
- `/usr/local/share` - Parent directory

## Benefits

1. **Both users can write**: Root and agent users can both run `mise use -g` and `mise install`
2. **Inherits group ownership**: The `g+s` (setgid) bit ensures new files/directories inherit the `mise` group
3. **Proper umask**: New files will be group-writable by default (`umask 002`)
4. **Extension-friendly**: Extensions no longer need complex USER switching patterns
5. **Consistent behavior**: Works the same way for both interactive and non-interactive shells

## Testing the Solution

Use the provided test script to validate the implementation:

```bash
# Copy test script into container
docker run --rm -it your-image-name bash
# Run the test script as agent user
./scratch/test-mise-group-permissions.sh

# Test as root user
sudo ./scratch/test-mise-group-permissions.sh
```

The test script validates:
- Directory write permissions for both users
- `mise use -g` functionality  
- `mise install` functionality
- File permission inheritance
- npm global install capability

## Key Implementation Details

### Permission Bits Explained
- `g+w` - Group write permission
- `g+s` - Set group ID (setgid) - new files inherit group ownership
- `umask 002` - Default permissions: `rwxrwxr-x` for dirs, `rw-rw-r--` for files

### Why GID 2000?
- Chosen to avoid conflicts with common system groups
- High enough to avoid user UID conflicts
- Consistent across container rebuilds

## Troubleshooting

If issues persist:

1. **Check group membership**: `groups` should show `mise` for both users
2. **Check directory permissions**: `ls -la /usr/local/share/mise` should show group ownership as `mise`
3. **Check umask**: `umask` should return `002` in shells
4. **Test inheritance**: Create a file in `/usr/local/share/mise` and check if it has group `mise`

## Alternative Approaches Considered

1. **User-level config**: Each user has separate mise installations
   - Pro: No permission issues
   - Con: Wastes space, complicates system-wide tooling

2. **ACLs**: Use filesystem Access Control Lists  
   - Pro: Very granular control
   - Con: More complex, not all filesystems support

The group-based approach provides the best balance of simplicity and functionality.
