#!/bin/bash

CONFIG_FILE="/etc/virtual-domains.mikrotik"
MKT_USER=""
MKT_HOST=""

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
  else
    echo "Missing $CONFIG_FILE. Run 'init' first."
    exit 1
  fi
}

run_ssh() {
  ssh -o StrictHostKeyChecking=no "$MKT_USER@$MKT_HOST" "$@"
}

case "$1" in
  init)
    echo "🔧 Setting up MikroTik DNS plugin..."
    read -p "Router IP (e.g. 192.168.88.1): " host
    read -p "Router username: " user
    echo "MKT_HOST=$host" | sudo tee "$CONFIG_FILE"
    echo "MKT_USER=$user" | sudo tee -a "$CONFIG_FILE"
    echo "✅ MikroTik config saved to $CONFIG_FILE"
    ;;
  teardown)
    load_config
    echo "🧹 Deleting all virtual-domains entries from MikroTik..."
    run_ssh '/ip dns static remove [find comment=\"virtual-domains\"]'
    echo "Removing $CONFIG_FILE"
    rm -f $CONFIG_FILE
    ;;
  add)
    load_config
    domain="$2"
    ip="$3"
    run_ssh \"/ip dns static remove [find name=$domain]\"
    run_ssh \"/ip dns static add name=$domain address=$ip comment=virtual-domains\"
    echo "✅ Added $domain → $ip to MikroTik"
    ;;
  remove)
    load_config
    domain="$2"
    run_ssh \"/ip dns static remove [find name=$domain]\"
    echo "🛑 Removed $domain from MikroTik"
    ;;
  *)
    echo "Usage: $0 init|teardown|add <domain> <ip>|remove <domain>"
    exit 1
    ;;
esac
