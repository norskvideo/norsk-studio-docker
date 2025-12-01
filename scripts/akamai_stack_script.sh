#!/bin/bash

# Stack Script for installing Norsk Studio
# Tested with Ubuntu 22.04 LTS and Debian 12

# <UDF name="norsk_license" label="Norsk license JSON string" default="" />
# <UDF name="studio_password" label="Frontend password for norsk-studio-admin" default="" />
# <UDF name="hardware" label="Hardware profile (none or quadra)" default="none" />
# <UDF name="domain_name" label="(Optional) Public domain name for deployment" default="" />
# <UDF name="certbot_email" label="(Optional) Email for certbot renewal notices" default="" />

set -euxo pipefail

# Capture output of stackscript
echo "Logging to /root/stackscript.log"
exec >/root/stackscript.log 2>&1

# Clone repo and run bootstrap script
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh

apt-get update
apt-get install -y git

mkdir -p /var/norsk-studio
cd /var/norsk-studio
git clone -b git-mgt https://github.com/norskvideo/norsk-studio-docker.git

cd /var/norsk-studio/norsk-studio-docker

# Download example media files if using Quadra
if [[ "$HARDWARE" == "quadra" ]]; then
  for source in action.mp4 wildlife.ts; do
    curl --fail -L "https://s3.eu-west-1.amazonaws.com/norsk.video/media-examples/data/$source" -o "data/media/$source"
  done
fi

# Run bootstrap script
./scripts/bootstrap.sh \
  --hardware="$HARDWARE" \
  --platform=linode \
  --license="$NORSK_LICENSE" \
  --password="$STUDIO_PASSWORD" \
  --domain="$DOMAIN_NAME" \
  --certbot-email="$CERTBOT_EMAIL"

# Reboot if using Quadra hardware
if [[ "$HARDWARE" == "quadra" ]]; then
  reboot
fi
