PREFIX ?= /usr/local
BIN_DIR := $(PREFIX)/bin
LIB_DIR := $(PREFIX)/lib/virtual-domains

all:
	@echo "Run 'sudo make install' to install virtual-domains."

install:
	install -Dm755 virtual-domains.sh $(BIN_DIR)/virtual-domains.sh
	install -d $(LIB_DIR)
	install -m755 dns-plugins/*.sh $(LIB_DIR)

uninstall:
	$(BIN_DIR)/virtual-domains.sh --teardown --force || true
	rm -f $(BIN_DIR)/virtual-domains.sh
	rm -rf $(LIB_DIR)
	rm -f /etc/systemd/system/virtual-domains.service
	systemctl daemon-reload || true
