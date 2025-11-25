#!/usr/bin/env bash

# debug-mise-activation.sh
#
# Purpose: Debug mise activation and PATH setup in Docker container
# Created: 2025-01-13
# Used for: Investigating why mise shims aren't on PATH in interactive container
#
# This script will help identify:
# 1. Which shell startup files are being read
# 2. Whether mise activation is working
# 3. What the PATH looks like before/after mise activation

echo "=== MISE ACTIVATION DEBUG SCRIPT ==="
echo "Current shell: $0"
echo "Shell options: $-"
echo ""

echo "=== ENVIRONMENT INFO ==="
echo "USER: $USER"
echo "HOME: $HOME"
echo "PWD: $PWD"
echo "SHELL: $SHELL"
echo ""

echo "=== PATH BEFORE MISE ==="
echo "PATH: $PATH"
echo ""

echo "=== MISE STATUS ==="
echo "Mise location: $(which mise)"
if command -v mise &> /dev/null; then
    echo "Mise version: $(mise --version)"
    echo "Mise root: $(mise root)"
    echo "Mise config dir: $(mise config dir)"
    echo ""

    echo "=== MISE TOOLS ==="
    mise list
    echo ""

    echo "=== MISE SHIMS DIR ==="
    mise_shims_dir="$(mise root)/shims"
    echo "Expected shims dir: $mise_shims_dir"
    if [ -d "$mise_shims_dir" ]; then
        echo "Shims dir exists: YES"
        echo "Shims dir contents:"
        ls -la "$mise_shims_dir" | head -10
    else
        echo "Shims dir exists: NO"
    fi
    echo ""
else
    echo "Mise not found in PATH"
fi

echo "=== CHECKING SHELL STARTUP FILES ==="
startup_files=(
    "/etc/bash.bashrc"
    "/etc/bashrc"
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.profile"
)

for file in "${startup_files[@]}"; do
    if [ -f "$file" ]; then
        echo "File: $file (EXISTS)"
        if grep -q "mise" "$file" 2>/dev/null; then
            echo "  Contains mise: YES"
            echo "  Mise lines:"
            grep -n "mise" "$file" | sed 's/^/    /'
        else
            echo "  Contains mise: NO"
        fi
    else
        echo "File: $file (MISSING)"
    fi
    echo ""
done

echo "=== TESTING MISE ACTIVATION ==="
echo "Before activation - python location: $(which python 2>/dev/null || echo 'NOT FOUND')"
echo "Before activation - node location: $(which node 2>/dev/null || echo 'NOT FOUND')"

echo ""
echo "Running: eval \"\$(mise activate bash)\""
eval "$(mise activate bash)"

echo "After activation - python location: $(which python 2>/dev/null || echo 'NOT FOUND')"
echo "After activation - node location: $(which node 2>/dev/null || echo 'NOT FOUND')"
echo ""

echo "=== PATH AFTER MISE ==="
echo "PATH: $PATH"
echo ""

echo "=== FINAL TOOL VERSIONS ==="
echo "Python: $(python --version 2>&1 || echo 'NOT AVAILABLE')"
echo "Node: $(node --version 2>&1 || echo 'NOT AVAILABLE')"
echo "Ruby: $(ruby --version 2>&1 || echo 'NOT AVAILABLE')"
echo ""

echo "=== DEBUG COMPLETE ==="
