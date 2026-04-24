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

Copy `Dockerfile.overlay.example` to `Dockerfile.overlay` and customize as needed:

```bash
cp Dockerfile.overlay.example Dockerfile.overlay
# Edit Dockerfile.overlay to add your packages and other needs
```

Build the overlay:

```bash
docker buildx build -t pi-agent:overlay -f Dockerfile.overlay . --load
```

### 4. Run the container (Example)

```bash
docker run --rm -it \
    --privileged \
    --network host \
    -v pi-agent-pi:/home/node/.pi \
    -v pi-agent-local:/home/node/.local \
    -e CONTEXT7_API_KEY="$CONTEXT7_API_KEY" \
    pi-agent:overlay
```

On first run, the entrypoint will install the Pi Agent. Subsequent runs will skip installation.


## Volumes

- `pi-agent-pi` - Persistent storage for Pi Agent config (`/home/node/.pi`)
- `pi-agent-local` - Persistent storage for npm global packages (`/home/node/.local`)

## Docker In Docker (DinD)

The overlay image includes DinD support by default. The entrypoint starts `dockerd` inside the container before launching the Pi Agent, so you can build images and run containers from within the Pi Agent.

The container starts the Docker daemon as root (required) and then drops privileges to the non-root `node` user for the Pi Agent. The `node` user is a member of the `docker` group, so it can access the Docker socket and run Docker commands without sudo.

> **Note:** DinD requires `--privileged` to access the kernel features needed by `dockerd` (cgroups, device access, namespaces).

```bash
docker run --rm -it \
    --privileged \
    --network host \
    -v pi-agent-pi:/home/node/.pi \
    -v pi-agent-local:/home/node/.local \
    -v $(pwd):/workspace \
    -v $(HOME)/.gitconfig:/home/node/.gitconfig:ro \
    -e CONTEXT7_API_KEY="$CONTEXT7_API_KEY" \
    pi-agent:overlay
```


## Network

The container uses `--network host` for direct host network access.S