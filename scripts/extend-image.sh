#!/usr/bin/env bash

# extend-image.sh - Helper script for extending the agentic-container base images
# This script helps users create custom Dockerfiles based on the agentic-container images

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_REGISTRY="${BASE_REGISTRY:-ghcr.io/your-repo/agentic-container}"

show_help() {
    cat << EOF
extend-image.sh - Helper for extending agentic-container images

USAGE:
    extend-image.sh COMMAND [OPTIONS]

COMMANDS:
    init [BASE_IMAGE]     Initialize a new Dockerfile extending the specified base image
    add-language LANG     Add a language runtime to your Dockerfile  
    add-tool TOOL         Add a development tool to your Dockerfile
    build [TAG]           Build your extended image
    push [TAG]            Push your extended image to a registry
    help                  Show this help message

BASE IMAGES:
    minimal               Core system tools, mise, Docker CLI only (~500MB)
    standard              Minimal + starship prompt and dev enhancements (~750MB)  
    ruby                  Standard + Ruby runtime
    node                  Standard + Node.js runtime
    python                Standard + Python runtime
    go                    Standard + Go runtime  
    dev                   All languages and tools (kitchen sink) (~2GB)

EXAMPLES:
    # Start with just the minimal image
    extend-image.sh init minimal
    
    # Start with Node.js included
    extend-image.sh init node
    
    # Add Python to an existing Dockerfile
    extend-image.sh add-language python@3.12
    
    # Build and tag your custom image
    extend-image.sh build my-dev-container:latest
    
    # Push to GitHub Container Registry
    extend-image.sh push ghcr.io/myuser/my-dev-container:latest

ENVIRONMENT VARIABLES:
    BASE_REGISTRY         Registry for base images (default: ghcr.io/your-repo/agentic-container)
    DOCKER_BUILDKIT       Enable BuildKit features (default: 1)

EOF
}

init_dockerfile() {
    local base_image="${1:-tools}"
    local dockerfile="Dockerfile"
    
    if [[ -f "$dockerfile" ]]; then
        echo "WARNING: $dockerfile already exists. Backing up to $dockerfile.bak"
        cp "$dockerfile" "$dockerfile.bak"
    fi
    
    cat > "$dockerfile" << EOF
# Extended development container based on agentic-container
# Base image: $base_image
FROM $BASE_REGISTRY:$base_image

# =============================================================================
# CUSTOM EXTENSIONS
# Add your custom tools, languages, and configurations below
# =============================================================================

# Example: Add additional system packages
# USER root  
# RUN apt-get update && apt-get install -y \\
#     your-package \\
#     another-package \\
#     && rm -rf /var/lib/apt/lists/*

# Example: Add a language runtime using mise
# RUN mise install python@3.12 && mise use -g python@3.12

# Example: Install additional tools
# RUN curl -sSL https://example.com/install.sh | sh

# Example: Copy custom configuration files
# COPY .vimrc /home/\$USERNAME/.vimrc
# COPY .gitconfig /home/\$USERNAME/.gitconfig  

# Switch back to non-root user for the final image
# USER \$USERNAME

# Example: Set up custom environment variables
# ENV MY_CUSTOM_VAR=value

# Your working directory is already set to /workspace
# WORKDIR /workspace

EOF

    echo "✅ Created $dockerfile extending $BASE_REGISTRY:$base_image"
    echo ""
    echo "Next steps:"
    echo "1. Edit $dockerfile to add your custom requirements"
    echo "2. Run: extend-image.sh build my-image:tag"
    echo "3. Run: extend-image.sh push registry/my-image:tag"
}

add_language() {
    local lang_spec="${1:-}"
    local dockerfile="Dockerfile"
    
    if [[ -z "$lang_spec" ]]; then
        echo "ERROR: Language specification required (e.g., python@3.12, node@20)"
        exit 1
    fi
    
    if [[ ! -f "$dockerfile" ]]; then
        echo "ERROR: No Dockerfile found. Run 'extend-image.sh init' first."
        exit 1
    fi
    
    # Create backup
    cp "$dockerfile" "$dockerfile.bak"
    
    # Insert language installation before the final USER directive
    local temp_file=$(mktemp)
    local inserted=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^USER[[:space:]] ]] && [[ "$inserted" == false ]]; then
            echo "# Added language: $lang_spec" >> "$temp_file"
            echo "RUN mise install $lang_spec && mise use -g $lang_spec" >> "$temp_file"
            echo "" >> "$temp_file"
            inserted=true
        fi
        echo "$line" >> "$temp_file"
    done < "$dockerfile"
    
    # If we didn't find a USER directive, append to the end
    if [[ "$inserted" == false ]]; then
        echo "" >> "$temp_file"
        echo "# Added language: $lang_spec" >> "$temp_file"
        echo "RUN mise install $lang_spec && mise use -g $lang_spec" >> "$temp_file"
    fi
    
    mv "$temp_file" "$dockerfile"
    echo "✅ Added $lang_spec to $dockerfile"
}

add_tool() {
    local tool_spec="${1:-}"
    local dockerfile="Dockerfile"
    
    if [[ -z "$tool_spec" ]]; then
        echo "ERROR: Tool specification required (e.g., gh, jq, kubectl)"
        exit 1
    fi
    
    if [[ ! -f "$dockerfile" ]]; then
        echo "ERROR: No Dockerfile found. Run 'extend-image.sh init' first."
        exit 1
    fi
    
    # Create backup  
    cp "$dockerfile" "$dockerfile.bak"
    
    # Insert tool installation
    local temp_file=$(mktemp)
    local inserted=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^USER[[:space:]] ]] && [[ "$inserted" == false ]]; then
            echo "# Added tool: $tool_spec" >> "$temp_file"
            echo "RUN mise install $tool_spec" >> "$temp_file"
            echo "" >> "$temp_file"
            inserted=true
        fi
        echo "$line" >> "$temp_file"
    done < "$dockerfile"
    
    if [[ "$inserted" == false ]]; then
        echo "" >> "$temp_file"
        echo "# Added tool: $tool_spec" >> "$temp_file"  
        echo "RUN mise install $tool_spec" >> "$temp_file"
    fi
    
    mv "$temp_file" "$dockerfile"
    echo "✅ Added $tool_spec to $dockerfile"
}

build_image() {
    local tag="${1:-extended-dev-container:latest}"
    local dockerfile="Dockerfile"
    
    if [[ ! -f "$dockerfile" ]]; then
        echo "ERROR: No Dockerfile found. Run 'extend-image.sh init' first."
        exit 1
    fi
    
    echo "🏗️  Building image: $tag"
    export DOCKER_BUILDKIT=1
    docker build -t "$tag" -f "$dockerfile" .
    echo "✅ Built image: $tag"
}

push_image() {
    local tag="${1:-}"
    
    if [[ -z "$tag" ]]; then
        echo "ERROR: Image tag required for push"
        exit 1
    fi
    
    echo "📤 Pushing image: $tag"
    docker push "$tag"
    echo "✅ Pushed image: $tag"
}

main() {
    local command="${1:-help}"
    
    case "$command" in
        init)
            shift
            init_dockerfile "$@"
            ;;
        add-language)
            shift
            add_language "$@"
            ;;
        add-tool)
            shift
            add_tool "$@"
            ;;
        build)
            shift
            build_image "$@"
            ;;
        push)
            shift
            push_image "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "ERROR: Unknown command '$command'"
            echo "Run 'extend-image.sh help' for usage information."
            exit 1
            ;;
    esac
}

main "$@"
