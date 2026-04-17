#!/bin/bash
set -e

# Container entrypoint for pi-agent
# Handles MCP config bootstrap before starting pi

# Default MCP config source (built into the image)
DEFAULT_MCP_CONFIG="/etc/pi-mcp/default.json"
TARGET_MCP_CONFIG="/home/node/.pi/agent/mcp.json"

# Determine if we should use container's MCP config
USE_CONTAINER_MCP="${PI_USE_CONTAINER_MCP:-}"

# If forced or if target config doesn't exist, install container's default
if [[ -n "$USE_CONTAINER_MCP" ]] || [[ ! -f "$TARGET_MCP_CONFIG" ]]; then
  if [[ -f "$DEFAULT_MCP_CONFIG" ]]; then
    echo "Installing container MCP configuration..."
    mkdir -p "$(dirname "$TARGET_MCP_CONFIG")"
    cp "$DEFAULT_MCP_CONFIG" "$TARGET_MCP_CONFIG"
  fi
fi

# Check for project-specific MCP config in workspace
if [[ -f "/workspace/.pi/mcp.json" ]]; then
  echo "Found project-specific MCP config at /workspace/.pi/mcp.json"
  # Project config is automatically loaded by pi-mcp-adapter from workspace
fi

# Execute the main command (pi)
exec "$@"
