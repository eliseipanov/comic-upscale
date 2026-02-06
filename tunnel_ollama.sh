#!/bin/bash
# tunnel_ollama.sh - SSH tunnel to Ollama API
# Usage: ./tunnel_ollama.sh
# 
# Creates tunnel: localhost:11434 → server:11434
# Then use Ollama normally: ollama run deepseek-coder

source config.sh

echo "============================================== Ollama SSH Tunnel =============================================="
echo ""
echo "Server: $REMOTE_USER@$REMOTE_IP:$SSH_PORT"
echo "Local:  localhost:11434"
echo "Remote: localhost:11434"
echo ""
echo "Press Ctrl+C to stop tunnel"
echo ""

# Create SSH tunnel (run in background)
ssh -o StrictHostKeyChecking=no -p $SSH_PORT -N -L 11434:localhost:11434 "$REMOTE_USER@$REMOTE_IP"
