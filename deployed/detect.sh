#!/usr/bin/env bash
if [[ -f /sys/class/dmi/id/bios_vendor ]]; then
  vendor="$(cat /sys/class/dmi/id/bios_vendor)"
  case "$vendor" in
    Google)
      echo "Google"
      ;;
    Linode)
      echo "Linode"
      ;;
    Amazon*|EC2*)
      echo "AWS"
      ;;
    *)
      if [[ -f /opt/norsk-studio/deployed/vendor ]]; then
        cat /opt/norsk-studio/deployed/vendor
      else
        echo "local"
      fi
      ;;
  esac
else
  echo "local"
fi
