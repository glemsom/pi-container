#!/bin/bash
# check-updates.sh - Check for newer versions of packages in Dockerfile
# Run this periodically to detect when updates are available

set -e

echo "========================================"
echo "Checking for package updates..."
echo "========================================"

# --- npm packages ---
echo ""
echo "=== npm packages ==="

npm_packages=(
    "@mariozechner/pi-coding-agent"
    "lean-ctx-bin"
    "@mjakl/pi-subagent"
    "@upstash/context7-mcp"
    "ctx7"
)

current_npm_versions=(
    "0.67.6"
    "3.2.2"
    "1.4.1"
    "2.1.8"
    "0.3.13"
)

for i in "${!npm_packages[@]}"; do
    pkg="${npm_packages[$i]}"
    current="${current_npm_versions[$i]}"
    latest=$(npm view "$pkg" version 2>/dev/null || echo "N/A")
    if [ "$latest" != "N/A" ] && [ "$latest" != "$current" ]; then
        echo "🔔 $pkg: $current -> $latest (UPDATE AVAILABLE)"
    else
        echo "✓ $pkg: $current (up to date)"
    fi
done

# --- apt packages ---
echo ""
echo "=== apt packages ==="

apt_packages=(
    "dumb-init"
    "curl"
    "git"
    "ripgrep"
)

echo "📦 apt packages: versions depend on Debian bookworm base image"
echo "   (run 'apt list --upgradable' inside container to check)"

# --- GitHub CLI (gh) ---
echo ""
echo "=== GitHub CLI (gh) ==="

gh_latest=$(curl -s https://api.github.com/repos/cli/cli/releases/latest 2>/dev/null | grep -o '"tag_name": "v\([^"]*\)"' | cut -d'"' -f4 || echo "N/A")
echo "🔖 gh: latest stable release is $gh_latest"

# --- Docker CLI ---
echo ""
echo "=== Docker CLI ==="

docker_latest=$(curl -s https://download.docker.com/linux/static/stable/x86_64/ 2>/dev/null | grep -oP 'docker-\K[0-9]+\.[0-9]+\.[0-9]+(?=\.tgz)' | sort -V | tail -1 || echo "N/A")
echo "🐳 Docker CLI: latest stable is $docker_latest (current Dockerfile uses 29.4.0)"

echo ""
echo "========================================"
echo "Check complete!"
echo "========================================"
echo ""
echo "To update packages in Dockerfile:"
echo "  - npm: change version in 'npm install -g' commands"
echo "  - apt: versions depend on Debian bookworm base"
echo "  - gh: update the apt-get install gh command or use static binary"
echo "  - Docker CLI: update the download URL version in Dockerfile"
echo ""