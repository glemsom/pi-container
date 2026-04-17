# Pi Container

Run the [Pi coding agent](https://pi.dev) inside an isolated Docker container, with your working directory and configuration properly mounted.

This repository contains:
- `Dockerfile` - Docker image definition with Node.js 25, pi, and optional dependencies
- `run-pi.sh` - Wrapper script to run pi in a container

## Why Use a Container?

- **Isolation**: Pi runs in its own environment without polluting your host system
- **Consistency**: Same dependencies and Node.js version everywhere
- **Security**: Restrict what pi can access by controlling the container
- **Portability**: Works the same on any machine with Docker

## Quick Start

### 1. Build the Container

```bash
docker build -t pi-agent:latest .
# Or use the wrapper to build and run:
./run-pi.sh --update
```

### 2. Run Pi

**Interactive mode** (your current directory is mounted as `/workspace`):

```bash
./run-pi.sh
```

**With an initial prompt**:

```bash
./run-pi.sh "List all files in this project"
```

### 3. Set Up Authentication

Pi supports multiple providers. Set your API key in the environment:

```bash
# Anthropic (Claude)
export ANTHROPIC_API_KEY=sk-ant-...

# OpenAI
export OPENAI_API_KEY=sk-...

# Google
export GOOGLE_API_KEY=...

# Or use the wrapper with PI_API_KEY
PI_API_KEY=sk-ant-... ./run-pi.sh "Hello"
```

Or authenticate interactively inside the container:

```bash
./run-pi.sh
# Then type: /login
```

## Wrapper Script: `run-pi.sh`

The wrapper script handles:
- Mounting your working directory to `/workspace`
- Mounting Pi extensions, skills, themes, and prompts from `~/.pi/agent/` (if present, read-only)
- Mounting shared skills (`~/.agents`)
- Forwarding necessary environment variables
- Setting correct UID/GID for file ownership

### Usage

```
./run-pi.sh [options] [prompt]

Options:
  -h, --help           Show help
  -u, --update         Rebuild Docker image, then run pi
  -i, --image IMAGE    Docker image (default: pi-agent:latest)
  --no-mount-pi        Don't mount ~/.pi configuration (full isolation)
   --no-mcp-host-config  Reset MCP config to container defaults (overwrite existing)
  --verbose            Show docker commands
  --                   Pass through arguments to pi
```

### Examples

```
./run-pi.sh                                    # Interactive mode with host config
./run-pi.sh "List files in src/"              # Run with prompt
./run-pi.sh --update                           # Rebuild image, then run
./run-pi.sh --no-mcp-host-config "Hello"      # Reset MCP config to defaults
./run-pi.sh --no-mount-pi "Hello"             # Full isolation (no host config)
PI_API_KEY=sk-ant-... ./run-pi.sh "Hello"      # Set API key
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `PI_DOCKER_IMAGE` | Override default container image |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `OPENAI_API_KEY` | OpenAI API key |
| `GOOGLE_API_KEY` | Google API key |
| `CONTEXT7_API_KEY` | Context7 API key (for documentation MCP) |
| `GH_TOKEN` / `GITHUB_TOKEN` | GitHub token |
| `PI_CODING_AGENT_DIR` | Override Pi config directory (default: `~/.pi/agent`) |
| `PI_SKIP_VERSION_CHECK` | Skip version check |
| `PI_CACHE_RETENTION` | Cache retention settings |
| `PI_USE_CONTAINER_MCP` | Reset MCP config to container defaults on startup (internal, also via `--no-mcp-host-config` flag) |

Additional API keys supported: Azure OpenAI, AWS, Mistral, Groq, Cerebras, xAI, OpenRouter, HuggingFace, Kimi, MiniMax

## What's Mounted

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `$PWD` | `/workspace` | Your working directory (pi's cwd) |
| `~/.pi/agent/extensions` | `/home/node/.pi/agent/extensions` | Pi extensions (read-only) |
| `~/.pi/agent/skills` | `/home/node/.pi/agent/skills` | Custom Pi skills (read-only) |
| `~/.pi/agent/themes` | `/home/node/.pi/agent/themes` | UI themes (read-only) |
| `~/.pi/agent/prompts` | `/home/node/.pi/agent/prompts` | Prompt templates (read-only) |
| `~/.agents` | `/home/node/.agents` | Shared skills location |
| `~/.gitconfig` | `/home/node/.gitconfig` | Git configuration |
| `~/.ssh` | `/home/node/.ssh` | SSH keys (for git operations) |
| `~/.config/gh` | `/home/node/.config/gh` | GitHub CLI token |
| `/var/run/docker.sock` | `/var/run/docker.sock` | Docker socket (for host docker access) |

**Note:** Only selective subdirectories from `~/.pi/agent` are mounted to keep MCP configuration (`mcp.json`) and authentication (`auth.json`) container-managed. The container provides its own MCP config with `lean-ctx` and `context7` pre-configured.

## Pi Configuration

Pi stores configuration in `~/.pi/agent/`. Key files:

| Path | Purpose | Source |
|------|---------|--------|
| `settings.json` | Global settings | Container default (can override via env) |
| `auth.json` | Authentication tokens | Container-managed (use env vars for API keys) |
| `models.json` | Custom model configurations | Container |
| `sessions/` | Session history | Container |
| `extensions/` | Custom extensions | **Host-mounted** (if present) |
| `skills/` | Custom skills | **Host-mounted** (if present) |
| `themes/` | Custom themes | **Host-mounted** (if present) |
| `prompts/` | Prompt templates | **Host-mounted** (if present) |
| `mcp.json` | MCP server configuration | **Container-managed** (lean-ctx, context7) |

Only the highlighted subdirectories are mounted from your host `~/.pi/agent/`. All other configuration (including MCP servers) is managed inside the container to ensure the pre-installed tools are always available.

The container runs as user 1000:1000 with home `/home/node`.

## Customization

### Build a Custom Image

Edit the `Dockerfile` to add dependencies:

```dockerfile
FROM node:25-bookworm

# Install additional tools
RUN apt-get update && apt-get install -y \
    dumb-init \
    curl \
    git \
    openssh-client \
    # Add your tools here
    && rm -rf /var/lib/apt/lists/*

# Install pi
RUN npm install -g @mariozechner/pi-coding-agent

# ... rest of Dockerfile
```

### Installed Dependencies

The container comes with these packages pre-installed:
- `@mariozechner/pi-coding-agent` - The Pi coding agent
- `lean-ctx-bin` - Lean context management with MCP server
- `@aliou/pi-guardrails` - Guardrails plugin
- `@mjakl/pi-subagent` - Subagent plugin
- `ctx7` - Context management
- `@mariozechner/pi-mcp-adapter` - MCP adapter for Pi
- `@upstash/context7-mcp` - Context7 MCP server for documentation
- `lean-ctx init --agent pi` - Initialized for pi agent

## MCP Server Configuration

Pi supports MCP (Model Context Protocol) servers via the pi-mcp-adapter extension. The container includes `lean-ctx` and `context7` pre-configured.

### How MCP Works in the Container

Since only selective subdirectories from `~/.pi/agent` are mounted (extensions, skills, themes, prompts), MCP configuration is **container-managed**:

| Scenario | Behavior |
|----------|----------|
| Default (no `~/.pi` mounted) | Container uses built-in MCP config |
| Selective `~/.pi/agent/*` mount | Container MCP config is always used |
| Project `.pi/mcp.json` in workspace | Project config overrides container config |
| `--no-mcp-host-config` flag | Resets MCP config to container defaults |

The container's default MCP config is at `/etc/pi-mcp/default.json` and is copied to `/home/node/.pi/agent/mcp.json` at startup if needed.

### Pre-installed MCP Servers

| Server | Tools | Description |
|--------|-------|-------------|
| `lean-ctx` | 42 tools | Token-efficient context management, compression, and project intelligence |
| `context7` | 2 tools | Up-to-date documentation for 9000+ libraries (requires `CONTEXT7_API_KEY`) |

### Configuration

The container's default `~/.pi/agent/mcp.json`:

```json
{
  "settings": {
    "toolPrefix": "none",
    "idleTimeout": 10
  },
  "mcpServers": {
    "lean-ctx": {
      "command": "lean-ctx",
      "lifecycle": "lazy"
    },
    "context7": {
      "command": "context7-mcp",
      "env": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      },
      "lifecycle": "lazy"
    }
  }
}
```

### Context7 Setup

1. Get an API key from [context7.com/dashboard](https://context7.com/dashboard)
2. Set it as an environment variable:

```bash
export CONTEXT7_API_KEY=your_key_here
```

The `run-pi.sh` script automatically forwards this variable. Get your key at [context7.com/dashboard](https://context7.com/dashboard).

### Usage

In Pi, interact with MCP servers:

- `mcp({ search: "read file" })` — Search all tools (MCP + Pi)
- `mcp({ describe: "ctx_read" })` — Describe a specific tool
- `mcp({ tool: "ctx_read", args: '{"path": "file.rs", "mode": "full"}' })` — Call a tool
- `mcp({ connect: "lean-ctx" })` — Connect a server manually
- `/mcp` — Open interactive MCP panel

MCP servers are lazy by default — they connect only when you first call a tool, and disconnect after 10 minutes of inactivity.

## Development

To rebuild the image:

```bash
docker build -t pi-agent:latest .
```

To run with verbose output:

```bash
./run-pi.sh --verbose "your prompt"
```

To debug without removing the container:

```bash
docker run --rm -it --entrypoint /bin/bash pi-agent:latest
```

## File Structure

```
.
├── Dockerfile      # Docker image definition (Node.js 25, pi + plugins)
├── run-pi.sh      # Wrapper script to run pi in a container
└── README.md      # This file
```

## See Also

- [Pi Documentation](https://pi.dev)
- [Pi GitHub](https://github.com/badlogic/pi-mono)