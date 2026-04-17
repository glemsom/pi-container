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
- Mounting Pi configuration (`~/.pi`)
- Mounting shared skills (`~/.agents`)
- Forwarding necessary environment variables
- Setting correct UID/GID for file ownership

### Usage

```
./run-pi.sh [options] [prompt]

Options:
  -h, --help         Show help
  -u, --update      Rebuild Docker image, then run pi
  -i, --image IMAGE  Docker image (default: pi-agent:latest)
  --no-mount-pi      Don't mount ~/.pi configuration
  --verbose          Show docker commands
  --                 Pass through arguments to pi
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

Additional API keys supported: Azure OpenAI, AWS, Mistral, Groq, Cerebras, xAI, OpenRouter, HuggingFace, Kimi, MiniMax

## What's Mounted

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `$PWD` | `/workspace` | Your working directory (pi's cwd) |
| `~/.pi` | `/home/node/.pi` | Pi configuration (settings, themes, packages) |
| `~/.agents` | `/home/node/.agents` | Shared skills location |
| `~/.gitconfig` | `/home/node/.gitconfig` | Git configuration |
| `~/.ssh` | `/home/node/.ssh` | SSH keys (for git operations) |
| `~/.config/gh` | `/home/node/.config/gh` | GitHub CLI token |
| `/var/run/docker.sock` | `/var/run/docker.sock` | Docker socket (for host docker access) |

## Pi Configuration

Pi stores configuration in `~/.pi/agent/`. Key files:

| Path | Purpose |
|------|---------|
| `~/.pi/agent/settings.json` | Global settings |
| `~/.pi/agent/auth.json` | Authentication tokens |
| `~/.pi/agent/models.json` | Custom model configurations |
| `~/.pi/agent/sessions/` | Session history |
| `~/.pi/agent/extensions/` | Custom extensions |
| `~/.pi/agent/skills/` | Custom skills |
| `~/.pi/agent/themes/` | Custom themes |
| `~/.pi/agent/prompts/` | Prompt templates |

These are read from your host's `~/.pi` directory when you run the container.
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
- `@context7/mcp` - Context7 MCP server for documentation
- `lean-ctx init --agent pi` - Initialized for pi agent

## MCP Server Configuration

Pi now supports MCP (Model Context Protocol) servers via the pi-mcp-adapter. Configure MCP servers in `~/.pi/agent/mcp.json` on your host machine (mounted into the container).

### Example Configuration

Create `~/.pi/agent/mcp.json`:

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
      "command": "npx",
      "args": ["-y", "@context7/mcp"],
      "env": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      },
      "lifecycle": "lazy"
    }
  }
}
```

### Available MCP Servers

| Server | Purpose | Configuration |
|--------|---------|--------------|
| `lean-ctx` | Token-efficient context management (42 tools) | `command: "lean-ctx"` |
| `context7` | Up-to-date library documentation (9000+ libraries) | `npx -y @context7/mcp` (requires `CONTEXT7_API_KEY`) |

### Usage

Once configured, use MCP tools in Pi:

- `mcp({ search: "screenshot" })` — Search available tools
- `mcp({ describe: "ctx_read" })` — Describe a specific tool
- `mcp({ tool: "ctx_read", args: '{"path": "file.rs"}' })` — Call an MCP tool
- `/mcp` — Interactive MCP panel in Pi

Set your Context7 API key as an environment variable:

```bash
export CONTEXT7_API_KEY=your_api_key_here
```

The `run-pi.sh` script automatically forwards this variable into the container.

### Using a Custom Image

```bash
./run-pi.sh -i my-custom-pi "prompt"
```

Or set the environment variable:

```bash
PI_DOCKER_IMAGE=my-custom-pi ./run-pi.sh
```

## MCP Server Configuration

Pi supports MCP (Model Context Protocol) servers via the pi-mcp-adapter extension. Configure servers in `~/.pi/agent/mcp.json` on your host (mounted to the container).

### Pre-installed MCP Servers

The container includes:

| Server | Tools | Description |
|--------|-------|-------------|
| `lean-ctx` | 42 tools | Token-efficient context management, compression, and project intelligence |
| `context7` | 2 tools | Up-to-date documentation for 9000+ libraries |

### Configuration Example

Create `~/.pi/agent/mcp.json`:

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
      "command": "npx",
      "args": ["-y", "@context7/mcp"],
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

The `run-pi.sh` script forwards this automatically. Get your key at [context7.com/dashboard](https://context7.com/dashboard).

### Using MCP Tools

In Pi, interact with MCP servers:

- `mcp({ server: "lean-ctx" })` — Connect to lean-ctx
- `mcp({ search: "read file" })` — Search all tools (MCP + Pi)
- `mcp({ describe: "ctx_read" })` — Describe a specific tool
- `mcp({ tool: "ctx_read", args: '{"path": "src/main.rs", "mode": "full"}' })` — Call a tool
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