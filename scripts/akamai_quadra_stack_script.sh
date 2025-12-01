#!/bin/bash

# Stack Script for installing Norsk Studio with Netint Quadra Support
# Tested with Ubuntu 22.04 LTS

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
git clone -b git-mgt https://github.com/norskvideo/norsk-studio-docker.git

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

# Set up Quadra support
cd /var/norsk-studio/
curl -O 'https://releases.netint.com/quadra/L8Q6OW2GRMBRJWF/Quadra_V5.2.0.zip'
curl -O http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz
if [[
  "$(md5sum Quadra_V5.2.0.zip | head -c 32)" == e458a75a9a09c8b59ce8a184ca9e5ad6 &&
  "$(md5sum yasm-1.3.0.tar.gz | head -c 32)" == fc9e586751ff789b34b1f21d572d96af
]]; then
  python3 -c 'from zipfile import ZipFile; ZipFile("Quadra_V5.2.0.zip").extractall()'
  tar -zxf yasm-1.3.0.tar.gz

  # Dependencies
  sudo DEBIAN_FRONTEND=noninteractive \
    apt-get install -y -q \
        pkg-config git gcc ninja-build python3 \
        python3-pip flex bison libpng-dev zlib1g-dev gnutls-bin uuid-runtime \
        uuid-dev libglib2.0-dev libxml2 libxml2-dev
  sudo pip3 install meson
  (cd yasm-1.3.0/; ./configure && make && sudo make install)

  (cd Quadra_V5.2.0/Quadra_SW_V5.2.0_RC3/libxcoder; bash build.sh)
else
  echo "Error: md5sums of Quadra_V5.2.0.zip or yasm-1.3.0.tar.gz did not match expected"
  md5sum Quadra_V5.2.0.zip yasm-1.3.0.tar.gz
  exit 1
fi

# Give the norsk user access to the hardware
sudo usermod -aG disk norsk
# Configure Norsk with access
echo 'export DEPLOY_HARDWARE="quadra"' >> /var/norsk-studio/norsk-studio-docker/deployed/Linode/norsk-config.sh

# Initialize Netint Quadra support via libxcoder
# (right now and at every boot, runs as user norsk)
sudo systemctl enable --now /var/norsk-studio/norsk-studio-docker/deployed/Linode/nilibxcoder.service


# Install and start the systemd units (norsk-setup, norsk, and nginx)
# Ubuntu: wants absolute paths
sudo systemctl enable --now /var/norsk-studio/norsk-studio-docker/deployed/systemd/*.service

reboot
