# virtual-domains.sh

A lightweight Linux tool for assigning local or LAN-visible IPs to domain names for development.

## Features

* Assign local or LAN IPs to development domain names
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
sudo virtual-domains.sh mysite.test 10.0.1.50
sudo virtual-domains.sh --purge mysite.test
sudo virtual-domains.sh --list
sudo virtual-domains.sh --up     # reassign all
sudo virtual-domains.sh --down   # remove all
sudo virtual-domains.sh --install-service
sudo virtual-domains.sh --teardown
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

* `etc_hosts.sh` (modifies /etc/hosts)
* `mdns.sh` (publishes .local domains via avahi)

You choose the plugin path or name during initial setup.
