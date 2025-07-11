#!/bin/bash

HOSTS_FILE="/etc/hosts"
BEGIN="### BEGIN virtual-domains"
END="### END virtual-domains"

ensure_hosts_section() {
  if ! grep -q "$BEGIN" "$HOSTS_FILE"; then
    echo -e "\n$BEGIN\n$END" | sudo tee -a "$HOSTS_FILE" > /dev/null
  fi
}

add_entry() {
  domain=$1; ip=$2
  ensure_hosts_section
  sudo sed -i "/$BEGIN/,/$END/{ /$domain/d }" "$HOSTS_FILE"
  sudo sed -i "/$BEGIN/a $ip $domain" "$HOSTS_FILE"
}

remove_entry() {
  domain=$1
  sudo sed -i "/$BEGIN/,/$END/{ /$domain/d }" "$HOSTS_FILE"
}

case "$1" in
  add) add_entry "$2" "$3" ;;  # $2 = domain, $3 = ip
  remove) remove_entry "$2" ;;
  *) echo "Usage: $0 add|remove domain [ip]" ;;
esac
