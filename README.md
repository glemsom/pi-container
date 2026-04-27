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

Copy `Dockerfile.overlay.example.dind` to `Dockerfile.overlay` and customize as needed.

NOTE: This example is using a DinD approach, but you can customize the overlay to fit your needs (e.g. add specific tools, set environment variables, etc.). 
      To reinstall the Pi Agent and extensions, you can remove the `~/.pi/.installed` marker file from the pi-agent-pi volume.

```bash
cp Dockerfile.overlay.example.dind Dockerfile.overlay
# Edit Dockerfile.overlay to add your packages and other needs
```

Build the overlay:

```bash
docker buildx build -t pi-agent:overlay -f Dockerfile.overlay . --load
```

### 4. Run the container (Example)
NOTE: Use `-v` for additional mounts, and `-e` to add environment variables as needed.


```bash
docker run --rm -it \
    --privileged \
    --network host \
    -v $(pwd):/workspace \
    -v pi-agent-pi:/home/node/.pi \
    -v pi-agent-local:/home/node/.local \
    -e CONTEXT7_API_KEY="$CONTEXT7_API_KEY" \
    pi-agent:overlay
```

On first run, the entrypoint will install the Pi Agent. Subsequent runs will skip installation.


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
