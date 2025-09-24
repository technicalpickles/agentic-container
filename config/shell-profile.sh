#!/bin/bash
# =============================================================================
# Shared Shell Profile for agentic-container
# This file contains common shell configurations for both root and non-root users
# =============================================================================

# Set umask for group-writable files (supports mise group permissions)
umask 002



# Mise environment setup (already set via ENV in Dockerfile, but ensure they're available in shells when run interactively)
export MISE_DATA_DIR="${MISE_DATA_DIR:-/usr/local/share/mise}"
export MISE_CONFIG_DIR="${MISE_CONFIG_DIR:-/etc/mise}"
export MISE_CACHE_DIR="${MISE_CACHE_DIR:-/tmp/mise-cache}"

eval "$(mise activate bash)"
eval "$(starship init bash)"