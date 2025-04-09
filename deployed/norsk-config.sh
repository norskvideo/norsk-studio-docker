#!/usr/bin/env bash
export DEPLOY_PLATFORM="$("$(dirname "$BASH_SOURCE")/detect.sh")"
export DEPLOY_LOGS="$(realpath "$(dirname "$BASH_SOURCE")/../logs")"
source "$(dirname "$BASH_SOURCE")/$DEPLOY_PLATFORM/$(basename "$BASH_SOURCE")"
