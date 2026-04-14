# Pi Container

Run the [Pi coding agent](https://pi.dev) inside an isolated Docker container, with your working directory and configuration properly mounted.

## Why Use a Container?

- **Isolation**: Pi runs in its own environment without polluting your host system
- **Consistency**: Same dependencies and Node.js version everywhere
- **Security**: Restrict what pi can access by controlling the container
- **Portability**: Works the same on any machine with Docker

## Quick Start

### 1. Build the Container

```bash
docker build -t pi-agent:latest .
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
- Running as your host UID/GID for correct file ownership and permissions

### Usage

```
./run-pi.sh [options] [prompt]

Options:
  -h, --help         Show help
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
| `PI_CODING_AGENT_DIR` | Override Pi config directory (default: `~/.pi/agent`) |

## What's Mounted

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `$PWD` | `/workspace` | Your working directory (pi's cwd) |
| `~/.pi` | `/home/node/.pi` | Pi configuration (settings, themes, packages) |
| `~/.agents` | `/home/node/.agents` | Shared skills location |
| `~/.gitconfig` | `/home/node/.gitconfig` | Git configuration |
| `~/.ssh` | `/home/node/.ssh` | SSH keys (for git operations) |

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

## Troubleshooting: `EACCES` in `/home/node/.pi/agent/...`

If you see errors like:

```text
EACCES: permission denied, mkdir '/home/node/.pi/agent/sessions/...'
```

it usually means your host `~/.pi` directory is owned by a different user than the one running `run-pi.sh`.

Fix ownership on the host:

```bash
sudo chown -R "$(id -u)":"$(id -g)" ~/.pi
```

## Customization

### Build a Custom Image

Edit the `Dockerfile` to add dependencies:

```dockerfile
FROM node:22-bookworm

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

### Using a Custom Image

```bash
./run-pi.sh -i my-custom-pi "prompt"
```

Or set the environment variable:

```bash
PI_DOCKER_IMAGE=my-custom-pi ./run-pi.sh
```

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

## Files

- `Dockerfile` - Docker image definition
- `run-pi.sh` - Wrapper script to run pi in a container

## See Also

- [Pi Documentation](https://pi.dev)
- [Pi GitHub](https://github.com/badlogic/pi-mono)
- [Pi Settings](docs/settings.md)
- [Pi Skills](docs/skills.md)
- [Pi Extensions](docs/extensions.md)
