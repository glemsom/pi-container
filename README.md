# Pi Container

Docker-based environment for running the Pi coding agent in an isolated container.

## Build Images

### 1) Build base image

```bash
docker build -f Dockerfile.base -t pi-agent:base .
```

The base image includes:
- Node.js 25 (bookworm)
- `fd` binary v10.4.2 (file discovery for Pi agent)
- Pi coding agent (`@mariozechner/pi-coding-agent`)

### 2) Build overlay image

Copy the example overlay file to `Dockerfile.overlay`:

```bash
cp Dockerfile.overlay.example Dockerfile.overlay
```

Then build the image:

```bash
docker build -f Dockerfile.overlay -t pi-agent:overlay .
```

The overlay image adds:
- Docker CLI v29.4.0
- Development tools: git, gpg, openssh-client, ripgrep
- GitHub CLI (`gh`)
- Pi Context plugin (`pi install npm:pi-context`)
- lean-ctx and pi-lean-ctx for context management
- Context7 extension (`@dreki-gg/pi-context7`)
- Kilo Gateway extension

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

### Options

| Flag | Description |
|------|-------------|
| `--image <tag>` | Use a different image tag (default: `pi-agent:overlay`) |
| `--host-pi` | Use host `~/.pi` directory (must exist) |
| `--no-host-pi` | Use Docker volume for `~/.pi` instead of host directory |
| `--docker-sock` | Mount Docker socket (default) |
| `--no-docker-sock` | Don't mount Docker socket |
| `-e <var>` | Pass environment variable into container |
| `-v <mount>` | Add volume mount (e.g., `-v /host/path:/container/path`) |
| `-w <dir>` | Set working directory inside container |

Alternatively, set these env vars:

```bash
PI_IMAGE=my-custom-image:tag ./run-pi.sh
PI_USE_HOST_PI=true ./run-pi.sh     # Force use host ~/.pi
PI_MOUNT_DOCKER_SOCK=false ./run-pi.sh  # Disable Docker socket mount
```

### Mounts and Runtime Behavior

`run-pi.sh` configures these mounts:

- `$PWD` → `/workspace` (read-write)
- `/var/run/docker.sock` → `/var/run/docker.sock` (if present, can be disabled with `--no-docker-sock`)
- `~/.gitconfig` → `/home/node/.gitconfig` (read-only, if present)
- `~/.ssh` → `/home/node/.ssh` (read-only, if present)
- `~/.pi` → `/home/node/.pi` (bind-mounted if present; use `--host-pi` or `--no-host-pi` to override)
- `~/.config/gh` → `/home/node/.config/gh` (read-only, if present)

This allows the container to:

- Work directly on your current project directory
- Use host Docker daemon via socket mount
- Access Docker as non-root (`node`) by adding the socket GID as a supplemental group
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

### Adding Extra Environment Variables

To pass additional environment variables from the host to the container, use the `-e` flag:

```bash
./run-pi.sh -e MY_VAR=value -e ANOTHER_VAR=value
```


Note: Variables must be passed **after** the script name but **before** any command arguments.

### Example: Custom API Token

The example below passes a custom `KILO_API_TOKEN`:

```bash
./run-pi.sh \
  -e KILO_API_TOKEN="your-token-here"
```

Or with an explicit pi command:

```bash
KILO_API_TOKEN=your-token-here ./run-pi.sh \
  -e KILO_API_TOKEN="${KILO_API_TOKEN}" \
  pi --model sonnet
```

- `KILO_API_TOKEN` is forwarded into the container as an environment variable.

### GitHub CLI Authentication

If `gh` is authenticated on the host, the GitHub token is automatically injected into the container as `GITHUB_TOKEN`.

## Notes

- `Dockerfile.overlay` is an example layer you can customize with your own tools.
- If `/var/run/docker.sock` is missing, Docker commands in the container cannot access the host daemon.
- The images use the non-root `node` user (UID 1000) from `node:25-bookworm`.
- lean-ctx is pre-initialized in the overlay image for efficient context management.
- The Kilo Gateway extension (`extensions/kilo-gateway.ts`) is included in the overlay.
- The Context7 extension provides documentation lookup capabilities.
