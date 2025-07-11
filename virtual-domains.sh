#!/bin/bash

VERSION="0.0.0-DEV"

set -e

CONF_FILE="/etc/virtual-domains.conf"
BEGIN_MARKER="### BEGIN virtual-domains"
END_MARKER="### END virtual-domains"

# Get directory where this script is installed
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$SCRIPT_DIR/../lib/virtual-domains"

# Read from config
get_iface() { grep '^# iface=' "$CONF_FILE" | cut -d= -f2; }
get_dns_mode() { grep '^# dns=' "$CONF_FILE" | cut -d= -f2; }

# Get IPv4 address and subnet for an interface
get_interface_info() {
  local iface=$1
  local info=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1)
  if [ -n "$info" ]; then
    echo "$info" | awk '{print $2}'
  fi
}

# Auto-detect subnet from interface
get_suggested_subnet() {
  local iface=$1
  local cidr=$(get_interface_info "$iface")
  if [ -n "$cidr" ]; then
    # Extract network portion (e.g., 192.168.1.100/24 -> 192.168.1.0/24)
    python3 -c "
import ipaddress
try:
    net = ipaddress.IPv4Network('$cidr', strict=False)
    print(str(net))
except:
    pass
" 2>/dev/null || echo ""
  fi
}

# List available DNS plugins
list_dns_plugins() {
  if [ -d "$LIB_DIR" ]; then
    find "$LIB_DIR" -name "*.sh" -executable -printf " - %f\n" | sort
  fi
}

ensure_conf_exists() {
  if [ ! -f "$CONF_FILE" ]; then
    echo "=== Virtual Domain $VERSION Setup ==="
    echo "How should your dev domains be accessible?"
    echo " [1] Host-only (via loopback interface)"
    echo " [2] LAN-visible (via your main network interface)"
    read -p "Choice [1/2]: " choice

    echo
    echo "Available interfaces:"
    ip -o link show | while read -r line; do
      iface=$(echo "$line" | awk -F': ' '{print $2}')
      ipv4=$(get_interface_info "$iface")
      if [ -n "$ipv4" ]; then
        echo " - $iface ($ipv4)"
      else
        echo " - $iface"
      fi
    done

    if [ "$choice" == "1" ]; then
      mode="local"
      iface="lo"
      subnet="127.10.10.0/24"
    else
      mode="lan"
      read -p "Which interface to use (e.g. eth0): " iface
      
      # Auto-suggest subnet based on interface
      suggested_subnet=$(get_suggested_subnet "$iface")
      if [ -n "$suggested_subnet" ]; then
        read -p "What subnet (detected: $suggested_subnet): " subnet
        subnet=${subnet:-$suggested_subnet}
      else
        read -p "What subnet (e.g. 10.0.1.0/24): " subnet
      fi
    fi

    echo
    echo "Available DNS plugins:"
    list_dns_plugins
    echo " - none (no DNS integration)"
    read -p "DNS plugin name [etc_hosts.sh]: " dns_mode
    dns_mode=${dns_mode:-etc_hosts.sh}
    
    # Convert to full path if it's just a filename
    if [[ "$dns_mode" != "none" && ! "$dns_mode" = /* ]]; then
      dns_mode="$LIB_DIR/$dns_mode"
    fi

    echo "# mode=$mode" | sudo tee "$CONF_FILE"
    echo "# iface=$iface" | sudo tee -a "$CONF_FILE"
    echo "# subnet=$subnet" | sudo tee -a "$CONF_FILE"
    echo "# dns=$dns_mode" | sudo tee -a "$CONF_FILE"
    echo "# domain ip" | sudo tee -a "$CONF_FILE"

    # Initialize the dns plugin
    call_dns_plugin_init
  fi
}

call_dns_plugin() {
  action=$1; domain=$2; ip=$3
  dns_mode=$(get_dns_mode)
  if [[ "$dns_mode" == "none" ]]; then
    return 0
  elif [[ -x "$dns_mode" ]]; then
    "$dns_mode" "$action" "$domain" "$ip"
  else
    echo "Warning: DNS plugin $dns_mode not found or not executable."
    return 1
  fi
}

add_domain() {
  domain=$1; ip=$2
  iface=$(get_iface)
  
  # Call DNS plugin first and respect exit code
  if ! call_dns_plugin add "$domain" "$ip"; then
    echo "Error: DNS plugin failed to add domain $domain. Aborting."
    return 1
  fi
  
  # Only proceed if DNS plugin succeeded
  echo "$domain $ip" | sudo tee -a "$CONF_FILE" > /dev/null
  sudo ip addr add "$ip/32" dev "$iface" || true
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
  if [[ "$1" != "--force" ]]; then
    read -p "⚠️  This will remove all virtual domain config and undo all setup. Are you sure? [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "Aborted."
      exit 1
    fi
  fi

  echo "Removing all virtual domain IPs and DNS entries..."
  down_all_ips

  echo "Removing systemd service (if exists)..."
  sudo systemctl disable virtual-domains.service 2>/dev/null || true
  sudo rm -f /etc/systemd/system/virtual-domains.service
  sudo systemctl daemon-reload

  echo "Informing DNS plugin of teardown..."
  call_dns_plugin_teardown

  echo "Removing $CONF_FILE..."
  sudo rm -f "$CONF_FILE"

  echo "virtual-domains.sh removal complete"
}

list_domains() {
  echo "Configured domains:" && grep -v '^#' "$CONF_FILE"
}

print_usage() {
  echo "virtual-domains.sh $VERSION"
  echo "Usage:"
  echo "  virtual-domains.sh --add domain ip   Add domain"
  echo "  virtual-domains.sh --purge domain    Remove domain"
  echo "  virtual-domains.sh --list            List domains"
  echo "  virtual-domains.sh --up              Re-assign all IPs"
  echo "  virtual-domains.sh --down            Remove all IPs"
  echo "  virtual-domains.sh --install-service Install systemd unit"
  echo "  virtual-domains.sh --teardown        Uninstall everything (with prompt)"
  echo "  virtual-domains.sh --version         Print version"
}

call_dns_plugin_init() {
  dns_mode=$(get_dns_mode)
  if [[ "$dns_mode" == "none" ]]; then return; fi
  if [[ -x "$dns_mode" ]]; then "$dns_mode" init || true; fi
}

call_dns_plugin_teardown() {
  dns_mode=$(get_dns_mode)
  if [[ "$dns_mode" == "none" ]]; then return; fi
  if [[ -x "$dns_mode" ]]; then "$dns_mode" teardown || true; fi
}

### MAIN ###
ensure_conf_exists
case "$1" in
  --add) add_domain "$2" "$3" ;;
  --purge) purge_domain "$2" ;;
  --list) list_domains ;;
  --up) up_all_ips ;;
  --down) down_all_ips ;;
  --install-service) install_service ;;
  --teardown) teardown_all "$2" ;;
  --version) echo "$VERSION" ;;
  *) print_usage ;;
esac
