#!/usr/bin/env bash
set -euo pipefail

IMAGE="${PI_IMAGE:-pi-agent:overlay}"
WORKDIR="${PWD}"

# Toggles (empty means auto-detect based on existence of host dir)
use_host_pi="${PI_USE_HOST_PI:-}"
mount_docker_sock="${PI_MOUNT_DOCKER_SOCK:-true}"

# Arrays to collect docker run arguments
args=(
  --rm
  -it
  --workdir /workspace
  --user node
  -v "${WORKDIR}:/workspace"
)

# Additional docker flags passed via -e, -v, -w on command line
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--env)
      args+=( -e "$2" )
      shift 2
      ;;
    -v|--volume)
      args+=( -v "$2" )
      shift 2
      ;;
    -w|--workdir)
      args+=( -w "$2" )
      shift 2
      ;;
    --host-pi)
      use_host_pi="true"
      shift
      ;;
    --no-host-pi)
      use_host_pi="false"
      shift
      ;;
    --docker-sock)
      mount_docker_sock="true"
      shift
      ;;
    --no-docker-sock)
      mount_docker_sock="false"
      shift
      ;;
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      # Pass unknown flags through to docker run
      args+=( "$1" )
      shift
      ;;
    *)
      # Not a flag, stop parsing
      break
      ;;
  esac
done

# Remaining arguments are the container command
container_cmd=("$@")

# Host Docker access
if [[ "${mount_docker_sock}" == "true" ]] && [[ -S /var/run/docker.sock ]]; then
  args+=( -v /var/run/docker.sock:/var/run/docker.sock )

  # Match the socket's group inside the container so non-root user can access Docker.
  # This avoids needing to run the container as root.
  docker_sock_gid="$(stat -c '%g' /var/run/docker.sock)"
  if [[ -n "${docker_sock_gid}" ]]; then
    args+=( --group-add "${docker_sock_gid}" )
  fi
elif [[ "${mount_docker_sock}" == "true" ]]; then
  echo "Warning: /var/run/docker.sock not found; Docker CLI in container won't reach host daemon." >&2
fi

# Optional config mounts (read-only)
if [[ -f "${HOME}/.gitconfig" ]]; then
  args+=( -v "${HOME}/.gitconfig:/home/node/.gitconfig:ro" )
fi

if [[ -d "${HOME}/.ssh" ]]; then
  args+=( -v "${HOME}/.ssh:/home/node/.ssh:ro" )
fi

# Persist /home/node/.pi either by bind-mounting the host directory, or by
# creating a named Docker volume if the host doesn't have ~/.pi yet.
# Use --host-pi to force host ~/.pi, --no-host-pi to force Docker volume.
PI_HOME_DIR="${HOME}/.pi"
PI_HOME_VOLUME="${PI_HOME_VOLUME:-pi-agent-pi-home}"

if [[ "${use_host_pi}" == "true" ]]; then
  # Force use host ~/.pi (must exist)
  if [[ ! -d "${PI_HOME_DIR}" ]]; then
    echo "Error: --host-pi specified but ${PI_HOME_DIR} does not exist" >&2
    exit 1
  fi
  args+=( -v "${PI_HOME_DIR}:/home/node/.pi" )
elif [[ "${use_host_pi}" == "false" ]]; then
  # Force use Docker volume
  docker volume create "${PI_HOME_VOLUME}" >/dev/null
  args+=( -v "${PI_HOME_VOLUME}:/home/node/.pi" )
elif [[ -d "${PI_HOME_DIR}" ]]; then
  # Default: use host ~/.pi if it exists
  args+=( -v "${PI_HOME_DIR}:/home/node/.pi" )
else
  # No host ~/.pi, create/use Docker volume
  docker volume create "${PI_HOME_VOLUME}" >/dev/null
  args+=( -v "${PI_HOME_VOLUME}:/home/node/.pi" )
fi

if [[ -d "${HOME}/.config/gh" ]]; then
  args+=( -v "${HOME}/.config/gh:/home/node/.config/gh:ro" )
  # Inject GitHub token if gh is authenticated
  if command -v gh &>/dev/null && gh auth token &>/dev/null; then
    args+=( -e "GITHUB_TOKEN=$(gh auth token)" )
  fi
fi

# Forward common API key env vars if present (only from host env, not command line)
forward_env_vars=(
  OPENAI_API_KEY
  ANTHROPIC_API_KEY
  GOOGLE_API_KEY
  GEMINI_API_KEY
  XAI_API_KEY
  DEEPSEEK_API_KEY
  MISTRAL_API_KEY
  OPENROUTER_API_KEY
  GROQ_API_KEY
  PERPLEXITY_API_KEY
)

for name in "${forward_env_vars[@]}"; do
  if [[ -n "${!name:-}" ]]; then
    args+=( -e "${name}=${!name}" )
  fi
done

# Default command starts pi; pass any custom command/args through.
if [[ ${#container_cmd[@]} -gt 0 ]]; then
  exec docker run "${args[@]}" "${IMAGE}" "${container_cmd[@]}"
else
  exec docker run "${args[@]}" "${IMAGE}" pi
fi