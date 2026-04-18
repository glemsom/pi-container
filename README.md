# Pi Container

Docker-based environment for running the Pi coding agent in an isolated container.

## Files

- `Dockerfile.base` – Base image with Node.js 25, Pi agent, and Docker CLI
- `Dockerfile.overlay` – Example user overlay with common dev tools and GitHub CLI
- `run-pi.sh` – Wrapper script to run the container with useful mounts and env forwarding

## Build Images

### 1) Build base image

```bash
docker build -f Dockerfile.base -t pi-agent:base .
```

### 2) Build overlay image

Edit the `FROM` line in `Dockerfile.overlay` if needed.

Example:

```Dockerfile
FROM pi-agent:base
```

Then build:

```bash
docker build -f Dockerfile.overlay -t pi-agent:overlay .
```

## Run

Use the wrapper script:

```bash
./run-pi.sh
```

By default, this runs `pi` inside the container.

To run a custom command:

```bash
./run-pi.sh bash
./run-pi.sh pi --help
```

Use a different image tag:

```bash
PI_IMAGE=my-custom-image:tag ./run-pi.sh
```

## Mounts and Runtime Behavior

`run-pi.sh` configures these mounts:

- `$PWD` → `/workspace` (read-write)
- `/var/run/docker.sock` → `/var/run/docker.sock` (if present)
- `~/.gitconfig` → `/home/node/.gitconfig` (read-only, if present)
- `~/.ssh` → `/home/node/.ssh` (read-only, if present)
- `~/.config/gh` → `/home/node/.config/gh` (read-only, if present)

This allows the container to:

- Work directly on your current project directory
- Use host Docker daemon via socket mount
- Reuse git, SSH, and GitHub CLI configuration

## Environment Variables

The wrapper forwards these variables when set:

- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GOOGLE_API_KEY`
- `GEMINI_API_KEY`
- `XAI_API_KEY`
- `DEEPSEEK_API_KEY`
- `MISTRAL_API_KEY`
- `OPENROUTER_API_KEY`
- `GROQ_API_KEY`
- `PERPLEXITY_API_KEY`

## Notes

- `Dockerfile.overlay` is an example layer you can customize with your own tools.
- If `/var/run/docker.sock` is missing, Docker commands in the container cannot access the host daemon.
- The images use the existing `node` user (UID 1000) from `node:25-bookworm-slim`.
