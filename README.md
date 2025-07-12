# virtual-domains

A lightweight Linux tool for assigning virtual IPs to local or LAN-visible domain names for development.

## Features

* Assign virtual IPs and domain names to your localhost
  * e.g. `dev.mydomain.dom` ➡️ `192.168.1.25`
* Automatically update `/etc/hosts` or use a DNS plugin
* For HTTP use, automatic configuration of Nginx reverse proxy, directing domains to localhost ports
* Choose your ethernet interface
* Systemd service for persistence after reboot

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
Usage:
  virtual-domains add domain ip       Add domain
  virtual-domains remove domain       Remove domain
  virtual-domains list                List domains
  virtual-domains up                  Re-assign all IPs
  virtual-domains down                Remove all IPs
  virtual-domains enable-nginx-site   Enable nginx reverse proxy
  virtual-domains disable-nginx-site  Disable nginx reverse proxy
  virtual-domains install-service     Install systemd unit
  virtual-domains teardown            Uninstall everything (with prompt)
  virtual-domains version             Print version
```

## DNS Plugins

`virtual-domains` supports a variety of DNS solutions through the use of plugins. The plugin
scripts are called via hooks, to keep your DNS up to date with your domain names / IP addresses.

The following DNS plugins are included, right out of the box, and can be selected at setup:

* `etc_hosts.sh` - Modifies `/etc/hosts` for pure local development (domains only visible to your machine.)
* `dnsmasq.sh` - Sets up a simple dnsmasq server (domains visible to any clients of this DNS server.)
* `mdns.sh` - Publishes `.local` domains via `avahi-daemon` / `avahi-publish` (domains visible to anyone on your LAN. Generally only compatible with `.local` domains.) 
* `mikrotik.sh` - Uses ssh to set DNS entries in Mikrotik RouterOS v6+ routers (domains visible to anyone on your LAN. Supports any domain.)

### DNS Plugin Development

To develop your own DNS plugin, it must respond to the following calls:

```sh
/path/to/plugin.sh init
/path/to/plugin.sh teardown
/path/to/plugin.sh add <domain> <ip>
/path/to/plugin.sh remove <domain>
```

At teardown time, remove will be called for each configured domain, so teardown only needs to cleanup things setup via init.

The plugin is expected to manage its own reboot sensitivity / persistence.

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

- v0.1.0 : July 7, 2025 : Initial release
