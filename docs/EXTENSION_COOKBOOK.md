# Agent Extension Cookbook

**Created**: 2025-09-15  
**Purpose**: Practical examples and best practices for extending the agentic-container base image for AI agent workloads

## Overview

This cookbook provides copy-paste ready Dockerfile examples for common AI agent scenarios. All examples extend the maintained `latest` image and follow best practices for layer optimization and fast agent startup times.

| Use Case | Languages | Key Tools | Agent Focus |
|----------|-----------|-----------|-------------|
| [Claude Agent Environment](#claude-agent-environment) | Python + Node (standard) | anthropic, ast-grep, pydantic | +~200MB |
| [Code Analysis Agent](#code-analysis-agent) | Python + Node + Go | ast-grep, language-specific tools | +~300MB |
| [MCP Server Host](#mcp-server-host) | Python + Node (standard) | uvx, npx, protocol tools | +~200MB |
| [Multi-Language Agent](#multi-language-agent) | Python + Node + Go | All language toolchains | +~600MB |
| [Background Processing Agent](#background-processing-agent) | Python + Redis | Celery, background job tools | +~400MB |
| [Database Integration Agent](#database-integration-agent) | Python + SQL | SQLAlchemy, psycopg2, sqlite-utils | +~250MB |
| [Web Scraping Agent](#web-scraping-agent) | Python + Node.js | Playwright, BeautifulSoup, requests | +~500MB |
| [Agent Development Environment](#agent-development-environment) | Python + Node.js | Testing, debugging, analysis tools | +~450MB |

## Extension Patterns

### Environment Activation

```dockerfile
# ✅ Good: Python and Node.js available directly (installed as standard)
RUN \
    pip install package && \
    npm install -g tool
    
# ✅ Good: Additional languages use mise activation
RUN mise install ruby@3.4.5 && mise use -g ruby@3.4.5 && \
    gem install rails rake
    
# ⚠️ Works but less robust: Direct paths
RUN /home/$USERNAME/.local/share/mise/installs/ruby/3.4.5/bin/gem install rails
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
