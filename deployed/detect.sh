#!/usr/bin/env bash
if [[ -f /sys/class/dmi/id/bios_vendor && "$(cat /sys/class/dmi/id/bios_vendor)" = "Google" ]]; then
  echo "Google"
elif [[ -f /sys/class/dmi/id/bios_vendor && "$(cat /sys/class/dmi/id/bios_vendor)" = "Linode" ]]; then
  echo "Linode"
elif [[ -f /sys/class/dmi/id/bios_vendor && "$(cat /sys/class/dmi/id/bios_vendor)" = "Amazon EC2" ]]; then
  echo "Amazon"
elif [[ -f /var/norsk-studio/norsk-studio-docker/deployed/vendor && "$(cat /var/norsk-studio/norsk-studio-docker/deployed/vendor)" = "Oracle" ]]; then
  echo "Oracle"
else
  echo "local"
fi
