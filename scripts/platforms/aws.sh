#!/usr/bin/env bash

# AWS EC2 platform configuration
# Sourced by bootstrap.sh via 20-platform.sh

platform_setup() {
  local repo_dir="$INSTALL_DIR/norsk-studio-docker"
  local platform_dir="$repo_dir/deployed/AWS"
  mkdir -p "$platform_dir"

  # Get IMDSv2 token (more secure than IMDSv1)
  local token
  token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

  # Get public IP from instance metadata
  export DEPLOY_PUBLIC_IP="$(curl -s -H "X-aws-ec2-metadata-token: $token" \
    http://169.254.169.254/latest/meta-data/public-ipv4)"

  # Generate norsk-config.sh
  cat > "$platform_dir/norsk-config.sh" <<'HEREDOC'
#!/usr/bin/env bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export DEPLOY_PUBLIC_IP="$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)"
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

  # Write vendor file for detection
  printf 'AWS\n' > "$repo_dir/deployed/vendor"

  echo "Platform IP: $DEPLOY_PUBLIC_IP"
  if [[ -n "${DOMAIN_NAME:-}" ]]; then
    echo "Domain: $DOMAIN_NAME"
  fi
}
