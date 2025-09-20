# Ruby Development Extension
# Demonstrates: mise install for Ruby, gem package manager
FROM ghcr.io/technicalpickles/agentic-container:main

# Build argument for Ruby version (can be overridden during build)
ARG RUBY_VERSION=3.4.5

# Install Ruby via rv (fast precompiled binaries) and build tools for native extensions
USER root
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && rv ruby install --install-dir $MISE_DATA_DIR/installs/ruby/ ruby-${RUBY_VERSION} \
    && mv $MISE_DATA_DIR/installs/ruby/ruby-${RUBY_VERSION} $MISE_DATA_DIR/installs/ruby/${RUBY_VERSION} \
    && mise use -g ruby@${RUBY_VERSION} \
    && gem install rails
USER agent

# No HEALTHCHECK - this container is designed for task execution, not service monitoring
WORKDIR /workspace
