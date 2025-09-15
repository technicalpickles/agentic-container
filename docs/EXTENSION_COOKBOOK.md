# Agent Extension Cookbook

**Created**: 2025-09-15  
**Purpose**: Practical examples and best practices for extending the agentic-container base image for AI agent workloads

## Overview

This cookbook provides copy-paste ready Dockerfile examples for common AI agent scenarios. All examples extend the maintained `latest` image and follow best practices for layer optimization and fast agent startup times.

## Quick Reference

| Use Case | Languages | Key Tools | Agent Focus |
|----------|-----------|-----------|-------------|
| [Claude Agent Environment](#claude-agent-environment) | Python 3.13.7 | anthropic, ast-grep, pydantic | +~300MB |
| [Code Analysis Agent](#code-analysis-agent) | Python + Node.js | ast-grep, tree-sitter, ripgrep | +~400MB |
| [MCP Server Host](#mcp-server-host) | Python + Node.js | uvx, npx, protocol tools | +~300MB |
| [Multi-Language Agent](#multi-language-agent) | Python + Node + Go | All language toolchains | +~600MB |
| [Background Processing Agent](#background-processing-agent) | Python + Redis | Celery, background job tools | +~400MB |
| [Database Integration Agent](#database-integration-agent) | Python + SQL | SQLAlchemy, psycopg2, sqlite-utils | +~250MB |
| [Web Scraping Agent](#web-scraping-agent) | Python + Node.js | Playwright, BeautifulSoup, requests | +~500MB |
| [Agent Development Environment](#agent-development-environment) | Python + Node.js | Testing, debugging, analysis tools | +~450MB |

## Extension Patterns

### Basic Agent Extension

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install and configure a single language for agent workload
RUN mise install python@3.13.7 && \
    mise use -g python@3.13.7 && \
    bash -c 'eval "$(mise activate bash)" && pip install anthropic pydantic python-dotenv'
```

### Multi-Language Agent Extension

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install multiple languages for cross-language agent analysis
RUN mise install python@3.13.7 node@24.8.0 go@1.25.1 && \
    mise use -g python@3.13.7 node@24.8.0 go@1.25.1 && \
    bash -c 'eval "$(mise activate bash)" && \
        pip install ast-grep-py tree-sitter libcst && \
        npm install -g @tree-sitter/cli typescript && \
        go install golang.org/x/tools/cmd/goimports@latest'
```

### Agent with System Dependencies

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Add system packages needed for agent operations
USER root
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Then add languages and agent tools as user
USER $USERNAME
RUN mise install python@3.13.7 && \
    mise use -g python@3.13.7 && \
    bash -c 'eval "$(mise activate bash)" && \
        pip install psycopg2-binary sqlite-utils && \
        pip install anthropic pydantic python-dotenv'
```

## Use Case Examples

### Claude Agent Environment

Optimized for Claude Desktop agents and similar AI code modification tools.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Python and system dependencies for agent operations
USER root
RUN apt-get update && apt-get install -y \
    python3-dev \
    build-essential \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
RUN mise install python@3.13.7 && mise use -g python@3.13.7

# Install agent-focused packages
RUN bash -c 'eval "$(mise activate bash)" && \
    pip install anthropic python-dotenv pydantic && \
    pip install requests aiohttp httpx && \
    pip install ast-grep-py tree-sitter libcst && \
    pip install sqlite-utils sqlalchemy'

# Verify agent toolchain is ready
RUN bash -c 'eval "$(mise activate bash)" && \
    ast-grep --version && \
    python3 -c "import anthropic; print(\"Claude agent runtime ready\")"'

WORKDIR /workspace
```

### Code Analysis Agent

Equipped for structural code analysis and modification across multiple languages.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install multiple languages for cross-language analysis
RUN mise install python@3.13.7 node@24.8.0 go@1.25.1 && \
    mise use -g python@3.13.7 node@24.8.0 go@1.25.1

# Install code analysis tooling
RUN bash -c 'eval "$(mise activate bash)" && \
    # Python analysis tools
    pip install ast-grep-py tree-sitter libcst && \
    pip install anthropic python-dotenv pydantic && \
    # Node.js parsing tools  
    npm install -g @tree-sitter/cli typescript-parser && \
    npm install -g @babel/parser @babel/traverse && \
    # Go analysis tools
    go install golang.org/x/tools/cmd/goimports@latest'

# Pre-install tree-sitter grammars for common languages
RUN bash -c 'eval "$(mise activate bash)" && \
    tree-sitter init-config && \
    tree-sitter install python javascript typescript go rust'

WORKDIR /workspace
```

### MCP Server Host

Ready for hosting Model Context Protocol servers in multiple languages.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install system packages for MCP server operations
USER root
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME

# Install multiple languages for versatile MCP server hosting
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0

# Install Python MCP tools
RUN bash -c 'eval "$(mise activate bash)" && \
    pip install pydantic httpx uvicorn fastapi && \
    pip install python-dotenv anthropic && \
    pip install sqlite-utils sqlalchemy'

# Install Node.js MCP tools  
RUN bash -c 'eval "$(mise activate bash)" && \
    npm install -g @modelcontextprotocol/sdk && \
    npm install -g express cors ws && \
    npm install -g typescript @types/node'

# Verify MCP server capabilities
RUN bash -c 'eval "$(mise activate bash)" && \
    uvx --help && npx --help && \
    python3 -c "import pydantic; print(\"MCP server runtime ready\")"'

# Common MCP server ports
EXPOSE 8080 3000

WORKDIR /workspace
```

### Go Microservices

Lightweight Go environment with popular frameworks and tools.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Go
RUN mise install go@1.25.1 && mise use -g go@1.25.1

# Install popular Go tools and frameworks
RUN bash -c 'eval "$(mise activate bash)" && \
    go install github.com/gin-gonic/gin@latest && \
    go install github.com/gorilla/mux@latest && \
    go install github.com/labstack/echo/v4@latest && \
    go install gorm.io/gorm@latest && \
    go install github.com/stretchr/testify@latest && \
    go install golang.org/x/tools/gopls@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest'

# Common Go application ports
EXPOSE 8080 9000

WORKDIR /workspace

# Set Go environment variables
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOSUMDB=sum.golang.org
```

### Ruby on Rails

Complete Ruby on Rails development environment.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install system dependencies for Ruby gems
USER root
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    libsqlite3-dev \
    libmysqlclient-dev \
    libvips-dev \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME

# Install Ruby
RUN mise install ruby@3.4.5 && mise use -g ruby@3.4.5

# Install Rails and common gems
RUN bash -c 'eval "$(mise activate bash)" && \
    gem install rails -v "~> 7.1" --no-document && \
    gem install bundler rspec-rails factory_bot_rails --no-document && \
    gem install pg mysql2 sqlite3 redis --no-document && \
    gem install devise cancancan rolify --no-document && \
    gem install image_processing mini_magick --no-document'

# Rails common ports
EXPOSE 3000

WORKDIR /workspace

# Configure Rails defaults
ENV RAILS_ENV=development
ENV RACK_ENV=development
```

### DevOps Toolkit

Essential tools for infrastructure management and deployment.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install system packages
USER root
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    apt-transport-https \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME

# Install languages for tooling
RUN mise install python@3.13.7 go@1.25.1 && \
    mise use -g python@3.13.7 go@1.25.1

# Install cloud and infrastructure tools
RUN bash -c 'eval "$(mise activate bash)" && \
    # AWS CLI
    pip install awscli boto3 && \
    # Ansible
    pip install ansible && \
    # Terraform
    mise install terraform@latest && mise use -g terraform@latest && \
    # Kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && sudo mv kubectl /usr/local/bin/ && \
    # Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && \
    # Docker Compose (additional)
    pip install docker-compose'

WORKDIR /workspace

# Set up useful aliases
RUN echo 'alias k=kubectl' >> ~/.bashrc && \
    echo 'alias tf=terraform' >> ~/.bashrc
```

### Web Scraping Agent

Optimized for web scraping and data extraction agents with browser automation.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install system dependencies for browser automation
USER root
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    libnss3-dev \
    libgconf-2-4 \
    libxss1 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME

# Install Python and Node.js for web scraping tools
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0

# Install Python web scraping tools
RUN bash -c 'eval "$(mise activate bash)" && \
    pip install requests beautifulsoup4 lxml && \
    pip install selenium playwright && \
    pip install scrapy && \
    pip install anthropic python-dotenv pydantic'

# Install Node.js automation tools  
RUN bash -c 'eval "$(mise activate bash)" && \
    npm install -g playwright && \
    npm install -g puppeteer && \
    npx playwright install'

# Install Python playwright browsers
RUN bash -c 'eval "$(mise activate bash)" && playwright install'

WORKDIR /workspace
```

### Machine Learning

Comprehensive ML environment with multiple frameworks and R support.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install system dependencies for ML
USER root
RUN apt-get update && apt-get install -y \
    python3-dev \
    python3-pip \
    build-essential \
    libhdf5-dev \
    libnetcdf-dev \
    libopenblas-dev \
    liblapack-dev \
    gfortran \
    r-base \
    r-base-dev \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME

# Install Python and R
RUN mise install python@3.13.7 && mise use -g python@3.13.7

# Install comprehensive ML stack
RUN bash -c 'eval "$(mise activate bash)" && \
    # Core ML libraries
    pip install numpy pandas scipy matplotlib seaborn plotly && \
    # Jupyter ecosystem  
    pip install jupyter jupyterlab ipywidgets && \
    # Machine Learning
    pip install scikit-learn xgboost lightgbm catboost && \
    # Deep Learning
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    pip install tensorflow keras && \
    # Computer Vision
    pip install opencv-python pillow imageio && \
    # NLP
    pip install transformers datasets tokenizers && \
    pip install nltk spacy && \
    # MLOps
    pip install mlflow wandb tensorboard && \
    # Data processing
    pip install dask ray polars && \
    # Databases
    pip install sqlalchemy duckdb sqlite-utils'

# Install R packages
RUN R -e "install.packages(c('ggplot2', 'dplyr', 'tidyr', 'caret', 'randomForest', 'xgboost'), repos='https://cran.rstudio.com/')"

# Expose Jupyter and MLflow ports
EXPOSE 8888 5000

WORKDIR /workspace

# Download common NLP models
RUN bash -c 'eval "$(mise activate bash)" && python -c "import nltk; nltk.download('punkt')"'
```

## Best Practices

### Layer Optimization

```dockerfile
# ✅ Good: Combine related operations
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0 && \
    bash -c 'eval "$(mise activate bash)" && \
        pip install django && \
        npm install -g typescript'

# ❌ Bad: Separate operations create unnecessary layers
RUN mise install python@3.13.7
RUN mise use -g python@3.13.7
RUN bash -c 'eval "$(mise activate bash)" && pip install django'
RUN mise install node@24.8.0
RUN npm install -g typescript
```

### System Package Management

```dockerfile
# ✅ Good: Clean up apt cache
USER root
RUN apt-get update && apt-get install -y \
    package1 \
    package2 \
    && rm -rf /var/lib/apt/lists/*

# ❌ Bad: Leaves cache files
RUN apt-get update
RUN apt-get install -y package1 package2
```

### Environment Activation

```dockerfile
# ✅ Good: Use mise activation for package installation
RUN bash -c 'eval "$(mise activate bash)" && \
    pip install package && \
    npm install -g tool'

# ⚠️ Works but less robust: Direct paths
RUN /home/$USERNAME/.local/share/mise/installs/python/3.13.7/bin/pip install package
```

### Port Management

```dockerfile
# ✅ Good: Document and expose relevant ports
# Jupyter notebook
EXPOSE 8888
# FastAPI/Flask development server
EXPOSE 8000
# Node.js development server  
EXPOSE 3000

# ❌ Unnecessary: Exposing too many ports
EXPOSE 3000 3001 3002 3003 8000 8001 8002 8080 8888 9000
```

### Working Directory

```dockerfile
# ✅ Good: Set working directory at the end
WORKDIR /workspace

# ❌ Bad: Setting WORKDIR too early can interfere with setup
```

## Troubleshooting

### Common Issues

**mise activation not working**
```dockerfile
# Solution: Use explicit bash activation
RUN bash -c 'eval "$(mise activate bash)" && pip install package'
```

**Permission errors during package installation**  
```dockerfile
# Solution: Ensure you're using the correct user
USER $USERNAME  # For language packages
USER root      # For system packages
```

**Large image sizes**
```dockerfile
# Solution: Clean up package managers
RUN apt-get update && apt-get install -y packages && rm -rf /var/lib/apt/lists/*
RUN bash -c 'eval "$(mise activate bash)" && pip install --no-cache-dir packages'
```

**Packages not found in container**
```dockerfile
# Solution: Verify mise activation in entrypoint or shell
RUN echo 'eval "$(mise activate bash)"' >> ~/.bashrc
```

## Contributing

Found a useful extension pattern? Please contribute:

1. Test your Dockerfile thoroughly
2. Follow the established format and naming  
3. Include size impact and key tools
4. Add troubleshooting notes if relevant
5. Submit a pull request

---

**Updated**: 2025-09-15  
**Next Review**: When new common patterns emerge
