#!/usr/bin/env bash
source "$(dirname "$0")/norsk-config.sh"
source "$(dirname "$0")/versions"
cd "$(dirname "$0")/.." || exit 1

export PUBLIC_URL_PREFIX=${PUBLIC_URL_PREFIX:-https://$DEPLOY_HOSTNAME/norsk}
export STUDIO_URL_PREFIX=${STUDIO_URL_PREFIX:-/studio}
export STUDIO_DOCS_URL=${STUDIO_DOCS_URL:-https://$DEPLOY_HOSTNAME/docs/studio/latest/index.html}
if [[ -z "${NORSK_USER:-}" ]]; then
  # These need to be set as ids because they are
  # names on the host system, not inside the container
  export NORSK_USER=$(id -u norsk 2>/dev/null)

  if [[ -z "${NORSK_GROUP:-}" && -n "$NORSK_USER" ]]; then
    # Prefer the disk group if norsk is a member
    # (For hardware access, e.g. Netint Quadra)
    if id -nG norsk | grep -qw disk; then
      export NORSK_GROUP=$(getent group disk | cut -d: -f3)
    else
      # Otherwise the default group (aka norsk)
      export NORSK_GROUP=$(id -g norsk)
    fi
  fi
fi

# Set up configuration for coturn
# TODO: configure hostIps (Norsk), external-ip (coturn)?
# TODO: secure turns:/stuns:?
if [[ -z "${GLOBAL_ICE_SERVERS:-}" && -n "${DEPLOY_PUBLIC_IP:-}" ]]; then
  # Include the public Google STUN server as a fallback in case
  # port 3478 is firewalled off...
  export GLOBAL_ICE_SERVERS='[{ "url": "turn:127.0.0.1:3478", "reportedUrl": "turn:'$DEPLOY_PUBLIC_IP':3478", "username": "norsk", "credential": "norsk" }, { "url": "turn:127.0.0.1:3478", "reportedUrl": "turn:'$DEPLOY_PUBLIC_IP':3478?transport=tcp", "username": "norsk", "credential": "norsk" }, { "url": "stun:127.0.0.1:3478", "reportedUrl": "stun:stun.l.google.com:19302" }]'
fi

if [[ "${1:-}" = "up" || "${1:-}" = "start" ]]; then
  bash ./deployed/check-setup.sh
fi

networkDir="networking/host"

declare -a composeFiles
composeFiles=(
  -f yaml/servers/norsk-media.yaml -f yaml/$networkDir/norsk-media.yaml
  -f yaml/servers/norsk-studio.yaml -f yaml/$networkDir/norsk-studio.yaml
  -f yaml/servers/turn.yaml -f yaml/$networkDir/turn.yaml
  -f yaml/norsk-users.yaml
  -f yaml/volumes/norsk-logs.yaml
)
if [[ -n "${DEPLOY_HARDWARE:-}" ]]; then
  composeFiles+=(
    -f "$DEPLOY_HARDWARE"
  )
fi

docker compose "${composeFiles[@]}" "$@"
