#!/usr/bin/env bash
curl -fsH 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/attributes/norsk-studio-admin-password || echo "$(hostname)-norsk-studio-password"
