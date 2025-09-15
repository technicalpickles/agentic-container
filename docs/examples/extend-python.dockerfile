# Extension Example: Adding Python to Base Image
# 
# This example demonstrates how to extend the agentic-container base 
# image with Python runtime. This is useful when you need just Python added
# to the development environment.
#
# Build: docker build -f docs/examples/extend-python.dockerfile -t my-python-container .
# Run:   docker run -it --rm my-python-container

FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Python using mise as root
# Note: mise installs are cached, so this is efficient
USER root
RUN mise install python@3.13.7

# Set Python as the global version
RUN mise use -g python@3.13.7

# Verify installation works (demonstrates proper mise activation)
RUN bash -c 'eval "$(mise activate bash)" && python3 --version && pip --version'

# Optional: Install common Python packages
# RUN bash -c 'eval "$(mise activate bash)" && pip install requests pandas numpy'

# Switch to non-root user for security
USER vscode

# Set working directory
WORKDIR /workspace

# Set up shell environment for the user (mise activation is already configured)
# When you run this container, Python will be available automatically

# Test that everything works
RUN bash -c 'eval "$(mise activate bash)" && python3 -c "print(\"Python is ready for development!\")"'

# Default command
CMD ["/bin/bash", "--login"]
