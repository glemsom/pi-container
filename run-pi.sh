#!/usr/bin/env bash
#
# pi-container - Run Pi agent inside a container
#
# Usage:
#   pi-container                    # Start interactive pi in current directory
#   pi-container "Your prompt"      # Run pi with a prompt and exit
#   pi-container --help             # Show help
#
# Environment Variables:
#   PI_DOCKER_IMAGE   - Override default container image (default: pi-agent:latest)
#   PI_API_KEY        - Set API key (alternatively use ANTHROPIC_API_KEY, OPENAI_API_KEY, etc.)
#
# Mounts:
#   - Current working directory -> /workspace (current dir of pi)
#   - ~/.pi                      -> /home/node/.pi (pi configuration)
#   - ~/.agents                  -> /home/node/.agents (shared skills location)
#   - Note: ~/.npmrc is NOT mounted - host config often has paths that break in container
#

set -e

# Configuration
IMAGE="${PI_DOCKER_IMAGE:-pi-agent:latest}"
CONTAINER_NAME="pi-agent-$$"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $(basename "$0") [options] [prompt]

Run Pi agent inside an isolated container with your working directory mounted.

Arguments:
    prompt              Optional initial prompt to send to pi

 Options:
      -h, --help         Show this help message
      -u, --update        Rebuild Docker image, then run pi
      -i, --image IMAGE  Docker image to use (default: pi-agent:latest)
      --no-mount-pi      Don't mount ~/.pi extensions/skills/themes/prompts (full isolation)
      --no-mcp-host-config  Reset MCP config to container defaults (overwrite any existing)
      --verbose          Show docker commands being executed
      --                 Pass through arguments to pi

Examples:
    $(basename "$0")                                    # Interactive mode
    $(basename "$0") "List files in src/"               # Run with prompt
    $(basename "$0") --update                            # Rebuild image, then run
    pi-container -i my-custom-image "Hello"             # Custom image
    PI_API_KEY=sk-ant-... $(basename "$0") "Hello"       # Set API key
EOF
    exit "${1:-0}"
}

# Parse arguments
MOUNT_PI=true
VERBOSE=false
REBUILD=false
PI_ARGS=()
NO_MCP_HOST_CONFIG=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage 0
            ;;
        -i|--image)
            IMAGE="$2"
            shift 2
            ;;
        --no-mount-pi)
            MOUNT_PI=false
            shift
            ;;
        --no-mcp-host-config)
            NO_MCP_HOST_CONFIG=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -u|--update)
            REBUILD=true
            shift
            ;;
        --)
            shift
            PI_ARGS+=("$@")
            break
            ;;
        -*)
            echo -e "${RED}Error: Unknown option: $1${NC}" >&2
            usage 1
            ;;
        *)
            PI_ARGS+=("$1")
            shift
            ;;
    esac
done

# Rebuild image if requested
if [[ "$REBUILD" == "true" ]]; then
    echo -e "${GREEN}Rebuilding Docker image...${NC}"
    # Get the directory where this script is located (resolve symlinks to get actual script location)
    SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
    docker build -t pi-agent:latest "$SCRIPT_DIR"
    echo -e "${GREEN}Image rebuilt successfully!${NC}"
fi

# Get current user info for correct UID/GID in container
USER_UID=$(id -u)
USER_GID=$(id -g)
USER_NAME=$(whoami)
USER_HOME="$HOME"

# Detect the docker socket GID from the host (socket is owned by root:GID)
DOCKER_SOCKET_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "")

# Build docker run arguments
DOCKER_ARGS=(
    --rm
    --interactive
    --tty
    --name "$CONTAINER_NAME"
    --user 1000:1000
    --group-add "$DOCKER_SOCKET_GID"
    --env "USER=$USER_NAME"
    --env "HOME=/home/node"
    --env "PI_CODING_AGENT_DIR=/home/node/.pi/agent"
    --workdir /workspace
    --network host
)

# Forward relevant environment variables
for env_var in \
    PI_CODING_AGENT_DIR \
    PI_PACKAGE_DIR \
    PI_SKIP_VERSION_CHECK \
    PI_CACHE_RETENTION \
    PI_SHARE_VIEWER_URL \
    PI_USE_CONTAINER_MCP \
    ANTHROPIC_API_KEY \
    ANTHROPIC_API_KEY_FILE \
    OPENAI_API_KEY \
    OPENAI_API_KEY_FILE \
    GOOGLE_API_KEY \
    VERTEX_PROJECT \
    VERTEX_LOCATION \
    AZURE_OPENAI_API_KEY \
    AWS_ACCESS_KEY_ID \
    AWS_SECRET_ACCESS_KEY \
    AWS_DEFAULT_REGION \
    MISTRAL_API_KEY \
    GROQ_API_KEY \
    CEREBRAS_API_KEY \
    XAI_API_KEY \
    OPENROUTER_API_KEY \
    CONTEXT7_API_KEY \
    HF_TOKEN \
    GH_TOKEN \
    GITHUB_TOKEN \
    KIMI_API_KEY \
    MINIMAX_API_KEY \
    KILO_API_TOKEN; do
    if [[ -n "${!env_var}" ]]; then
        DOCKER_ARGS+=(--env "$env_var=${!env_var}")
    fi
done

