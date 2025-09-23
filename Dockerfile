# =============================================================================
# BUILDER STAGE: Tools that need compilation or build dependencies
# This stage contains build tools and compilers needed for installation
# =============================================================================

# Build arguments for language versions and agent tools (can be overridden during build)
ARG NODE_VERSION=24.8.0
ARG PYTHON_VERSION=3.13.7
ARG RUBY_VERSION=3.4.5
ARG GO_VERSION=1.25.1
ARG AST_GREP_VERSION=0.39.5
ARG LEFTHOOK_VERSION=1.13.3
ARG UV_VERSION=0.8.20
ARG CLAUDE_CODE_VERSION=1.0.120
ARG CODEX_VERSION=2.0.0

FROM ubuntu:24.04 AS builder

# Re-declare ARGs needed in this stage (inherit from global)
ARG NODE_VERSION
ARG PYTHON_VERSION

# Set mise environment for consistent installation paths
ENV MISE_DATA_DIR=/usr/local/share/mise

# Install build dependencies only
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    curl \
    ca-certificates \
    xz-utils \
    # Install version managers in builder stage
    && curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    # Install rv (fast precompiled Ruby binaries)
    && curl --proto '=https' --tlsv1.2 -LsSf https://github.com/spinel-coop/rv/releases/download/v0.1.1/rv-installer.sh | sh \
    && mv /root/.cargo/bin/rv /usr/local/bin/rv \
    && rm -rf /var/lib/apt/lists/*

# Install commonly used languages in builder stage
# Install Node.js (https://endoflife.date/nodejs) and Python (https://endoflife.date/python)
RUN mise install node@${NODE_VERSION} \
    && mise install python@${PYTHON_VERSION}

# =============================================================================
# LANGUAGE-SPECIFIC BUILD STAGES FOR DEV IMAGE
# These install language runtimes for the kitchen sink dev example.
# We use multiple stages to enable parallelization, plus better utilize layer caching.
# =============================================================================

FROM builder AS ruby-stage
# Re-declare ARG for this stage (inherit from global)
ARG RUBY_VERSION
# https://endoflife.date/ruby - Install to global mise directory using rv (fast precompiled binaries)
RUN rv ruby install --install-dir $MISE_DATA_DIR/installs/ruby/ ruby-${RUBY_VERSION} && \
    mv $MISE_DATA_DIR/installs/ruby/ruby-${RUBY_VERSION} $MISE_DATA_DIR/installs/ruby/${RUBY_VERSION}

FROM builder AS go-stage
# Re-declare ARG for this stage (inherit from global)
ARG GO_VERSION
# https://endoflife.date/go - Install to global mise directory  
RUN mise install go@${GO_VERSION}

FROM builder AS lefthook-stage
# Re-declare ARG for this stage (inherit from global)
ARG LEFTHOOK_VERSION
RUN mise install lefthook@${LEFTHOOK_VERSION}

# =============================================================================
# STANDARD LAYER: Main development image with enhanced experience
# Foundation with core system tools, mise version manager, Docker CLI, and dev tools (~750MB target)
# This is the primary maintained image that users should extend
# =============================================================================
FROM ubuntu:24.04 AS standard

# Re-declare ARGs needed in this stage (inherit from global)
ARG NODE_VERSION
ARG PYTHON_VERSION
ARG AST_GREP_VERSION
ARG UV_VERSION
ARG CLAUDE_CODE_VERSION
ARG CODEX_VERSION

# Install essential runtime packages and development tools
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core system tools
    git \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    # Essential CLI tools
    vim \
    nano \
    less \
    jq \
    unzip \
    zip \
    ripgrep \
    fd-find \
    # Process management
    dumb-init \
    sudo \
    procps \
    # Locale support
    locales \
    # Development tools
    tree \
    htop \
    iputils-ping \
    netcat-traditional \
    telnet \
    # Install Docker CLI and GitHub CLI
    && mkdir -m 0755 -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin gh \
    # Generate locales
    && locale-gen en_US.UTF-8 \
    # Cleanup after installation
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* /var/tmp/* \
    && find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true \
    && find /usr/share/doc -depth -type f ! -name copyright -delete 2>/dev/null || true \
    && rm -rf /usr/share/man/* /usr/share/groff/* /usr/share/info/* /usr/share/lintian/* /usr/share/linda/* 2>/dev/null || true



# Set up mise for system-wide installations (optimized configuration)
ENV MISE_DATA_DIR=/usr/local/share/mise
ENV MISE_CONFIG_DIR=/etc/mise  
ENV MISE_CACHE_DIR=/tmp/mise-cache
# Add mise shims to PATH - no activation needed!
ENV PATH="/usr/local/share/mise/shims:${PATH}"

# Copy version managers and common languages from builder stage
COPY --from=builder /usr/local/bin/mise /usr/local/bin/mise
COPY --from=builder /usr/local/bin/rv /usr/local/bin/rv
COPY --from=builder $MISE_DATA_DIR/installs/node $MISE_DATA_DIR/installs/node  
COPY --from=builder $MISE_DATA_DIR/installs/python $MISE_DATA_DIR/installs/python

# Create mise group for shared access to directories and add root to it
RUN groupadd --gid 2000 mise \
    && usermod -aG mise root

# Configure mise with optimized setup and add shims to PATH with group permissions
RUN mkdir -p $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    # Set group ownership and permissions for shared access
    && chgrp -R mise $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    && chmod -R g+ws $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    # Ensure parent directories support group creation
    && chgrp mise /usr/local/share && chmod g+ws /usr/local/share \
    # Configure environment variables system-wide
    && echo 'export MISE_DATA_DIR=/usr/local/share/mise' >> /etc/environment \
    && echo 'export MISE_CONFIG_DIR=/etc/mise' >> /etc/environment \
    && echo 'export MISE_CACHE_DIR=/tmp/mise-cache' >> /etc/environment \
    # Add mise shims to PATH system-wide (enables tools in RUN commands without activation)
    && echo 'export PATH="/usr/local/share/mise/shims:$PATH"' >> /etc/environment \
    && echo 'export PATH="/usr/local/share/mise/shims:$PATH"' >> /etc/bash.bashrc \
    && echo 'export PATH="/usr/local/share/mise/shims:$PATH"' >> /etc/profile \
    # Set umask for group-writable files
    && echo 'umask 002' >> /etc/bash.bashrc \
    && echo 'umask 002' >> /etc/profile \
    # Also add mise activation for interactive shell features (auto-switching, etc.)
    && echo 'eval "$(mise activate bash)"' >> /etc/bash.bashrc \
    && echo 'eval "$(mise activate bash)"' >> /etc/profile \
    && mise use -g node@${NODE_VERSION} python@${PYTHON_VERSION} \
    # Install agent toolchain: ast-grep for structural code search, uv for MCP server support (includes uvx), goss for testing
    && GITHUB_TOKEN=$(cat /run/secrets/github_token) mise use -g ast-grep@${AST_GREP_VERSION} uv@${UV_VERSION} goss@${GOSS_VERSION} \
    # Install AI Coding Agents (GitHub CLI already installed above)
    && npm install -g @anthropic-ai/claude-code@^${CLAUDE_CODE_VERSION} @openai/codex@^${CODEX_VERSION} \
    && gh extension install github/gh-copilot \
    && curl -fsSL https://opencode.ai/install | bash \
    && curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | bash \
    # Cleanup after all installations
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* /var/tmp/* \
    && find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true \
    && find /usr/share/doc -depth -type f ! -name copyright -delete 2>/dev/null || true \
    && rm -rf /usr/share/man/* /usr/share/groff/* /usr/share/info/* /usr/share/lintian/* /usr/share/linda/* 2>/dev/null || true

# Create a non-root user for devcontainer use
ARG USERNAME=agent
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# Create user and group
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && (groupadd docker 2>/dev/null || true) \
    && usermod -aG docker,mise $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    # Create workspace directory
    && mkdir -p /workspace && chown $USERNAME:$USERNAME /workspace

# Add extension helper script
COPY scripts/extend-image.sh /usr/local/bin/extend-image
RUN chmod +x /usr/local/bin/extend-image

# Install starship prompt
RUN curl -sS https://starship.rs/install.sh | FORCE=true sh \
    && echo 'eval "$(starship init bash)"' >> /etc/bash.bashrc

# Set up enhanced shell for non-root user  
RUN echo 'eval "$(starship init bash)"' >> /home/$USERNAME/.bashrc && \
    # Add mise shims to PATH in user shell files (for RUN commands)
    echo 'export PATH="/usr/local/share/mise/shims:$PATH"' >> /home/$USERNAME/.bashrc && \
    echo 'export PATH="/usr/local/share/mise/shims:$PATH"' >> /home/$USERNAME/.bash_profile && \
    echo 'export PATH="/usr/local/share/mise/shims:$PATH"' >> /home/$USERNAME/.profile && \
    # Set umask for group-writable files
    echo 'umask 002' >> /home/$USERNAME/.bashrc && \
    echo 'umask 002' >> /home/$USERNAME/.bash_profile && \
    echo 'umask 002' >> /home/$USERNAME/.profile && \
    # Also add mise activation for interactive shell features
    echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.bashrc && \
    echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.bash_profile && \
    echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.profile

# Set up environment for both interactive and non-interactive use
RUN echo 'export DEBIAN_FRONTEND=noninteractive' >> /home/$USERNAME/.bashrc && \
    echo 'export TERM=xterm-256color' >> /home/$USERNAME/.bashrc && \
    echo 'export LANG=en_US.UTF-8' >> /home/$USERNAME/.bashrc && \
    echo 'export LC_ALL=en_US.UTF-8' >> /home/$USERNAME/.bashrc

USER $USERNAME

# Set git safe directory for the workspace (important for devcontainers)
RUN git config --global --add safe.directory /workspace && \
    git config --global --add safe.directory '*'

# Configure git with reasonable defaults for devcontainers  
RUN git config --global init.defaultBranch main && \
    git config --global pull.rebase false && \
    git config --global core.autocrlf input

# Set working directory
WORKDIR /workspace

# For background agents: use dumb-init as entrypoint for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# No HEALTHCHECK - this container is designed for agent task execution, not service monitoring
# Agents execute commands and return results; traditional health checks are not applicable

# Default command - can be overridden
CMD ["/bin/bash", "--login"]



# =============================================================================
# DEV IMAGE: Kitchen sink example with all languages
# This is provided as an example only - not actively maintained
# Users should extend 'standard' for production use
# =============================================================================
FROM standard AS dev

# Re-declare ARGs needed in this stage (inherit from global)
ARG NODE_VERSION
ARG PYTHON_VERSION
ARG RUBY_VERSION
ARG GO_VERSION
ARG LEFTHOOK_VERSION

# Copy additional language installations from build stages
# (python and node are already available from the standard stage)
COPY --from=ruby-stage $MISE_DATA_DIR/installs/ruby $MISE_DATA_DIR/installs/ruby
COPY --from=lefthook-stage $MISE_DATA_DIR/installs/lefthook $MISE_DATA_DIR/installs/lefthook
COPY --from=go-stage $MISE_DATA_DIR/installs/go $MISE_DATA_DIR/installs/go

USER root
# Configure global tool versions in system-wide mise config 
RUN mise use -g python@${PYTHON_VERSION} \
    node@${NODE_VERSION} \
    ruby@${RUBY_VERSION} \
    go@${GO_VERSION} \
    lefthook@${LEFTHOOK_VERSION}

USER $USERNAME