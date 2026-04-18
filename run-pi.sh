#!/usr/bin/env bash
set -euo pipefail

IMAGE="${PI_IMAGE:-pi-agent:overlay}"
WORKDIR="${PWD}"

args=(
  --rm
  -it
  --workdir /workspace
  --user node
  -v "${WORKDIR}:/workspace"
)

# Host Docker access
if [[ -S /var/run/docker.sock ]]; then
  args+=( -v /var/run/docker.sock:/var/run/docker.sock )
else
  echo "Warning: /var/run/docker.sock not found; Docker CLI in container won't reach host daemon." >&2
fi

# Optional config mounts (read-only)
if [[ -f "${HOME}/.gitconfig" ]]; then
  args+=( -v "${HOME}/.gitconfig:/home/node/.gitconfig:ro" )
fi

if [[ -d "${HOME}/.ssh" ]]; then
  args+=( -v "${HOME}/.ssh:/home/node/.ssh:ro" )
fi

if [[ -d "${HOME}/.config/gh" ]]; then
  args+=( -v "${HOME}/.config/gh:/home/node/.config/gh:ro" )
fi

# Forward common API key env vars if present
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
if [[ "$#" -gt 0 ]]; then
  exec docker run "${args[@]}" "${IMAGE}" "$@"
else
  exec docker run "${args[@]}" "${IMAGE}" pi
fi
