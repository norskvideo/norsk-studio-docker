#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")" || exit 1

# Requires `dig` (which may be provided by a `dnsutils` or `bind-utils` package)
# and `certbot`

DNS="8.8.8.8"
DOMAIN="$1"
IP="$2"
EMAIL="$3"

LOGS=../logs/certbot-dns
rm -rf $LOGS
mkdir -p $LOGS

function pause() {
  printf "sleep %s\r" "$1" >&2
  sleep "$1"
  printf "           \r" >&2
}

function check_dns() {
  pause 12
  echo
  date | tee $LOGS/dns_recent.txt

  # Use `+trace` for recursive DNS resolving
  dig -4 "@$DNS" +trace "$DOMAIN" >> $LOGS/dns_recent.txt 2>&1

  # Keep a running total of the logs
  cat $LOGS/dns_recent.txt >> $LOGS/dns_total.txt
  cat $LOGS/dns_recent.txt >> $LOGS/total.txt
  # Output some important info to stdout
  cat $LOGS/dns_recent.txt | grep -e "^$DOMAIN." -e "^;; Received"
  # Pull the `A` records out of the result
  cat $LOGS/dns_recent.txt \
    | grep "^$DOMAIN." \
    | grep -oE '\sA\s+[.[:digit:]]+$' \
    | grep -oE '[.[:digit:]]+$' \
    | sort | uniq > $LOGS/dns_ips.txt
  # Return whether it was found
  # (this is an exact line match)
  grep -Fxq "$IP" $LOGS/dns_ips.txt
}
function recheck_dns() {
  # If it just started succeeding, we want to give remote DNS a good chance to
  # see the DNS update too
  check_dns && pause 20
}

function wait_for_dns() {
  # Spend up to 72s checking DNS before trying a staging cert anyways
  check_dns || recheck_dns || recheck_dns || recheck_dns || recheck_dns || recheck_dns
  printf "\nDNS status: %s (0: DNS looks right from here, 1: no, but trying anyways)\n\n" "$?"
  # Try a staging cert and then a production cert, or sleep for a while before
  # checking DNS and trying again
  try_cert || wait_for_dns
}

function try_cert() {
  # First try a staging cert
  echo "Trying a staging cert..." >&2
  if tee_cert --dry-run > /dev/null; then
    pause 5
    # Then try a production cert
    echo "Trying a production cert:" >&2
    # Always log production cert attempts to stdout
    if tee_cert; then
      echo "Success!" >&2
      return 0
    else
      echo >> $LOGS/cert_total.txt
      echo >&2
      echo "Production cert failed" >&2
      # 12 minutes per failed certificate request
      pause 720
      return 1
    fi
  else
    echo "Staging cert failed" >&2
    # 1 minute per failed staging certificate request
    pause 60
    return 1
  fi
}

function tee_cert() {
  do_cert "$@" 2>&1 \
    | tee $LOGS/cert_recent.txt \
    | tee -a $LOGS/cert_total.txt \
    | tee -a $LOGS/total.txt
}
function do_cert() {
  date
  if [[ -z "$EMAIL" || "$1" == "--dry-run" ]]; then
    echo sudo certbot certonly --standalone --agree-tos --register-unsafely-without-email --non-interactive -d "$DOMAIN" "$@"
    sudo certbot certonly --standalone --agree-tos --register-unsafely-without-email --non-interactive -d "$DOMAIN" "$@"
  else
    echo sudo certbot certonly --standalone --agree-tos --email "$EMAIL" --non-interactive -d "$DOMAIN" "$@"
    sudo certbot certonly --standalone --agree-tos --email "$EMAIL" --non-interactive -d "$DOMAIN" "$@"
  fi
}

function main() {
  if echo "$DOMAIN" | grep -E '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$'
  then
    if echo "$IP" | grep -E '^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])$'
    then
      wait_for_dns
    else
      echo "Invalid IP: $IP" >&2
      exit 2
    fi
  else
    echo "Invalid domain name: $DOMAIN" >&2
    exit 3
  fi
}

main
