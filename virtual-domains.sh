#!/bin/bash

set -e

CONF_FILE="/etc/virtual-domains.conf"
BEGIN_MARKER="### BEGIN virtual-domains"
END_MARKER="### END virtual-domains"

# Read from config
get_iface() { grep '^# iface=' "$CONF_FILE" | cut -d= -f2; }
get_dns_mode() { grep '^# dns=' "$CONF_FILE" | cut -d= -f2; }

ensure_conf_exists() {
  if [ ! -f "$CONF_FILE" ]; then
    echo "=== Virtual Domain Setup ==="
    echo "How should your dev domains be accessible?"
    echo " [1] Host-only (via loopback interface)"
    echo " [2] LAN-visible (via your main network interface)"
    read -p "Choice [1/2]: " choice

    ip -o link show | awk -F': ' '{print " - "$2}'

    if [ "$choice" == "1" ]; then
      mode="local"
      iface="lo"
      subnet="127.10.10.0/24"
    else
      mode="lan"
      read -p "Which interface to use (e.g. eth0): " iface
      read -p "What subnet (e.g. 10.0.1.0/24): " subnet
    fi

    echo "What DNS handling plugin should be used?"
    echo " - etc_hosts (default /etc/hosts)"
    echo " - none (no DNS integration)"
    echo " - /path/to/your/plugin.sh"
    read -p "DNS mode [etc_hosts]: " dns_mode
    dns_mode=${dns_mode:-etc_hosts}

    echo "# mode=$mode" | sudo tee "$CONF_FILE"
    echo "# iface=$iface" | sudo tee -a "$CONF_FILE"
    echo "# subnet=$subnet" | sudo tee -a "$CONF_FILE"
    echo "# dns=$dns_mode" | sudo tee -a "$CONF_FILE"
    echo "# domain ip" | sudo tee -a "$CONF_FILE"
  fi
}

call_dns_plugin() {
  action=$1; domain=$2; ip=$3
  dns_mode=$(get_dns_mode)
  if [[ "$dns_mode" == "none" ]]; then
    return
  elif [[ "$dns_mode" == "etc_hosts" ]]; then
    /usr/local/lib/virtual-domains/etc_hosts.sh "$action" "$domain" "$ip"
  elif [[ -x "$dns_mode" ]]; then
    "$dns_mode" "$action" "$domain" "$ip"
  else
    echo "Warning: DNS plugin $dns_mode not found or not executable."
  fi
}

add_domain() {
  domain=$1; ip=$2
  iface=$(get_iface)
  echo "$domain $ip" | sudo tee -a "$CONF_FILE" > /dev/null
  sudo ip addr add "$ip/32" dev "$iface" || true
  call_dns_plugin add "$domain" "$ip"
}

purge_domain() {
  domain=$1
  ip=$(grep "^$domain " "$CONF_FILE" | awk '{print $2}')
  iface=$(get_iface)
  sudo sed -i "/^$domain /d" "$CONF_FILE"
  call_dns_plugin remove "$domain" "$ip"
  if ! grep -q " $ip$" "$CONF_FILE"; then
    sudo ip addr del "$ip/32" dev "$iface" || true
  fi
}

up_all_ips() {
  iface=$(get_iface)
  grep -v '^#' "$CONF_FILE" | while read -r domain ip; do
    sudo ip addr add "$ip/32" dev "$iface" || true
    call_dns_plugin add "$domain" "$ip"
  done
}

down_all_ips() {
  iface=$(get_iface)
  grep -v '^#' "$CONF_FILE" | while read -r domain ip; do
    call_dns_plugin remove "$domain" "$ip"
    sudo ip addr del "$ip/32" dev "$iface" || true
  done
}

install_service() {
  SCRIPT_PATH="/usr/local/bin/virtual-domains.sh"
  SERVICE_PATH="/etc/systemd/system/virtual-domains.service"
  if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Expected script at $SCRIPT_PATH"
    exit 1
  fi
  sudo tee "$SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=Assign virtual dev domain IPs
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH --up
RemainAfterExit=true
ExecStop=$SCRIPT_PATH --down

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable virtual-domains.service
  echo "✅ Service installed and enabled."
}

teardown_all() {
  read -p "⚠️  This will remove all virtual domain config and undo all setup. Are you sure? [y/N]: " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 1
  fi

  echo "Removing all virtual domain IPs and DNS entries..."
  down_all_ips

  echo "Removing systemd service (if exists)..."
  sudo systemctl disable virtual-domains.service 2>/dev/null || true
  sudo rm -f /etc/systemd/system/virtual-domains.service
  sudo systemctl daemon-reload

  echo "Removing $CONF_FILE..."
  sudo rm -f "$CONF_FILE"

  echo "\nSo long, and thanks for all the fish! virtual-domains.sh out!"
}

list_domains() {
  echo "Configured domains:" && grep -v '^#' "$CONF_FILE"
}

print_usage() {
  echo "Usage:"
  echo "  $0 domain ip         Add domain"
  echo "  $0 --purge domain    Remove domain"
  echo "  $0 --list            List domains"
  echo "  $0 --up              Re-assign all IPs"
  echo "  $0 --down            Remove all IPs"
  echo "  $0 --install-service Install systemd unit"
  echo "  $0 --teardown        Uninstall everything (with prompt)"
}

### MAIN ###
ensure_conf_exists
case "$1" in
  --purge) purge_domain "$2" ;;
  --list) list_domains ;;
  --up) up_all_ips ;;
  --down) down_all_ips ;;
  --install-service) install_service ;;
  --teardown) teardown_all ;;
  "") print_usage ;;
  *) add_domain "$1" "$2" ;;
esac
