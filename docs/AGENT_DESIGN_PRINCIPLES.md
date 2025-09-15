# Agent Design Principles

**Created**: 2025-09-15  
**Status**: Living Document  
**Purpose**: Core design principles guiding the agentic-container project

## Vision Statement

Agentic Container provides fast, reliable container environments optimized for AI agent execution in cloud platforms. We focus on enabling cloud providers, individual developers, and companies to deploy AI agents with predictable performance and minimal setup overhead.

## Core Design Principles

### 1. Agent-First Performance

**Fast startup time is critical**
- Pre-install common tools agents need to avoid setup scripts during execution
- Optimize container startup time as the primary performance metric
- Layer caching optimized for common agent extension patterns

**No interactive prompts**
- All operations must be headless and fail gracefully
- No commands that require user input or confirmation
- Designed for unattended execution in cloud environments

**Predictable behavior**
- Agents need consistent, reliable environments across runs
- Version pinning for reproducible builds
- Clear error handling and logging

### 2. MCP-Ready Runtime

**Universal tool availability**
- `uvx`, `npx`, and other package runners available regardless of primary language
- Agents can spin up MCP servers without additional setup
- Support for protocol-agnostic agent architectures

**Agent toolchain support**
- Pre-installed tools agents commonly need (ast-grep, tree-sitter parsers)
- Code analysis tools ready for structural code modification
- Cross-language parsing and analysis capabilities

**Model Context Protocol support**
- Ready for agents to host their own MCP servers
- Universal package runners for protocol server deployment
- Network configuration optimized for agent communication

### 3. Bare Docker Simplicity

**Not a devcontainer**
- Plain Docker images that work with any container orchestration
- No dependencies on VS Code or devcontainer ecosystem
- Cloud-provider friendly and platform-agnostic

**Minimal extension surface**
- Easy `FROM` + `RUN` patterns for customization
- No complex configuration files or setup procedures
- Straightforward extension via Dockerfile patterns

**Single responsibility**
- Focus on agent execution, not general development
- Clear boundaries around what the project does and doesn't do
- Avoid feature creep into developer tooling territory

### 4. Runtime Flexibility

**Language version control**
- Easy to specify exact versions needed for different codebases
- mise-based version management for consistency
- Support for multiple language versions when needed

**Layered approach**
- Start minimal, add only what you need
- Clear progression from base → tools → languages
- Efficient layer sharing across different agent configurations

**Version lock capability**
- Reproducible builds for production agent deployments
- Clear versioning strategy for base images
- Backward compatibility during transitions

### 5. Code Analysis Native

**AST tooling built-in**
- Pre-compiled parsers and analysis tools
- Support for structural code analysis across languages
- Ready for agents that modify code programmatically

**Multi-language parsing**
- Tree-sitter grammars for common languages
- Cross-language analysis capabilities
- Consistent APIs across different language parsers

**Analysis performance**
- Pre-compiled tools to avoid build time during agent execution
- Cached tooling for common operations
- Optimized for repeated analysis tasks

## What We Are NOT

### Not a General Development Environment

- We don't try to replace VS Code devcontainers
- We don't include developer UI tools (fancy prompts, etc.)
- We don't optimize for interactive development workflows
- We don't provide comprehensive IDE integrations

### Not a Universal Solution

- We don't try to cover every possible use case
- We focus on cloud agent execution, not edge cases
- We prioritize common agent patterns over niche requirements
- We maintain focus rather than trying to be everything

### Not a Traditional CI/CD Tool

- While agents might run in CI/CD, we're not optimized for that
- We focus on agent-specific needs rather than general automation
- We don't compete with dedicated CI/CD container solutions

## Success Metrics

### Primary Metrics (Must Optimize)
- **Container startup time**: Time from `docker run` to agent ready
- **Tool availability time**: Time from start to `ast-grep` and `mise` ready
- **Extension predictability**: Consistent behavior across agent deployments

### Secondary Metrics (Monitor and Improve)
- **Image size**: Smaller is better, but not at the expense of agent functionality
- **Build time**: Fast builds enable quick iteration
- **Layer efficiency**: Good caching for common extension patterns

### Tertiary Metrics (Nice to Have)
- **Documentation clarity**: Easy for new users to understand purpose
- **Community adoption**: Usage by agent platform providers
- **Extension ecosystem**: Common patterns shared by community

## Decision Framework

When evaluating new features, tools, or changes, ask:

### 1. **Does this improve agent execution?**
- Does it make agents start faster?
- Does it make agents more reliable?
- Does it enable new agent capabilities?

### 2. **Is this agent-specific?**
- Would general developers also want this feature?
- Is this something agents uniquely need?
- Does this align with cloud agent execution?

### 3. **Does this maintain simplicity?**
- Can users still extend with simple Dockerfile patterns?
- Does this introduce complex configuration requirements?
- Does this maintain our "bare Docker" principle?

### 4. **Is this sustainable to maintain?**
- Can we keep this updated alongside core agent tooling?
- Does this align with our limited maintenance bandwidth?
- Is the value worth the ongoing maintenance cost?

## Examples of Good vs. Bad Additions

### ✅ Good Additions
- **ast-grep**: Agents frequently need structural code analysis
- **uvx/npx universal availability**: Enables MCP server deployment
- **tree-sitter parsers**: Core capability for code modification agents
- **Fast startup optimizations**: Directly improves agent performance

### ❌ Bad Additions
- **Jupyter notebooks**: This is developer tooling, not agent execution
- **VS Code extensions**: We're not targeting developer environments
- **Complex IDE integrations**: Agents don't need interactive development tools
- **Game development tools**: Outside our agent execution focus

## Evolution Strategy

### Short-term (Next 6 months)
- Implement core agent tooling (ast-grep, tree-sitter, etc.)
- Optimize startup time and reliability
- Create agent-focused documentation and examples
- Build adoption with agent platform providers

### Medium-term (6-12 months)
- Monitor agent usage patterns and optimize accordingly
- Develop specialized variants for common agent patterns
- Build community around agent-specific extensions
- Performance benchmarking and optimization

### Long-term (12+ months)
- Adapt to evolution of agent platforms and requirements
- Consider architectural changes based on real-world usage
- Potential integration with emerging agent standards
- Continue focus on simplicity and performance

## Community Guidelines

### For Contributors
- Propose changes through the lens of agent execution improvement
- Consider maintenance burden in all suggestions
- Test changes with realistic agent workloads
- Document agent-specific use cases and benefits

### For Users
- Extend for agent-specific needs, not general development
- Share common agent patterns with the community
- Report performance issues and reliability problems
- Help maintain focus on agent execution use cases

---

**Remember**: Every decision should make it easier and faster to run AI agents in cloud environments. When in doubt, choose simplicity and agent performance over features.
