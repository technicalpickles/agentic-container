# Extension Example: Adding Node.js to Base Image
#
# This example demonstrates how to extend the agentic-container base
# image with Node.js runtime. Ideal for JavaScript/TypeScript development.
#
# Build: docker build -f docs/examples/extend-nodejs.dockerfile -t my-node-container .
# Run:   docker run -it --rm my-node-container

FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Node.js using mise
RUN mise install node@24.8.0

# Set Node.js as the global version
RUN mise use -g node@24.8.0

# Verify installation works
RUN bash -c 'eval "$(mise activate bash)" && node --version && npm --version'

# Optional: Install global packages (uncomment as needed)
# RUN bash -c 'eval "$(mise activate bash)" && npm install -g typescript @types/node ts-node'

# Optional: Set npm configuration
# RUN bash -c 'eval "$(mise activate bash)" && npm config set init-license MIT && npm config set init-version 1.0.0'

# Switch to non-root user
USER vscode

# Set working directory
WORKDIR /workspace

# Test that everything works
RUN bash -c 'eval "$(mise activate bash)" && node -e "console.log(\"Node.js is ready for development!\")"'

# Default command
CMD ["/bin/bash", "--login"]