# If GH_TOKEN not set, try to extract it from HOST gh config using host gh
# (gh stores token in keyring on host, which isn't accessible in container)
# We use 'command -v' from the host to check for gh, not a docker container
if [[ -z "$GH_TOKEN" ]] && command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
        GH_TOKEN=$(gh auth token 2>/dev/null)
        if [[ -n "$GH_TOKEN" ]]; then
            DOCKER_ARGS+=(--env "GH_TOKEN=$GH_TOKEN")
        fi
    fi
fi

# If requested, use container's MCP config instead of host's
if [[ "$NO_MCP_HOST_CONFIG" == "true" ]]; then
    DOCKER_ARGS+=(--env "PI_USE_CONTAINER_MCP=true")
fi

# Mount current working directory
HOST_CWD="$(pwd)"
DOCKER_ARGS+=(-v "$HOST_CWD:/workspace")

# Mount Docker socket for host docker access
DOCKER_ARGS+=(-v "/var/run/docker.sock:/var/run/docker.sock")

# Recursively find and mount symlinks in a directory
# Args: $1=host_path $2=container_path
# Returns: adds -v arguments for symlinks to DOCKER_ARGS array
collect_symlink_mounts() {
    local host_path="$1"
    local container_path="$2"
    
    for item in "$host_path"/*; do
        [[ -e "$item" ]] || continue
        local item_name=$(basename "$item")
        local container_item="$container_path/$item_name"
        
        if [[ -L "$item" ]]; then
            # Symlink: resolve target and mount it
            local target=$(readlink -f "$item")
            if [[ -d "$target" ]]; then
                DOCKER_ARGS+=(-v "$target:$container_item")
                collect_symlink_mounts "$target" "$container_item"
            elif [[ -f "$target" ]]; then
                DOCKER_ARGS+=(-v "$target:$container_item")
            fi
        elif [[ -d "$item" ]]; then
            # Regular directory: recurse to find nested symlinks
            collect_symlink_mounts "$item" "$container_item"
        fi
        # Regular files don't need special handling
    done
}

# Mount pi configuration directories selectively
# Only mount user extensions, skills, themes, and prompts.
# MCP config is container-managed to ensure lean-ctx and context7 are available.
if [[ "$MOUNT_PI" == "true" ]]; then
    # Mount individual agent subdirectories (not the entire ~/.pi to avoid overriding container MCP config)
    local pi_agent_dir="$USER_HOME/.pi/agent"
    
    # extensions — Pi extensions/plugins
    if [[ -d "$pi_agent_dir/extensions" ]]; then
        DOCKER_ARGS+=(-v "$pi_agent_dir/extensions:/home/node/.pi/agent/extensions:ro")
        collect_symlink_mounts "$pi_agent_dir/extensions" "/home/node/.pi/agent/extensions"
    fi
    
    # skills — Custom Pi skills
    if [[ -d "$pi_agent_dir/skills" ]]; then
        DOCKER_ARGS+=(-v "$pi_agent_dir/skills:/home/node/.pi/agent/skills:ro")
        collect_symlink_mounts "$pi_agent_dir/skills" "/home/node/.pi/agent/skills"
    fi
    
    # themes — Pi UI themes
    if [[ -d "$pi_agent_dir/themes" ]]; then
        DOCKER_ARGS+=(-v "$pi_agent_dir/themes:/home/node/.pi/agent/themes:ro")
        collect_symlink_mounts "$pi_agent_dir/themes" "/home/node/.pi/agent/themes"
    fi
    
    # prompts — Custom prompt templates
    if [[ -d "$pi_agent_dir/prompts" ]]; then
        DOCKER_ARGS+=(-v "$pi_agent_dir/prompts:/home/node/.pi/agent/prompts:ro")
        collect_symlink_mounts "$pi_agent_dir/prompts" "/home/node/.pi/agent/prompts"
    fi

    # ~/.agents -> /home/node/.agents (shared skills location)
    if [[ -d "$USER_HOME/.agents" ]]; then
        DOCKER_ARGS+=(-v "$USER_HOME/.agents:/home/node/.agents:ro")
    fi

    # ~/.gitconfig -> /home/node/.gitconfig
    if [[ -f "$USER_HOME/.gitconfig" ]]; then
        DOCKER_ARGS+=(-v "$USER_HOME/.gitconfig:/home/node/.gitconfig:ro")
    fi

    # ~/.ssh -> /home/node/.ssh (for git operations)
    if [[ -d "$USER_HOME/.ssh" ]]; then
        DOCKER_ARGS+=(-v "$USER_HOME/.ssh:/home/node/.ssh:ro")
    fi

    # ~/.config/gh -> /home/node/.config/gh (GitHub CLI token)
    if [[ -d "$USER_HOME/.config/gh" ]]; then
        DOCKER_ARGS+=(-v "$USER_HOME/.config/gh:/home/node/.config/gh:ro")
    fi
fi

# Show docker command if verbose
if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${GREEN}Running:${NC} docker run $IMAGE bash -l -c pi ${PI_ARGS[*]}" >&2
    echo -e "${GREEN}Docker args:${NC} ${DOCKER_ARGS[*]}" >&2
fi

# Run pi in container through bash (login shell to source ~/.bashrc for leanctx aliases)
# First run lean-ctx doctor to verify lean-ctx is healthy, then start dashboard in background and run pi
exec docker run "${DOCKER_ARGS[@]}" "$IMAGE" bash -l -c "pi ${PI_ARGS[*]}"