#!/usr/bin/env bash

# Linode platform configuration
# Sourced by bootstrap.sh via 20-platform.sh

platform_setup() {
  local repo_dir="$INSTALL_DIR/norsk-studio-docker"
  local platform_dir="$repo_dir/deployed/Linode"

  # Get public IP from eth0
  export DEPLOY_PUBLIC_IP="$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)"

  # Generate norsk-config.sh
  cat > "$platform_dir/norsk-config.sh" <<'HEREDOC'
#!/usr/bin/env bash
export DEPLOY_PUBLIC_IP="$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)"
export DEPLOY_DOMAIN_NAME=${DOMAIN_NAME}
export DEPLOY_CERTBOT_EMAIL=${CERTBOT_EMAIL}
if [[ -z "$DEPLOY_DOMAIN_NAME" ]]; then
  export DEPLOY_HOSTNAME="$DEPLOY_PUBLIC_IP"
else
  export DEPLOY_HOSTNAME="$DEPLOY_DOMAIN_NAME"
fi

HEREDOC

  # Substitute actual values into the config
  sed -i "s|\${DOMAIN_NAME}|${DOMAIN_NAME}|g" "$platform_dir/norsk-config.sh"
  sed -i "s|\${CERTBOT_EMAIL}|${CERTBOT_EMAIL}|g" "$platform_dir/norsk-config.sh"

  chmod +x "$platform_dir/norsk-config.sh"
  chown norsk:norsk "$platform_dir/norsk-config.sh"

  echo "Platform IP: $DEPLOY_PUBLIC_IP"
  if [[ -n "${DOMAIN_NAME:-}" ]]; then
    echo "Domain: $DOMAIN_NAME"
  fi
}
