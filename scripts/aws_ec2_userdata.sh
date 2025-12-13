#!/bin/bash

# EC2 UserData script for Norsk Studio installation
# Tested with Ubuntu 22.04 LTS
#
# Prerequisites:
# 1. IAM instance profile with SSM parameter read access
# 2. SSM parameters created:
#    - /norsk/license (SecureString)
#    - /norsk/password (SecureString)
# 3. (Optional) EC2 instance tags:
#    - DomainName
#    - CertbotEmail
# 4. (Optional) HardwareProfile tag for manual override (auto|none|quadra|nvidia)

set -euxo pipefail

# Capture output
exec >/var/log/ec2-userdata.log 2>&1

# Get IMDSv2 token
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Fetch secrets from SSM Parameter Store
echo "Fetching secrets from SSM..."
NORSK_LICENSE=$(aws ssm get-parameter \
  --name /norsk/license \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text \
  --region $(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/placement/region))

STUDIO_PASSWORD=$(aws ssm get-parameter \
  --name /norsk/password \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text \
  --region $(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/placement/region))

# Fetch optional config from instance tags (allow failures)
DOMAIN_NAME=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/tags/instance/DomainName || echo "")

CERTBOT_EMAIL=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/tags/instance/CertbotEmail || echo "")

HARDWARE_OVERRIDE=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/tags/instance/HardwareProfile || echo "auto")

# Install git
apt-get update
apt-get install -y git

# Clone repo
git clone -b git-mgt https://github.com/norskvideo/norsk-studio-docker.git /opt/norsk-studio
cd /opt/norsk-studio

# Run bootstrap
./scripts/bootstrap.sh \
  --platform=aws \
  --hardware="$HARDWARE_OVERRIDE" \
  --license="$NORSK_LICENSE" \
  --password="$STUDIO_PASSWORD" \
  --domain="$DOMAIN_NAME" \
  --certbot-email="$CERTBOT_EMAIL"

# Reboot if GPU hardware detected (check installed config)
if grep -q 'DEPLOY_HARDWARE="nvidia"' deployed/*/norsk-config.sh 2>/dev/null; then
  echo "NVIDIA hardware detected, rebooting..."
  reboot
fi
