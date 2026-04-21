# Pi Agent Docker Container

Run the Pi Agent inside a Docker container with persistent volumes.

## Quick Start

```bash
# Oneline rebuild all and run
cp Dockerfile.overlay.example Dockerfile.overlay; docker volume rm pi-agent-pi pi-agent-local 2>/dev/null; docker volume create pi-agent-pi && docker volume create pi-agent-local; docker buildx build -t pi-agent:overlay -f Dockerfile.overlay . --load && docker run --rm -it --network host -v pi-agent-pi:/home/node/.pi -v pi-agent-local:/home/node/.local pi-agent:overlay

```

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
# Edit Dockerfile.overlay to add your packages
```

Build the overlay:

```bash
docker buildx build -t pi-agent:overlay -f Dockerfile.overlay . --load
```

### 4. Run the container

```bash
docker run --rm -it \
    --network host \
    -v pi-agent-pi:/home/node/.pi \
    -v pi-agent-local:/home/node/.local \
    pi-agent:overlay
```

On first run, the entrypoint will install the Pi Agent. Subsequent runs will skip installation.

## Volumes

- `pi-agent-pi` - Persistent storage for Pi Agent config (`/home/node/.pi`)
- `pi-agent-local` - Persistent storage for npm global packages (`/home/node/.local`)

## Network

The container uses `--network host` for direct host network access.

## Developing the Overlay

1. Edit `Dockerfile.overlay` to add OS packages and in the ENTRYPOINT section add additional Pi agent packages
2. Rebuild: `docker build -t pi-agent:overlay -f Dockerfile.overlay .`
3. Run: same as step 4 above