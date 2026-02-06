#!/bin/bash
# tunnel_flask.sh - SSH tunnel to access Flask UI locally
# Usage: ./tunnel_flask.sh [local_port]

set -e

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
fi

LOCAL_PORT="${1:-5800}"

echo "Creating SSH tunnel to Flask UI..."
echo "Local:  http://0.0.0.0:$LOCAL_PORT"
echo "Remote: $REMOTE_USER@$REMOTE_IP:$SSH_PORT"
echo ""
echo "Press Ctrl+C to stop the tunnel"
echo ""

# Create tunnel (blocking)
ssh -o StrictHostKeyChecking=no -p $SSH_PORT -L $LOCAL_PORT:localhost:5800 $REMOTE_USER@$REMOTE_IP
