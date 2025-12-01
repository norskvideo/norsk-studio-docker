#!/usr/bin/env bash
set -eo pipefail

# Thin wrapper for cloud deployment
# Sources cloud config and calls up.sh with appropriate flags

source "$(dirname "$0")/norsk-config.sh"
cd "$(dirname "$0")/.." || exit 1

# Calculate ICE servers with STUN fallback for cloud deployment
if [[ -n "${DEPLOY_PUBLIC_IP:-}" ]]; then
    # Generate TURN password if not exists
    TURN_PASSWORD_FILE="secrets/turn-password"
    if [[ ! -f "$TURN_PASSWORD_FILE" ]]; then
        mkdir -p secrets
        # Generate 32 character random password
        if command -v openssl > /dev/null 2>&1; then
            openssl rand -base64 24 > "$TURN_PASSWORD_FILE"
        else
            # Fallback: use /dev/urandom
            tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 > "$TURN_PASSWORD_FILE"
        fi
        echo "Generated TURN password in $TURN_PASSWORD_FILE"
    fi
    export TURN_PASSWORD=$(cat "$TURN_PASSWORD_FILE")

    ice_servers='[
  {"url": "turn:127.0.0.1:3478", "reportedUrl": "turn:'$DEPLOY_PUBLIC_IP':3478", "username": "norsk", "credential": "'$TURN_PASSWORD'"},
  {"url": "turn:127.0.0.1:3478", "reportedUrl": "turn:'$DEPLOY_PUBLIC_IP':3478?transport=tcp", "username": "norsk", "credential": "'$TURN_PASSWORD'"},
  {"url": "stun:127.0.0.1:3478", "reportedUrl": "stun:stun.l.google.com:19302"}
]'
else
    ice_servers=""
fi

# Extract hardware type from DEPLOY_HARDWARE path
hw_flag=""
if [[ -n "${DEPLOY_HARDWARE:-}" ]]; then
    if [[ "$DEPLOY_HARDWARE" == *"quadra"* ]]; then
        hw_flag="--enable-quadra"
    elif [[ "$DEPLOY_HARDWARE" == *"nvidia"* ]]; then
        hw_flag="--enable-nvidia"
    fi
fi

# Translate old interface: pull/up/down actions
action_flag=""
if [[ "${1:-}" == "pull" ]]; then
    action_flag="--pull-only"
    shift
elif [[ "${1:-}" == "up" ]]; then
    shift
elif [[ "${1:-}" == "down" ]]; then
    exec ./down.sh
fi

# Build up.sh arguments
args=(
    --network-mode host
    --public-url "${PUBLIC_URL_PREFIX:-https://$DEPLOY_HOSTNAME/norsk}"
    --studio-url "${STUDIO_URL_PREFIX:-https://$DEPLOY_HOSTNAME/studio}"
)

if [[ -n "$ice_servers" ]]; then
    args+=(--ice-servers "$ice_servers")
fi

if [[ -n "$hw_flag" ]]; then
    args+=($hw_flag)
fi

if [[ -n "$action_flag" ]]; then
    args+=($action_flag)
fi

# Call up.sh with cloud configuration
./up.sh "${args[@]}" "$@"
