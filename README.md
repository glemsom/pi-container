# Pi Agent Docker Container

Run the Pi Agent inside a Docker container with persistent volumes.

### 1. Build the base image (if not already built)

```bash
docker build -t pi-agent:base -f Dockerfile.base .
```

### 2. Create named volumes

```bash
docker volume create pi-agent-pi
docker volume create pi-agent-local
```

These volumes persist Pi Agent config and npm global packages across container restarts.

### 3. Build overlay image

There are two example overlays included:

- Dockerfile.overlay.example.dind — Docker-in-Docker (DinD) example that starts dockerd at container startup and uses an entrypoint script to perform first-run installation as the `node` user.
- Dockerfile.overlay.example.simple — Simple overlay that installs only the Pi agent at build time and runs entirely as the non-root `node` user (no entrypoint required).

Copy the example you prefer to `Dockerfile.overlay` and customize as needed.

For DinD (entrypoint-based first-run installation):

```bash
cp Dockerfile.overlay.example.dind Dockerfile.overlay
# Edit Dockerfile.overlay to add your packages and other needs
```

For the simple overlay (agent installed at build time):

```bash
cp Dockerfile.overlay.example.simple Dockerfile.overlay
# Edit Dockerfile.overlay if you want to install additional tools
```

Build the overlay:

```bash
docker buildx build -t pi-agent:overlay -f Dockerfile.overlay . --load
```

### 4. Run the container (Examples)
NOTE: Use `-v` for additional mounts, and `-e` to add environment variables as needed.

Below are two concrete `docker run` examples — one for each provided overlay. Pick the one that matches the overlay you copied to `Dockerfile.overlay` when building.

1) DinD overlay — Dockerfile.overlay.example.dind

Description: This overlay provides Docker-in-Docker (DinD) support. The image's entrypoint starts the Docker daemon (`dockerd`) as `root` at container startup, then drops privileges to the non-root `node` user to perform a first-run installation of the Pi Agent and run the agent. Use this when you need to build images or run containers from inside the Pi Agent.

Run (DinD requires privileged access):

```bash
docker run --rm -it \
    --privileged \
    --network host \
    -v $(pwd):/workspace \
    -v pi-agent-pi:/home/node/.pi \
    -v pi-agent-local:/home/node/.local \
    -e CONTEXT7_API_KEY="$CONTEXT7_API_KEY" \
    -e LEAN_CTX_DATA_DIR="/home/node/.pi/lean-ctx" \
    pi-agent:overlay
```

Notes: On first run the DinD overlay's entrypoint will install the Pi Agent as the `node` user (a marker file prevents repeated installs). `--privileged` is typically required for DinD so `dockerd` can access necessary kernel features.

2) Simple overlay — Dockerfile.overlay.example.simple

Description: This overlay is a minimal example that installs the Pi Agent at build time and runs entirely as the non-root `node` user. It does not start `dockerd` and does not require privileged mode. Use this when you only need the Pi Agent and don't need Docker-in-Docker capabilities or extra extensions.


```bash
docker run --rm -it \
    -v $(pwd):/workspace \
    -e CONTEXT7_API_KEY="$CONTEXT7_API_KEY" \
    pi-agent:overlay
```

Notes: The simple overlay installs the Pi Agent at build time, so containers from that overlay start immediately without a first-run install step. Add `-v` and `-e` flags as needed to mount additional files or provide environment variables.

## Volumes

- `pi-agent-pi` - Persistent storage for Pi Agent config (`/home/node/.pi`)
- `pi-agent-local` - Persistent storage for npm global packages (`/home/node/.local`)

## Entrypoint Script (`entrypoint.sh`) (In Dockerfile.overlay.example.dind)

The overlay uses an `entrypoint.sh` script to handle privilege separation and proper initialization:

- **Docker-in-Docker (DinD):** The script starts the Docker daemon (`dockerd`) as `root` to provide DinD capabilities inside the container.
- **Privilege drop:** After starting `dockerd`, the script switches to the non-root `node` user to install and run the Pi Agent and its extensions.
- This ensures:
  - DinD features are available (daemon runs as `root`).
  - The Pi Agent and extensions run as the `node` user, following security best practices.
  - The `node` user, as a member of the `docker` group, can manage Docker without `sudo`.

You can find and customize `entrypoint.sh` in the project. This logic is defined in `Dockerfile.overlay.example.dind`, but you may adjust it for your requirements.

## Docker In Docker (DinD)

The overlay image includes DinD support by default. The entrypoint starts `dockerd` inside the container before launching the Pi Agent, so you can build images and run containers from within the Pi Agent.

The container starts the Docker daemon as root (required) and then drops privileges to the non-root `node` user for the Pi Agent. The `node` user is a member of the `docker` group, so it can access the Docker socket and run Docker commands without sudo.

> **Note:** DinD requires `--privileged` to access the kernel features needed by `dockerd` (cgroups, device access, namespaces).
