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

remove_hosts_section() {
  sudo sed -i "/$BEGIN/,/$END/d" "$HOSTS_FILE"
}

case "$1" in
  init) ;;
  teardown) remove_hosts_section ;;
  add) add_entry "$2" "$3" ;;
  remove) remove_entry "$2" ;;
  *) echo "Usage: $0 init|teardown|add <domain> <ip>|remove <domain>" ;;
esac
