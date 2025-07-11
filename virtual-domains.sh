#!/bin/bash

set -e

CONF_FILE="/etc/virtual-domains.conf"
HOSTS_FILE="/etc/hosts"
BEGIN_MARKER="### BEGIN virtual-domains"
END_MARKER="### END virtual-domains"

ensure_conf_exists() {
  if [ ! -f "$CONF_FILE" ]; then
    echo "=== Virtual Domain Setup ==="
    echo "This tool maps custom domains to local virtual IPs for development."
    echo
    echo "How should your dev domains be accessible?"
    echo " [1] Host-only (localhost only, via loopback interface)"
    echo " [2] LAN-visible (accessible from other devices on the network)"
    read -p "Choice [1/2]: " choice

    echo
    echo "Detected interfaces:"
    ip -o link show | awk -F': ' '{print " - "$2}'

    if [ "$choice" == "1" ]; then
      mode="local"
      iface="lo"
      subnet="127.10.10.0/24"
    else
      mode="lan"
      read -p "Which interface should be used (e.g. eth0): " iface
      read -p "What subnet will you assign virtual IPs in? (e.g. 10.0.1.0/24): " subnet
    fi

    sudo tee "$CONF_FILE" > /dev/null <<EOF
# mode=$mode
# iface=$iface
# subnet=$subnet
# domain ip
EOF
    echo "Created $CONF_FILE"
  fi
}

get_iface() {
  grep '^# iface=' "$CONF_FILE" | cut -d= -f2
}

get_mode() {
  grep '^# mode=' "$CONF_FILE" | cut -d= -f2
}

add_domain() {
  domain=$1
  ip=$2
  iface=$(get_iface)

  # Check if already exists
  if grep -q "^$domain " "$CONF_FILE"; then
    echo "$domain already exists. Updating IP to $ip."
    sudo sed -i "s|^$domain .*|$domain $ip|" "$CONF_FILE"
  else
    echo "Adding $domain -> $ip"
    echo "$domain $ip" | sudo tee -a "$CONF_FILE" > /dev/null
  fi

  echo "Assigning IP $ip to $iface"
  sudo ip addr add "$ip/32" dev "$iface" || true  # allow idempotent add
  regenerate_hosts
}

purge_domain() {
  domain=$1
  ip=$(grep "^$domain " "$CONF_FILE" | awk '{print $2}')
  iface=$(get_iface)

  echo "Purging $domain from config and hosts"
  sudo sed -i "/^$domain /d" "$CONF_FILE"

  # If no other domain is using this IP, remove it
  if ! grep -q " $ip$" "$CONF_FILE"; then
    echo "No other domains use $ip, removing IP from interface $iface"
    sudo ip addr del "$ip/32" dev "$iface" || true
  fi

  regenerate_hosts
}

regenerate_hosts() {
  echo "Regenerating $HOSTS_FILE entries..."

  tmp=$(mktemp)
  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    BEGIN {inblock=0}
    $0 ~ begin {inblock=1; print begin; print "# updated " strftime("%F %T"); while ((getline line < "'$CONF_FILE'") > 0) {
      if (line ~ /^[^#]/) {
        split(line, f, " ")
        print f[2], f[1]
      }
    }; next}
    $0 ~ end {inblock=0; print end; next}
    !inblock {print}
  ' "$HOSTS_FILE" > "$tmp"

  # Ensure both markers are present
  if ! grep -q "$BEGIN_MARKER" "$tmp"; then
    echo -e "$BEGIN_MARKER\n# updated $(date)\n$END_MARKER" >> "$tmp"
  fi

  sudo cp "$tmp" "$HOSTS_FILE"
  rm "$tmp"
}

print_usage() {
  echo "Usage:"
  echo "  $0 <domain> <ip>         Add or update domain"
  echo "  $0 --purge <domain>      Remove domain"
  echo "  $0 --list                Show current config"
  echo "  $0 --install-service     Install a systemd service to recreate IPs at boot (calls --up)"
  echo "  $0 --up                  Assign all IPs"
  echo "  $0 --down                Remove all IPs"

}

list_domains() {
  echo "Configured virtual domains:"
  grep -v '^#' "$CONF_FILE"
}

install_service() {
  SCRIPT_PATH="/usr/local/bin/virtual-domains.sh"
  SERVICE_PATH="/etc/systemd/system/virtual-domains.service"

  if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Error: Expected script to be at $SCRIPT_PATH"
    echo "Move it there before installing systemd service."
    exit 1
  fi

  echo "Installing systemd unit to manage virtual IPs..."

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

  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable virtual-domains.service

  echo "✅ Service installed and enabled: virtual-domains.service"
  echo "You can now run: sudo systemctl start virtual-domains"
}

up_all_ips() {
  iface=$(get_iface)
  grep -v '^#' "$CONF_FILE" | while read -r domain ip; do
    echo "Assigning $ip to $iface"
    sudo ip addr add "$ip/32" dev "$iface" || true
  done
}

down_all_ips() {
  iface=$(get_iface)
  grep -v '^#' "$CONF_FILE" | while read -r domain ip; do
    echo "Removing $ip from $iface"
    sudo ip addr del "$ip/32" dev "$iface" || true
  done
}

### MAIN ###
ensure_conf_exists

case "$1" in
  --install-service)
    install_service
    ;;
  --up)
    up_all_ips
    ;;
  --down)
    down_all_ips
    ;;
  --purge)
    if [ -z "$2" ]; then print_usage; exit 1; fi
    purge_domain "$2"
    ;;
  --list)
    list_domains
    ;;
  *)
    if [ -z "$1" ] || [ -z "$2" ]; then print_usage; exit 1; fi
    add_domain "$1" "$2"
    ;;
esac
