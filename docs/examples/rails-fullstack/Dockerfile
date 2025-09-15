# Ruby Development Extension
# Demonstrates: mise install for Ruby, gem package manager
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Ruby via mise
USER root
RUN mise install ruby@3.4.1

# Add Ruby packages via gem  
RUN gem install rails bundler

USER vscode
WORKDIR /workspace
