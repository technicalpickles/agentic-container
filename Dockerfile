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
ARG LEFTHOOK_VERSION=1.13.6
ARG UV_VERSION=0.8.23
ARG CLAUDE_CODE_VERSION=1.0.128
ARG CODEX_VERSION=0.41.0
ARG GOSS_VERSION=0.4.9
ARG STARSHIP_VERSION=1.23.0

FROM ubuntu:24.04 AS builder

# Re-declare ARGs needed in this stage (inherit from global)
ARG NODE_VERSION
ARG PYTHON_VERSION

# Set up mise for system-wide installations (optimized configuration)
ENV MISE_DATA_DIR=/usr/local/share/mise
ENV MISE_CONFIG_DIR=/etc/mise  
ENV MISE_CACHE_DIR=/tmp/mise-cache
# Add mise shims to PATH - no activation needed!
ENV PATH="/usr/local/share/mise/shims:${PATH}"

# Install build dependencies only
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    bzip2 \
    cmake \
    curl \
    ca-certificates \
    unzip \
    xz-utils \
    zip \
    # Install version managers in builder stage
    && curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    # Install rv (fast precompiled Ruby binaries)
    && curl --proto '=https' --tlsv1.2 -LsSf https://github.com/spinel-coop/rv/releases/download/v0.1.1/rv-installer.sh | sh \
    && mv /root/.cargo/bin/rv /usr/local/bin/rv \
    && rm -rf /var/lib/apt/lists/*

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
    mv $MISE_DATA_DIR/installs/ruby/ruby-${RUBY_VERSION} $MISE_DATA_DIR/installs/ruby/${RUBY_VERSION} \
    && mise use -g ruby@${RUBY_VERSION}

FROM builder AS go-stage
# Re-declare ARG for this stage (inherit from global)
ARG GO_VERSION
# https://endoflife.date/go - Install to global mise directory  
RUN mise use -g go@${GO_VERSION}

FROM builder AS node-stage
# Re-declare ARG for this stage (inherit from global)
ARG NODE_VERSION
# https://endoflife.date/nodejs - Install to global mise directory
RUN mise use -g node@${NODE_VERSION}

FROM builder AS python-stage
# Re-declare ARG for this stage (inherit from global)
ARG PYTHON_VERSION
# https://endoflife.date/python - Install to global mise directory
RUN mise use -g python@${PYTHON_VERSION}

FROM builder AS lefthook-stage
# Re-declare ARG for this stage (inherit from global)
ARG LEFTHOOK_VERSION
RUN mise use -g lefthook@${LEFTHOOK_VERSION}

FROM node-stage AS claude-code-stage
# Re-declare ARG for this stage (inherit from global)
ARG CLAUDE_CODE_VERSION
ARG NODE_VERSION
RUN npm install -g @anthropic-ai/claude-code@^${CLAUDE_CODE_VERSION}

FROM node-stage AS codex-stage
ARG CODEX_VERSION
ARG NODE_VERSION
RUN npm install -g @openai/codex@^${CODEX_VERSION}

FROM builder AS starship-stage
RUN mise use -g starship@${STARSHIP_VERSION}

FROM builder AS ast-grep-stage
ARG AST_GREP_VERSION
RUN mise use -g ast-grep@${AST_GREP_VERSION}

FROM builder AS goose-stage
ARG GOOSE_VERSION
ENV GOOSE_BIN_DIR=/usr/local/bin
ENV CONFIGURE=false
RUN curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | bash

FROM builder AS opencode-stage
RUN curl -fsSL https://opencode.ai/install | bash \
    && mv /root/.opencode/bin/opencode /usr/local/bin/opencode

# =============================================================================
# STANDARD LAYER: Main development image with enhanced experience
# Foundation with core system tools, mise version manager, Docker CLI, and dev tools (~750MB target)
# This is the primary maintained image that users should extend
# =============================================================================
FROM ubuntu:24.04 AS standard

# Re-declare ARGs needed in this stage (inherit from global)
ARG NODE_VERSION
ARG PYTHON_VERSION
ARG UV_VERSION
ARG GOSS_VERSION
ARG STARSHIP_VERSION

# Create a non-root user for devcontainer use
ARG USERNAME=agent
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# Set up mise for system-wide installations (optimized configuration)
ENV MISE_DATA_DIR=/usr/local/share/mise
ENV MISE_CONFIG_DIR=/etc/mise  
ENV MISE_CACHE_DIR=/tmp/mise-cache
# Add mise shims to PATH - no activation needed!
ENV PATH="/usr/local/share/mise/shims:${PATH}"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

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
    && find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true

# Copy configuration files
COPY config/gitconfig /etc/gitconfig
COPY config/shell-profile.sh /etc/bash.bashrc
COPY config/shell-profile.sh /etc/profile
COPY --chown=$USERNAME:$USERNAME config/shell-profile.sh /home/$USERNAME/.bashrc
COPY --chown=$USERNAME:$USERNAME config/shell-profile.sh /home/$USERNAME/.bash_profile
COPY --chown=$USERNAME:$USERNAME config/shell-profile.sh /home/$USERNAME/.profile

# Copy version managers and common languages from builder stage
COPY --from=builder /usr/local/bin/mise /usr/local/bin/mise
COPY --from=builder /usr/local/bin/rv /usr/local/bin/rv
COPY --from=node-stage $MISE_DATA_DIR/installs/node $MISE_DATA_DIR/installs/node  
COPY --from=python-stage $MISE_DATA_DIR/installs/python $MISE_DATA_DIR/installs/python
COPY --from=starship-stage $MISE_DATA_DIR/installs/starship $MISE_DATA_DIR/installs/starship

# Create mise group for shared access to directories and add root to it
RUN groupadd --gid 2000 mise \
    && usermod -aG mise root \
    # Configure mise with optimized setup and add shims to PATH with group permissions
    && mkdir -p $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    # Set group ownership and permissions for shared access
    && chgrp -R mise $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    && chmod -R g+ws $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    # Ensure parent directories support group creation
    && chgrp mise /usr/local/share && chmod g+ws /usr/local/share \
    # install node and python globally, since frequently used for mcp
    && mise use -g node@${NODE_VERSION} python@${PYTHON_VERSION} starship@${STARSHIP_VERSION} \
    # Install uv for MCP server support (includes uvx), goss for testing
    && GITHUB_TOKEN=$(cat /run/secrets/github_token) mise use -g uv@${UV_VERSION} goss@${GOSS_VERSION} \
    # Fix permissions on config files for mise group access
    && chmod g+w $MISE_CONFIG_DIR/config.toml \
    # Create user and group
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && (groupadd docker 2>/dev/null || true) \
    && usermod -aG docker,mise $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    # Create workspace directory
    && mkdir -p /workspace \
    && chown $USERNAME:$USERNAME /workspace \
    # make sure user owns their home directory
    && chown -R $USERNAME:$USERNAME /home/$USERNAME

USER $USERNAME

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
ARG USERNAME
ARG NODE_VERSION
ARG PYTHON_VERSION
ARG RUBY_VERSION
ARG GO_VERSION
ARG LEFTHOOK_VERSION
ARG AST_GREP_VERSION
ARG CLAUDE_CODE_VERSION
ARG CODEX_VERSION
ARG STARSHIP_VERSION

# Copy additional language installations from build stages
# (python and node are already available from the standard stage)
COPY --from=ruby-stage $MISE_DATA_DIR/installs/ruby $MISE_DATA_DIR/installs/ruby
COPY --from=lefthook-stage $MISE_DATA_DIR/installs/lefthook $MISE_DATA_DIR/installs/lefthook
COPY --from=go-stage $MISE_DATA_DIR/installs/go $MISE_DATA_DIR/installs/go
COPY --from=ast-grep-stage $MISE_DATA_DIR/installs/ast-grep $MISE_DATA_DIR/installs/ast-grep
COPY --from=claude-code-stage $MISE_DATA_DIR/installs/node/$NODE_VERSION/lib/node_modules/@anthropic-ai/claude-code $MISE_DATA_DIR/installs/node/$NODE_VERSION/lib/node_modules/@anthropic-ai/claude-code
COPY --from=codex-stage $MISE_DATA_DIR/installs/node/$NODE_VERSION/lib/node_modules/@openai/codex $MISE_DATA_DIR/installs/node/$NODE_VERSION/lib/node_modules/@openai/codex
COPY --from=goose-stage /usr/local/bin/goose /usr/local/bin/goose
COPY --from=opencode-stage /usr/local/bin/opencode /usr/local/bin/opencode

# Configure global tool versions in system-wide mise config 
RUN mise use -g \
    python@${PYTHON_VERSION} \
    node@${NODE_VERSION} \
    ruby@${RUBY_VERSION} \
    go@${GO_VERSION} \
    lefthook@${LEFTHOOK_VERSION} \
    ast-grep@${AST_GREP_VERSION} \
    # Regenerate shims after installing all tools
    && mise reshim \
    # Fix permissions on config files for mise group access
    && chmod g+w $MISE_CONFIG_DIR/config.toml \
    # Cleanup after all installations, just in case
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* /var/tmp/* \
    && find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true

USER $USERNAME

WORKDIR /workspace