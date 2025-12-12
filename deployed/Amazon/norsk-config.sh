#!/usr/bin/env bash
TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
export DEPLOY_PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
export DEPLOY_DOMAIN_NAME=""
export DEPLOY_CERTBOT_EMAIL=""
if [[ -z "$DEPLOY_DOMAIN_NAME" ]]; then
  export DEPLOY_HOSTNAME="$DEPLOY_PUBLIC_IP"
else
  export DEPLOY_HOSTNAME="$DEPLOY_DOMAIN_NAME"
fi
