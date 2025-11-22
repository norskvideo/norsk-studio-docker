#!/usr/bin/env bash
# Shared functions for Norsk Studio scripts
# NOTE: Similar functions exist in scripts/install (must be self-contained)
#       If you update here, consider updating there too.

oops() {
    echo "$0:" "$@" >&2
    exit 1
}

# HTTP fetch wrapper - curl or wget
if command -v curl > /dev/null 2>&1; then
    fetch() { curl --silent --fail -L "$1" -o "$2"; }
    fetch_json() { curl -s "$1"; }
elif command -v wget > /dev/null 2>&1; then
    fetch() { wget --quiet "$1" -O "$2"; }
    fetch_json() { wget -qO- "$1"; }
else
    fetch() { oops "need curl or wget"; }
    fetch_json() { oops "need curl or wget"; }
fi

# Docker pull wrapper
pull() {
    DOCKER_CLI_HINTS=false docker pull "$1"
}

# Container versions file
VERSIONS_FILE="versions"

# Get configured container versions
get_container_config() {
    local script_dir="${1:-.}"

    if [[ -f "$script_dir/$VERSIONS_FILE" ]]; then
        source "$script_dir/$VERSIONS_FILE"
    else
        echo "Error: $VERSIONS_FILE not found" >&2
        exit 1
    fi
}

# List available tags from Docker Hub (multi-arch only)
list_docker_tags() {
    local repo="$1"
    local limit="${2:-20}"
    local url="https://hub.docker.com/v2/repositories/norskvideo/$repo/tags?page_size=$limit&ordering=last_updated"

    fetch_json "$url" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//' | grep -v '^latest$' | grep -v '^nightly$' | grep -v '\-arm64$' | grep -v '\-amd64$'
}
