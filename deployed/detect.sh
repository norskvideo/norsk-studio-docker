#!/usr/bin/env bash
if [[ -f /var/norsk-studio/norsk-studio-docker/deployed/vendor ]]; then
  cat /var/norsk-studio/norsk-studio-docker/deployed/vendor
elif [[ -f /sys/class/dmi/id/bios_vendor && "$(cat /sys/class/dmi/id/bios_vendor)" = "Google" ]]; then
  echo "Google"
elif [[ -f /sys/class/dmi/id/bios_vendor && "$(cat /sys/class/dmi/id/bios_vendor)" = "Linode" ]]; then
  echo "Linode"
elif [[ -f /sys/class/dmi/id/bios_vendor && "$(cat /sys/class/dmi/id/bios_vendor)" = "Amazon EC2" || -f /sys/class/dmi/id/bios_version && "$(cat /sys/class/dmi/id/bios_version)" =~ "amazon" ]]; then
  echo "Amazon"
else
  echo "local"
fi
