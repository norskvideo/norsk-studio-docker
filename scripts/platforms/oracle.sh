#!/usr/bin/env bash

# Oracle Cloud platform configuration
# Sourced by bootstrap.sh via 20-platform.sh

platform_setup() {
  export PLATFORM_DIR="$REPO_DIR/deployed/Oracle"
  mkdir -p "$PLATFORM_DIR"

  # Get public IP from AWS check IP service
  export DEPLOY_PUBLIC_IP="$(curl -fs http://checkip.amazonaws.com)"

  # Generate norsk-config.sh
  cat > "$PLATFORM_DIR/norsk-config.sh" <<'HEREDOC'
#!/usr/bin/env bash
export DEPLOY_PUBLIC_IP="$(curl http://checkip.amazonaws.com)"
export DEPLOY_DOMAIN_NAME=${DOMAIN_NAME}
export DEPLOY_CERTBOT_EMAIL=${CERTBOT_EMAIL}
if [[ -z "$DEPLOY_DOMAIN_NAME" ]]; then
  export DEPLOY_HOSTNAME="$DEPLOY_PUBLIC_IP"
else
  export DEPLOY_HOSTNAME="$DEPLOY_DOMAIN_NAME"
fi

HEREDOC

  # Substitute actual values
  sed -i "s|\${DOMAIN_NAME}|${DOMAIN_NAME}|g" "$PLATFORM_DIR/norsk-config.sh"
  sed -i "s|\${CERTBOT_EMAIL}|${CERTBOT_EMAIL}|g" "$PLATFORM_DIR/norsk-config.sh"

  chmod +x "$PLATFORM_DIR/norsk-config.sh"
  chown norsk:norsk "$PLATFORM_DIR/norsk-config.sh"

  # Write vendor file for detection
  printf 'Oracle\n' > "$REPO_DIR/deployed/vendor"

  # TODO: Verify if still needed - original script modified iptables
  # Fix up iptables rules to allow all incoming traffic (for norsk)
  echo "TODO: Review if iptables modification still required"
  iptables -F INPUT || true
  iptables-save > /etc/iptables/rules.v4 || true

  # Match Linode behavior - keep oauth2 enabled (don't disable)
  # Original oracle script disabled it, but per user decision, match Linode

  echo "Platform IP: $DEPLOY_PUBLIC_IP"
  if [[ -n "${DOMAIN_NAME:-}" ]]; then
    echo "Domain: $DOMAIN_NAME"
  fi
}
