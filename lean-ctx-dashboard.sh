#!/usr/bin/env bash
#
# lean-ctx-dashboard.sh - Manage lean-ctx dashboard container
#
# Usage:
#   lean-ctx-dashboard.sh start   # Start the dashboard container
#   lean-ctx-dashboard.sh stop    # Stop the dashboard container
#   lean-ctx-dashboard.sh status  # Check if dashboard is running
#   lean-ctx-dashboard.sh restart # Restart the dashboard container

set -e

CONTAINER_NAME="lean-ctx-dashboard"
IMAGE="${PI_DOCKER_IMAGE:-pi-agent:latest}"
USER_HOME="$HOME"

# Check if container is running
is_running() {
    docker ps --filter "name=$CONTAINER_NAME" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Start the dashboard container
start() {
    if is_running; then
        echo "lean-ctx dashboard container is already running"
        return 0
    fi

    echo "Starting lean-ctx dashboard container..."

    # Remove any existing stopped container with the same name
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

    # Start the dashboard container
    # - Mount ~/.lean-ctx from host for data persistence
    # - Use host network (--network host)
    # - Expose port 3333
    # - Run with --host=0.0.0.0 for dashboard binding
    docker run -d \
        --name "$CONTAINER_NAME" \
        --network host \
        -v "$USER_HOME/.lean-ctx:/home/node/.lean-ctx" \
        "$IMAGE" \
        lean-ctx dashboard --host=0.0.0.0

    echo "lean-ctx dashboard started on port 3333"
}

# Stop the dashboard container
stop() {
    if is_running; then
        echo "Stopping lean-ctx dashboard container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
    else
        echo "lean-ctx dashboard container is not running"
    fi
}

# Show status
status() {
    if is_running; then
        echo "lean-ctx dashboard is running"
        docker ps --filter "name=$CONTAINER_NAME" --format "  {{.Status}}"
    else
        echo "lean-ctx dashboard is not running"
    fi
}

# Restart the dashboard container
restart() {
    stop
    start
}

# Main
case "${1:-status}" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        restart
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac