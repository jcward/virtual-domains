#!/bin/bash

DNSMASQ_CONF="/etc/dnsmasq.d/virtual-domains.conf"

case "$1" in
  init)
    echo "# virtual-domains DNS entries" | sudo tee "$DNSMASQ_CONF" > /dev/null
    echo "server=8.8.8.8" | sudo tee -a "$DNSMASQ_CONF" > /dev/null
    echo "listen-address=127.0.0.1" | sudo tee -a "$DNSMASQ_CONF" > /dev/null
    sudo systemctl restart dnsmasq
    echo "✅ dnsmasq plugin initialized"
    ;;
  teardown)
    echo "🧹 Removing $DNSMASQ_CONF"
    sudo rm -f "$DNSMASQ_CONF"
    sudo systemctl restart dnsmasq
    ;;
  add)
    domain="$2"
    ip="$3"
    # Remove duplicates first
    sudo sed -i "/^address=\/$domain\//d" "$DNSMASQ_CONF"
    echo "address=/$domain/$ip" | sudo tee -a "$DNSMASQ_CONF" > /dev/null
    sudo systemctl restart dnsmasq
    echo "✅ Added $domain → $ip"
    ;;
  remove)
    domain="$2"
    sudo sed -i "/^address=\/$domain\//d" "$DNSMASQ_CONF"
    sudo systemctl restart dnsmasq
    echo "🛑 Removed $domain"
    ;;
  *)
    echo "Usage: $0 init|teardown|add <domain> <ip>|remove <domain>"
    exit 1
    ;;
esac
