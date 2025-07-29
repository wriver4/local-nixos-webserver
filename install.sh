#!/usr/bin/env bash
# Quick installation script

set -e

echo "🚀 NixOS Web Server Quick Install"
echo "=================================="

# Check if NixOS
if [[ ! -f /etc/NIXOS ]]; then
    echo "❌ This installer is for NixOS systems only."
    exit 1
fi

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "📦 Installing git..."
    nix-env -iA nixpkgs.git
fi

# Clone or update repository
if [[ -d "nixos-webserver" ]]; then
    echo "📁 Updating existing installation..."
    cd nixos-webserver
    git pull
else
    echo "📥 Cloning repository..."
    git clone https://github.com/your-username/nixos-webserver.git
    cd nixos-webserver
fi

# Choose installation method
echo ""
echo "Choose installation method:"
echo "1) Traditional Nix package"
echo "2) Flakes (recommended)"
echo "3) Manual installation"
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        echo "📦 Installing via Nix package..."
        nix-env -i -f default.nix
        nixos-webserver-setup
        ;;
    2)
        echo "❄️ Installing via Flakes..."
        if ! nix flake --version &> /dev/null; then
            echo "❌ Flakes not enabled. Enable with:"
            echo "   nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];"
            exit 1
        fi
        nix profile install .
        ;;
    3)
        echo "🔧 Running manual installation..."
        chmod +x install-on-existing-nixos.sh
        ./install-on-existing-nixos.sh
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "1. Review your /etc/nixos/configuration.nix"
echo "2. Run: sudo nixos-rebuild switch"
echo "3. Access your sites:"
echo "   • Dashboard: http://dashboard.local"
echo "   • phpMyAdmin: http://phpmyadmin.local"
echo "   • Sample sites: http://sample1.local, http://sample2.local, http://sample3.local"
