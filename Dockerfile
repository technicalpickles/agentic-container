FROM ubuntu:24.04 AS base

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    ca-certificates \
    gnupg \
    lsb-release

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
COPY --from=ruby /root/.local/share/mise/installs/ruby /root/.local/share/mise/installs/ruby
COPY --from=node /root/.local/share/mise/installs/node /root/.local/share/mise/installs/node
COPY --from=lefthook /root/.local/share/mise/installs/lefthook /root/.local/share/mise/installs/lefthook
COPY --from=python /root/.local/share/mise/installs/python /root/.local/share/mise/installs/python
COPY --from=go /root/.local/share/mise/installs/go /root/.local/share/mise/installs/go

RUN mise use -g python@3.13.7 \
    node@24.8.0 \
    ruby@3.4.5 \
    go@1.25.1 \
    lefthook@latest