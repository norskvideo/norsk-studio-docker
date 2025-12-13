#!/usr/bin/env bash

# Local/development platform configuration
# Sourced by bootstrap.sh via 20-platform.sh

platform_setup() {
  export PLATFORM_DIR="$REPO_DIR/deployed/local"
  mkdir -p "$PLATFORM_DIR"

  # Use localhost defaults
  export DEPLOY_PUBLIC_IP="127.0.0.1"
  export DEPLOY_HOSTNAME="localhost"

  # Generate norsk-config.sh
  cat > "$PLATFORM_DIR/norsk-config.sh" <<'HEREDOC'
#!/usr/bin/env bash
export DEPLOY_PUBLIC_IP=${DEPLOY_PUBLIC_IP:-"127.0.0.1"}
export DEPLOY_DOMAIN_NAME=""
export DEPLOY_HOSTNAME=${DEPLOY_HOSTNAME:-"localhost"}

# Better for port forwarding
export PUBLIC_URL_PREFIX="/norsk"
export STUDIO_URL_PREFIX="/studio"
# Work around a bug that is fixed but not released
export STUDIO_DOCS_URL="https://docs.norsk.video/studio/latest/index.html"

# Better for port forwarding
echo "absolute_redirect off;" > "$(dirname "$BASH_SOURCE")/../../support/extras/server.conf"
HEREDOC

  chmod +x "$PLATFORM_DIR/norsk-config.sh"
  chown norsk:norsk "$PLATFORM_DIR/norsk-config.sh"

  echo "Platform: local (localhost)"
}
