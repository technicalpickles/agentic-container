FROM ubuntu:24.04 AS base

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    # Additional tools commonly needed in devcontainers
    vim \
    nano \
    less \
    jq \
    unzip \
    zip \
    tree \
    htop \
    procps \
    # Networking and debugging tools
    iputils-ping \
    netcat-traditional \
    telnet \
    # For background agents: proper signal handling
    dumb-init \
    # Locale support
    locales \
    # Install sudo for non-root user
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Generate locales
RUN locale-gen en_US.UTF-8

# Add Docker's official GPG key and repository
RUN mkdir -m 0755 -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker CLI and Docker Compose
RUN apt-get update && apt-get install -y docker-ce-cli docker-compose-plugin

# Install mise and configure for system-wide use
RUN curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# Set up mise for system-wide installations (based on research best practices)
ENV MISE_DATA_DIR=/usr/local/share/mise
ENV MISE_CONFIG_DIR=/etc/mise  
ENV MISE_CACHE_DIR=/tmp/mise-cache

# Create mise directories with proper permissions
RUN mkdir -p $MISE_DATA_DIR $MISE_CONFIG_DIR $MISE_CACHE_DIR \
    && chmod 755 $MISE_DATA_DIR $MISE_CONFIG_DIR

# Configure environment variables system-wide
RUN echo 'export MISE_DATA_DIR=/usr/local/share/mise' >> /etc/environment \
    && echo 'export MISE_CONFIG_DIR=/etc/mise' >> /etc/environment \
    && echo 'export MISE_CACHE_DIR=/tmp/mise-cache' >> /etc/environment \
    && echo 'eval "$(mise activate bash)"' >> /etc/bash.bashrc \
    && echo 'eval "$(mise activate bash)"' >> /etc/profile

RUN curl -sS https://starship.rs/install.sh | FORCE=true sh && echo 'eval "$(starship init bash)"' >> /etc/bash.bashrc


FROM base AS ruby
RUN curl --proto '=https' --tlsv1.2 -LsSf https://github.com/spinel-coop/rv/releases/download/v0.1.1/rv-installer.sh | sh \
    && mv /root/.cargo/bin/rv /usr/local/bin/rv
# https://endoflife.date/ruby - Install to global mise directory
RUN rv ruby install --install-dir $MISE_DATA_DIR/installs/ruby/ ruby-3.4.5 && \
    mv $MISE_DATA_DIR/installs/ruby/ruby-3.4.5 $MISE_DATA_DIR/installs/ruby/3.4.5

FROM base AS node
# https://endoflife.date/nodejs - Install to global mise directory
RUN mise install node@24.8.0 node@22.11.0

FROM base AS lefthook  
RUN mise install lefthook@latest

FROM base AS python
# https://endoflife.date/python - Install to global mise directory
RUN mise install python@3.13.7

FROM base AS go
# https://endoflife.date/go - Install to global mise directory  
RUN mise install go@1.25.1

FROM base AS dev

# Copy global mise installations from build stages
COPY --from=ruby $MISE_DATA_DIR/installs/ruby $MISE_DATA_DIR/installs/ruby
COPY --from=node $MISE_DATA_DIR/installs/node $MISE_DATA_DIR/installs/node  
COPY --from=lefthook $MISE_DATA_DIR/installs/lefthook $MISE_DATA_DIR/installs/lefthook
COPY --from=python $MISE_DATA_DIR/installs/python $MISE_DATA_DIR/installs/python
COPY --from=go $MISE_DATA_DIR/installs/go $MISE_DATA_DIR/installs/go

# Configure global tool versions in system-wide mise config
RUN mise use -g python@3.13.7 \
    node@24.8.0 \
    ruby@3.4.5 \
    go@1.25.1 \
    lefthook@latest

# Create a non-root user for devcontainer use
ARG USERNAME=vscode
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# Create user and group, avoiding common conflicts
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && (groupadd docker 2>/dev/null || true) \
    && usermod -aG docker $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set up shell for non-root user  
RUN echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.bashrc && \
    echo 'eval "$(starship init bash)"' >> /home/$USERNAME/.bashrc && \
    echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.bash_profile && \
    echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.profile

# Set up environment for both interactive and non-interactive use
RUN echo 'export DEBIAN_FRONTEND=noninteractive' >> /home/$USERNAME/.bashrc && \
    echo 'export TERM=xterm-256color' >> /home/$USERNAME/.bashrc && \
    echo 'export LANG=en_US.UTF-8' >> /home/$USERNAME/.bashrc && \
    echo 'export LC_ALL=en_US.UTF-8' >> /home/$USERNAME/.bashrc

# Create workspace directory
RUN mkdir -p /workspace && chown $USERNAME:$USERNAME /workspace

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

# Default command - can be overridden
CMD ["/bin/bash", "--login"]