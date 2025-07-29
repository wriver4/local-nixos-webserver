# Makefile for easy management
.PHONY: build install clean test help

# Default target
help:
	@echo "NixOS Web Server - Available targets:"
	@echo "  build     - Build the package"
	@echo "  install   - Install the package"
	@echo "  clean     - Clean build artifacts"
	@echo "  test      - Test the configuration"
	@echo "  flake     - Build with flakes"
	@echo "  shell     - Enter development shell"

build:
	@echo "🔨 Building NixOS Web Server package..."
	nix-build

install: build
	@echo "📦 Installing NixOS Web Server..."
	nix-env -i -f default.nix

clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf result result-*
	nix-collect-garbage

test:
	@echo "🧪 Testing NixOS configuration..."
	sudo nixos-rebuild dry-build

flake:
	@echo "❄️ Building with flakes..."
	nix build

shell:
	@echo "🐚 Entering development shell..."
	nix-shell

# Development targets
dev-install:
	@echo "🚀 Development installation..."
	./install-on-existing-nixos.sh --interactive

dev-rebuild:
	@echo "🔄 Rebuilding NixOS configuration..."
	sudo nixos-rebuild switch

dev-test-sites:
	@echo "🌐 Testing site accessibility..."
	@for site in dashboard.local phpmyadmin.local sample1.local sample2.local sample3.local; do \
		echo -n "Testing $$site: "; \
		if curl -s -o /dev/null -w "%{http_code}" "http://$$site" | grep -q "200\|302"; then \
			echo "✅ OK"; \
		else \
			echo "❌ Failed"; \
		fi; \
	done
