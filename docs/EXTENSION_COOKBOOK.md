# Extension Cookbook

**Created**: 2025-09-15  
**Purpose**: Practical examples and best practices for extending the agentic-container base image

## Overview

This cookbook provides copy-paste ready Dockerfile examples for common development scenarios. All examples extend the maintained `latest` image and follow best practices for layer optimization.

## Quick Reference

| Use Case | Languages | Key Tools | Size Impact |
|----------|-----------|-----------|-------------|
| [Python Data Science](#python-data-science) | Python 3.13.7 | Jupyter, pandas, numpy | +~500MB |
| [Node.js Web App](#nodejs-web-application) | Node.js 24.8.0 | TypeScript, Express, testing tools | +~200MB |
| [Full-Stack Development](#full-stack-development) | Python + Node.js | Django, React, databases | +~800MB |
| [Go Microservices](#go-microservices) | Go 1.25.1 | Popular Go frameworks | +~300MB |
| [Ruby on Rails](#ruby-on-rails) | Ruby 3.4.5 | Rails, gems, PostgreSQL client | +~400MB |
| [DevOps Toolkit](#devops-toolkit) | Python + Go | kubectl, terraform, cloud CLIs | +~600MB |
| [Mobile Development](#mobile-development) | Node.js + Java | React Native, Android tools | +~1.2GB |
| [Machine Learning](#machine-learning) | Python + R | PyTorch, TensorFlow, Jupyter | +~1.5GB |

## Extension Patterns

### Basic Language Extension

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install and configure a single language
RUN mise install python@3.13.7 && \
    mise use -g python@3.13.7 && \
    bash -c 'eval "$(mise activate bash)" && pip install requests fastapi'
```

### Multi-Language Extension

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install multiple languages efficiently
RUN mise install python@3.13.7 node@24.8.0 go@1.25.1 && \
    mise use -g python@3.13.7 node@24.8.0 go@1.25.1 && \
    bash -c 'eval "$(mise activate bash)" && \
        pip install fastapi requests && \
        npm install -g typescript @types/node && \
        go install github.com/gin-gonic/gin@latest'
```

### System Packages + Languages

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Add system packages first
USER root
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Then add languages as user
USER $USERNAME
RUN mise install python@3.13.7 && \
    mise use -g python@3.13.7 && \
    bash -c 'eval "$(mise activate bash)" && pip install psycopg2-binary'
```

## Use Case Examples

### Python Data Science

Perfect for data analysis, machine learning experiments, and Jupyter notebooks.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Python and system dependencies for data science
USER root
RUN apt-get update && apt-get install -y \
    python3-dev \
    build-essential \
    libhdf5-dev \
    libnetcdf-dev \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
RUN mise install python@3.13.7 && mise use -g python@3.13.7

# Install data science stack
RUN bash -c 'eval "$(mise activate bash)" && \
    pip install jupyter jupyterlab && \
    pip install pandas numpy scipy matplotlib seaborn plotly && \
    pip install scikit-learn xgboost lightgbm && \
    pip install requests beautifulsoup4 sqlalchemy && \
    pip install duckdb sqlite-utils'

# Expose Jupyter port
EXPOSE 8888

WORKDIR /workspace

# Optional: Set up Jupyter config
RUN mkdir -p ~/.jupyter && \
    echo "c.NotebookApp.ip = '0.0.0.0'" >> ~/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.open_browser = False" >> ~/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.token = ''" >> ~/.jupyter/jupyter_notebook_config.py
```

### Node.js Web Application

Optimized for modern Node.js web development with TypeScript and testing tools.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install Node.js and configure
RUN mise install node@24.8.0 && mise use -g node@24.8.0

# Install global tools and frameworks
RUN bash -c 'eval "$(mise activate bash)" && \
    npm install -g typescript ts-node @types/node && \
    npm install -g express-generator @nestjs/cli && \
    npm install -g jest vitest cypress && \
    npm install -g nodemon pm2 && \
    npm install -g prettier eslint @typescript-eslint/parser'

# Common Node.js ports
EXPOSE 3000 8080

WORKDIR /workspace

# Set up npm defaults
RUN bash -c 'eval "$(mise activate bash)" && \
    npm config set init-author-name "Developer" && \
    npm config set init-license "MIT"'
```

### Full-Stack Development

Combines Python backend with Node.js frontend, plus database tools.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install system packages for databases
USER root
RUN apt-get update && apt-get install -y \
    postgresql-client \
    mysql-client \
    redis-tools \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME

# Install multiple languages
RUN mise install python@3.13.7 node@24.8.0 && \
    mise use -g python@3.13.7 node@24.8.0

# Install backend tools (Python)
RUN bash -c 'eval "$(mise activate bash)" && \
    pip install django fastapi uvicorn gunicorn && \
    pip install psycopg2-binary redis celery && \
    pip install pytest pytest-django requests && \
    pip install django-extensions django-debug-toolbar'

# Install frontend tools (Node.js)  
RUN bash -c 'eval "$(mise activate bash)" && \
    npm install -g create-react-app @angular/cli @vue/cli && \
    npm install -g typescript @types/react @types/node && \
    npm install -g vite webpack webpack-cli && \
    npm install -g tailwindcss postcss autoprefixer'

# Common web ports
EXPOSE 3000 8000 8080 5173

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

### Mobile Development

React Native and Android development setup.

```dockerfile
FROM ghcr.io/technicalpickles/agentic-container:latest

# Install system dependencies
USER root
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    android-sdk \
    gradle \
    unzip \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME

# Install Node.js for React Native
RUN mise install node@24.8.0 && mise use -g node@24.8.0

# Install React Native and mobile development tools
RUN bash -c 'eval "$(mise activate bash)" && \
    npm install -g react-native-cli @react-native-community/cli && \
    npm install -g expo-cli @expo/cli && \
    npm install -g typescript @types/react @types/react-native && \
    npm install -g flipper-server && \
    npm install -g detox-cli'

# Set up Android environment
ENV ANDROID_HOME=/usr/lib/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools

# Metro bundler port
EXPOSE 8081

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
