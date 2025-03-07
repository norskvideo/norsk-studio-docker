#!/bin/bash

# <UDF name="norsk_license" label="Norsk license JSON string" default="" />
# <UDF name="studio_password" label="Frontend password for norsk-studio-admin" default="" />
# <UDF name="domain_name" label="(Optional) Public domain name for deployment" default="" />
# <UDF name="certbot_email" label="(Optional) Email for certbot renewal notices" default="" />

set -euxo pipefail

# Capture output of stackscript
exec >/root/stackscript.log 2>&1


# Install docker using convenience script
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh


# Install `dig` and `certbot`
sudo apt-get install -y certbot dnsutils

sudo mkdir -p /var/norsk-studio
cd /var/norsk-studio
git clone -b deployed https://github.com/norskvideo/norsk-studio-starter-kit.git

cd /var/norsk-studio/norsk-studio-starter-kit

# Pull all of the docker images required
sudo ./deployed/norsk-containers.sh pull
sudo ./deployed/support-containers.sh pull
sudo docker pull xmartlabs/htpasswd@sha256:fac862e543f80d72386492aa87b0f6f3c1c06a49a845e553ebea91750ce6320c

# Install the systemd units
sudo systemctl enable ./deployed/systemd/*.service

# Set secrets and config from UDF
(set +x; printf '%s\n' "$NORSK_LICENSE") > ./secrets/license.json
(set +x; printf '%s' "$STUDIO_PASSWORD") | docker run --rm -i xmartlabs/htpasswd@sha256:fac862e543f80d72386492aa87b0f6f3c1c06a49a845e553ebea91750ce6320c -i norsk-studio-admin > ./support/oauth2/secrets/.htpasswd

mkdir -p ./deployed/Linode
cat > ./deployed/Linode/norsk-config.sh <<HEREDOC
#!/usr/bin/env bash
export DEPLOY_PUBLIC_IP="\$(ip addr show eth0 | grep "inet\b" | awk '{print \$2}' | cut -d/ -f1)"
export DEPLOY_DOMAIN_NAME=${DOMAIN_NAME@Q}
export DEPLOY_CERTBOT_EMAIL=${CERTBOT_EMAIL@Q}
if [[ -z "\$DEPLOY_DOMAIN_NAME" ]]; then
  export DEPLOY_HOSTNAME="\$DEPLOY_PUBLIC_IP"
else
  export DEPLOY_HOSTNAME="\$DEPLOY_DOMAIN_NAME"
fi
HEREDOC

(cd ./deployed/systemd/; sudo systemctl start *.service)