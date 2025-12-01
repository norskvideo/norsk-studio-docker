#!/usr/bin/env bash

# Platform configuration setup
# Sourced by bootstrap.sh

setup_platform() {
  local repo_dir="$INSTALL_DIR/norsk-studio-docker"

  # Auto-detect platform if not specified
  if [[ -z "$PLATFORM" ]]; then
    if [[ -f /sys/class/dmi/id/bios_vendor ]]; then
      local vendor="$(cat /sys/class/dmi/id/bios_vendor)"
      case "$vendor" in
        Google)
          PLATFORM="google"
          ;;
        Linode)
          PLATFORM="linode"
          ;;
        *)
          PLATFORM="local"
          ;;
      esac
    else
      PLATFORM="local"
    fi
    echo "Auto-detected platform: $PLATFORM"
  fi

  # Validate platform
  if [[ ! "$PLATFORM" =~ ^(linode|google|oracle|local)$ ]]; then
    echo "Error: Platform must be one of: linode, google, oracle, local" >&2
    exit 1
  fi

  # Source platform-specific module
  local platform_script="$SCRIPT_DIR/platforms/$PLATFORM.sh"
  if [[ ! -f "$platform_script" ]]; then
    echo "Error: Platform script not found: $platform_script" >&2
    exit 1
  fi

  source "$platform_script"

  # Create platform config directory
  local platform_dir="$repo_dir/deployed/${PLATFORM^}"
  mkdir -p "$platform_dir"

  # Call platform-specific setup
  echo "Configuring for platform: $PLATFORM"
  platform_setup
}
