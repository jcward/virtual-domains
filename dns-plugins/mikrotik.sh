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
    if ! run_ssh '/ip dns static remove [find comment="virtual-domains"]'; then
      echo "Warning: Failed to remove some entries from MikroTik"
    fi
    echo "Removing $CONFIG_FILE"
    sudo rm -f "$CONFIG_FILE"
    ;;
  add)
    load_config
    domain="$2"
    ip="$3"
    # Combine both commands into a single SSH session
    if ! run_ssh "/ip dns static remove [find name=\"$domain\"]; /ip dns static add name=\"$domain\" address=\"$ip\" comment=\"virtual-domains\""; then
      echo "Error: Failed to add $domain → $ip to MikroTik"
      exit 1
    fi
    echo "✅ Added $domain → $ip to MikroTik"
    ;;
  remove)
    load_config
    domain="$2"
    if ! run_ssh "/ip dns static remove [find name=\"$domain\"]"; then
      echo "Error: Failed to remove $domain from MikroTik"
      exit 1
    fi
    echo "🛑 Removed $domain from MikroTik"
    ;;
  debug)
    load_config
    echo "📋 MikroTik DNS Static Entries:"
    echo "==============================="
    echo
    echo "🔍 virtual-domains entries:"
    if ! run_ssh '/ip dns static print detail where comment="virtual-domains"'; then
      echo "Error: Failed to query MikroTik DNS entries"
      exit 1
    fi
    echo
    echo "📋 All DNS static entries:"
    if ! run_ssh '/ip dns static print detail'; then
      echo "Error: Failed to query MikroTik DNS entries"
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 init|teardown|add <domain> <ip>|remove <domain>|debug"
    exit 1
    ;;
esac
