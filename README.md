# virtual-domains.sh

A lightweight Linux tool for assigning virtual IPs to local or LAN-visible domain names for development.

## Features

* Assign local or LAN virtual IPs to development domain names
  * e.g. `dev.mydomain.dom` ➡️ `192.168.1.25`
* Automatically update `/etc/hosts` or pluggable DNS systems
* Supports loopback or network interface IPs
* Systemd service for persistence
* Plugin architecture for DNS strategies: etc\_hosts, dnsmasq, mdns (avahi), mikrotik, etc.

## Installation

```sh
sudo make install
```

This installs:

* `virtual-domains.sh` into `/usr/local/bin`
* All `dns-plugins/*.sh` into `/usr/local/lib/virtual-domains/`

## Usage

```sh
sudo virtual-domains.sh --add mysite.test 10.0.1.50
sudo virtual-domains.sh --purge mysite.test
sudo virtual-domains.sh --list
sudo virtual-domains.sh --up     # reassign all
sudo virtual-domains.sh --down   # remove all
sudo virtual-domains.sh --install-service
sudo virtual-domains.sh --teardown
sudo virtual-domains.sh --version
```

## DNS Plugin Interface

A plugin must respond to the following calls:

```sh
/path/to/plugin.sh init
/path/to/plugin.sh teardown
/path/to/plugin.sh add <domain> <ip>
/path/to/plugin.sh remove <domain>
```

Available plugins:

* etc_hosts.sh - Modifies `/etc/hosts` for pure local development
* dnsmasq.sh - Sets up a simple dnsmasq server
* mdns.sh - Publishes `.local` domains via avahi-daemon / avahi-publish
* mikrotik.sh - Sets DNS entries in Mikrotik RouterOS v6+ routers

You choose the plugin path or name during initial setup.
