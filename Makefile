PREFIX ?= /usr/local
BIN_DIR := $(PREFIX)/bin
LIB_DIR := $(PREFIX)/lib/virtual-domains

all:
	@echo "Run 'sudo make install' to install virtual-domains."

install:
	@if [ ! -w $(PREFIX) ] && [ $$(id -u) -ne 0 ]; then \
		echo "Error: install to $(PREFIX) must be run with root privileges. Please use sudo. Aborting." >&2; \
		exit 1; \
	fi
	install -Dm755 virtual-domains $(BIN_DIR)/virtual-domains
	install -d $(LIB_DIR)
	install -m755 dns-plugins/*.sh $(LIB_DIR)

uninstall:
	@if [ ! -w $(PREFIX) ] && [ $$(id -u) -ne 0 ]; then \
		echo "Error: uninstall at $(PREFIX) must be run with root privileges. Please use sudo. Aborting." >&2; \
		exit 1; \
	fi
	$(BIN_DIR)/virtual-domains --teardown --force || true
	rm -f $(BIN_DIR)/virtual-domains
	rm -rf $(LIB_DIR)
	rm -f /etc/systemd/system/virtual-domains.service
	systemctl daemon-reload || true
