# virtual-domains

A lightweight Linux tool for assigning virtual IPs to local or LAN-visible domain names for development.

## Features

* Assign local or LAN virtual IPs to development domain names
  * e.g. `dev.mydomain.dom` ➡️ `192.168.1.25`
* Automatically update `/etc/hosts` or pluggable DNS systems
* Nginx reverse proxy integration - automatically proxy domains to localhost ports
* Supports loopback or network interface IPs
* Systemd service for persistence
* Plugin architecture for DNS strategies: etc\_hosts, dnsmasq, mdns (avahi), mikrotik, etc.

## Installation

```sh
sudo make install
```

This installs:

* `virtual-domains` into `/usr/local/bin`
* All `dns-plugins/*.sh` into `/usr/local/lib/virtual-domains/`

## Usage

Note that sudo is typically required.

```sh
virtual-domains add mysite.test 10.0.1.50
virtual-domains remove mysite.test
virtual-domains list
virtual-domains up     # reassign all
virtual-domains down   # remove all
virtual-domains enable-nginx-site   # enable nginx reverse proxy
virtual-domains disable-nginx-site  # disable nginx reverse proxy
virtual-domains install-service
virtual-domains teardown
virtual-domains version
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

## Nginx Reverse Proxy

For HTTP use cases, virtual-domains can configure an existing nginx server to reverse-proxy your domain names to ports on your localhost. You can enable and disable this feature at any time.

When enabled, virtual-domains will:

* Create `/etc/nginx/sites-enabled/virtual-domains` with proxy configurations
* Map each domain to a localhost port (starting at a user-defined port, 10800 by default)
* Automatically reload nginx when domains are added/removed

**Example:** If you add `myapp.test`, it will be proxied to `http://localhost:10800`. The next domain will use port 10801, and so on.

### Configuration

The nginx port offset can be changed by editing `/etc/virtual-domains.conf`:

```conf
# nginx_port_offset=10800  # Change this to start at a different port
```

After changing the port offset, run `enable-nginx-site` to regenerate the nginx configuration.

Disable the nginx feature at any time with `disable-nginx-site`

## Releases

- virtual-domains_0.1.0.deb - July 7, 2025
