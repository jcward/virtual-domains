#!/bin/bash

PLUGIN_STATE_DIR="/run/virtual-domains-mdns"
sudo mkdir -p "$PLUGIN_STATE_DIR"

case "$1" in
  init)
    echo "✅ mDNS plugin ready (requires avahi-daemon and avahi-publish)"
    ;;
  teardown)
    echo "🧹 Removing mDNS entries..."
    pkill -f 'avahi-publish -a' || true
    rm -rf "$PLUGIN_STATE_DIR"
    ;;
  add)
    domain="$2"
    ip="$3"
    echo "📣 Publishing $domain as $ip via mDNS"
    avahi-publish -a "$domain" "$ip" &
    echo $! > "$PLUGIN_STATE_DIR/$domain.pid"
    ;;
  remove)
    domain="$2"
    if [ -f "$PLUGIN_STATE_DIR/$domain.pid" ]; then
      kill "$(cat "$PLUGIN_STATE_DIR/$domain.pid")" || true
      rm "$PLUGIN_STATE_DIR/$domain.pid"
      echo "🛑 Removed mDNS for $domain"
    fi
    ;;
  *)
    echo "Usage: $0 init|teardown|add <domain> <ip>|remove <domain>"
    exit 1
    ;;
esac
