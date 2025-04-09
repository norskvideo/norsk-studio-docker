#!/usr/bin/env bash
if [[ -f /sys/class/dmi/id/bios_vendor && "$(cat /sys/class/dmi/id/bios_vendor)" = "Google" ]]; then
  echo "Google"
elif [[ -f /sys/class/dmi/id/bios_vendor && "$(cat /sys/class/dmi/id/bios_vendor)" = "Linode" ]]; then
  echo "Linode"
else
  echo "local"
fi
