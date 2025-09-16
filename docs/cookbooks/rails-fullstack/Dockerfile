# Ruby Development Extension
# Demonstrates: mise install for Ruby, gem package manager
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Ruby via rv (fast precompiled binaries) and build tools for native extensions
USER root
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && rv ruby install --install-dir $MISE_DATA_DIR/installs/ruby/ ruby-3.4.5 \
    && mv $MISE_DATA_DIR/installs/ruby/ruby-3.4.5 $MISE_DATA_DIR/installs/ruby/3.4.5 \
    && mise use -g ruby@3.4.5 \
    && gem install rails
USER agent
WORKDIR /workspace
