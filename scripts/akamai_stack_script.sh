#!/bin/bash

# Stack Script for installing Norsk Studio
# Tested with Ubuntu 22.04 LTS and Debian 12

# <UDF name="norsk_license" label="Norsk license JSON string" default="" />
# <UDF name="studio_password" label="Frontend password for norsk-studio-admin" default="" />
# <UDF name="domain_name" label="(Optional) Public domain name for deployment" default="" />
# <UDF name="certbot_email" label="(Optional) Email for certbot renewal notices" default="" />

set -euxo pipefail

# Capture output of stackscript
echo "Logging to /root/stackscript.log"
exec >/root/stackscript.log 2>&1


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

# Download example source files
for source in action.mp4 wildlife.ts; do
  curl --fail -L "https://s3.eu-west-1.amazonaws.com/norsk.video/media-examples/data/$source" -o "/var/norsk-studio/norsk-studio-docker/data/media/$source"
done

# Change ownership and permissions
sudo chown -R norsk:norsk /var/norsk-studio/

# Pull all of the docker images required
./deployed/norsk-containers.sh pull --quiet
./deployed/support-containers.sh pull --quiet
docker pull xmartlabs/htpasswd@sha256:fac862e543f80d72386492aa87b0f6f3c1c06a49a845e553ebea91750ce6320c


# Install and start the systemd units (norsk-setup, norsk, and nginx)
# Ubuntu: wants absolute paths
sudo systemctl enable --now /var/norsk-studio/norsk-studio-docker/deployed/systemd/*.service
