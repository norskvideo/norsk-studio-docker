#!/usr/bin/env bash

# Bootstrap script for Norsk Studio on Oracle Cloud
# Tested with Ubuntu 22.04 LTS
#
# requirements:
# - run as root
# - set the NORSK_LICENSE environment variable to contain the license json

set -euxo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Install docker using convenience script
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Add a new user norsk
sudo groupadd norsk
sudo useradd -g norsk -G root,docker -ms /bin/bash norsk

# Install `dig` and `certbot`
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q certbot dnsutils

sudo mkdir -p /var/norsk-studio
cd /var/norsk-studio
git clone -b deployed https://github.com/norskvideo/norsk-studio-docker.git

cd /var/norsk-studio/norsk-studio-docker

# Set secrets and config from UDF
(set +x; printf '%s\n' "$NORSK_LICENSE") > ./secrets/license.json
(set +x; printf '%s' "$STUDIO_PASSWORD") | docker run --rm -i xmartlabs/htpasswd@sha256:fac862e543f80d72386492aa87b0f6f3c1c06a49a845e553ebea91750ce6320c -i norsk-studio-admin > ./support/oauth2/secrets/.htpasswd

mkdir -p ./deployed/Oracle
cat > ./deployed/Oracle/norsk-config.sh <<HEREDOC
#!/usr/bin/env bash
export DEPLOY_PUBLIC_IP="\$(curl http://checkip.amazonaws.com)"
export DEPLOY_DOMAIN_NAME=${DOMAIN_NAME@Q}
export DEPLOY_CERTBOT_EMAIL=${CERTBOT_EMAIL@Q}
if [[ -z "\$DEPLOY_DOMAIN_NAME" ]]; then
  export DEPLOY_HOSTNAME="\$DEPLOY_PUBLIC_IP"
else
  export DEPLOY_HOSTNAME="\$DEPLOY_DOMAIN_NAME"
fi

HEREDOC

(set +x; printf '%s\n' "Oracle") > ./deployed/vendor

# Change ownership and permissions
sudo chown -R norsk:norsk /var/norsk-studio/

# Pull all of the docker images required
./deployed/norsk-containers.sh pull --quiet
./deployed/support-containers.sh pull --quiet
docker pull xmartlabs/htpasswd@sha256:fac862e543f80d72386492aa87b0f6f3c1c06a49a845e553ebea91750ce6320c

# Disable oauth2
sed -i 's/export AUTH_METHOD=oauth2/export AUTH_METHOD=no-auth/' ./deployed/support-containers.sh

# Fix up iptables rules to allow all incoming traffic (for norsk)
sudo iptables -F INPUT
iptables-save > /etc/iptables/rules.v4

# Install and start the systemd units (norsk-setup, norsk, and nginx)
# Ubuntu: wants absolute paths
sudo systemctl enable --now /var/norsk-studio/norsk-studio-docker/deployed/systemd/*.service
