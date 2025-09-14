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

RUN curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && echo 'eval "$(mise activate bash)"' >> /etc/bash.bashrc \
    && echo 'eval "$(mise activate bash)"' >> /etc/profile \
    && mkdir -p /root && echo 'eval "$(mise activate bash)"' >> /root/.bashrc

RUN curl -sS https://starship.rs/install.sh | FORCE=true sh && echo 'eval "$(starship init bash)"' >> /etc/bash.bashrc


FROM base AS ruby
RUN curl --proto '=https' --tlsv1.2 -LsSf https://github.com/spinel-coop/rv/releases/download/v0.1.1/rv-installer.sh | sh
# https://endoflife.date/ruby
RUN /root/.cargo/bin/rv ruby install --install-dir ~/.local/share/mise/installs/ruby/ ruby-3.4.5 && \
    mv ~/.local/share/mise/installs/ruby/ruby-3.4.5 ~/.local/share/mise/installs/ruby/3.4.5

FROM base AS node
# https://endoflife.date/nodejs
RUN mise install node@24.8.0 node@22.11.0

FROM base AS lefthook
RUN mise install lefthook@latest

FROM base AS python
# https://endoflife.date/python
RUN mise install python@3.13.7

FROM base AS go
# https://endoflife.date/go
RUN mise install go@1.25.1

FROM base AS dev

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

COPY --from=ruby /root/.local/share/mise/installs/ruby /root/.local/share/mise/installs/ruby
COPY --from=node /root/.local/share/mise/installs/node /root/.local/share/mise/installs/node
COPY --from=lefthook /root/.local/share/mise/installs/lefthook /root/.local/share/mise/installs/lefthook
COPY --from=python /root/.local/share/mise/installs/python /root/.local/share/mise/installs/python
COPY --from=go /root/.local/share/mise/installs/go /root/.local/share/mise/installs/go

# Set up mise for both root and non-root user
RUN mise use -g python@3.13.7 \
    node@24.8.0 \
    ruby@3.4.5 \
    go@1.25.1 \
    lefthook@latest

# Create directories and copy mise installations to non-root user
RUN mkdir -p /home/$USERNAME/.local/share && \
    mkdir -p /home/$USERNAME/.config/mise && \
    cp -r /root/.local/share/mise /home/$USERNAME/.local/share/ && \
    if [ -f /root/.config/mise/config.toml ]; then cp /root/.config/mise/config.toml /home/$USERNAME/.config/mise/; fi && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.local /home/$USERNAME/.config

# Set up shell for non-root user
RUN echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.bashrc && \
    echo 'eval "$(starship init bash)"' >> /home/$USERNAME/.bashrc && \
    echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.bash_profile

# Set up environment for both interactive and non-interactive use
RUN echo 'export DEBIAN_FRONTEND=noninteractive' >> /home/$USERNAME/.bashrc && \
    echo 'export TERM=xterm-256color' >> /home/$USERNAME/.bashrc && \
    echo 'export LANG=en_US.UTF-8' >> /home/$USERNAME/.bashrc && \
    echo 'export LC_ALL=en_US.UTF-8' >> /home/$USERNAME/.bashrc

# Create workspace directory
RUN mkdir -p /workspace && chown $USERNAME:$USERNAME /workspace

# Ensure mise is available in non-interactive shells (important for background agents)
RUN echo 'eval "$(mise activate bash)"' >> /home/$USERNAME/.profile

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