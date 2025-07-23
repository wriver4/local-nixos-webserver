#!/usr/bin/env bash

# Fix Flake Configuration for Webserver
# This script fixes the webserver configuration to work properly with flake setup

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_CONFIG_DIR="/etc/nixos"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Check privileges
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        SUDO_CMD=""
        success "Running as root"
    else
        if ! command -v sudo &> /dev/null; then
            error "This script requires root privileges or sudo access."
        fi
        
        if ! sudo -n true 2>/dev/null; then
            log "This script requires sudo access. You may be prompted for your password."
            if ! sudo -v; then
                error "Failed to obtain sudo privileges"
            fi
        fi
        SUDO_CMD="sudo"
        success "Sudo access confirmed"
    fi
}

# Check flake setup
check_flake_setup() {
    log "Checking flake setup..."
    
    if [[ -f "$NIXOS_CONFIG_DIR/flake.nix" ]]; then
        success "Found flake.nix - using flake-based configuration"
        
        # Check if webserver.nix is imported in configuration.nix
        if grep -q "webserver.nix" "$NIXOS_CONFIG_DIR/configuration.nix"; then
            success "webserver.nix is imported in configuration.nix"
        else
            warning "webserver.nix is not imported in configuration.nix"
            echo "You'll need to add './webserver.nix' to your imports in configuration.nix"
        fi
    else
        error "No flake.nix found. This script is for flake-based setups."
    fi
}

# Update webserver.nix to be flake-compatible
update_webserver_module() {
    log "Updating webserver.nix for flake compatibility..."
    
    # Create a flake-compatible webserver.nix
    sudo tee "$NIXOS_CONFIG_DIR/webserver.nix" > /dev/null << 'EOF'
# Main Web Server Module for Flake-based NixOS
# This module imports webserver-specific services and configurations
# Compatible with flake-based setups (no hardware-configuration.nix import)

{ config, pkgs, lib, ... }:

{
  imports = [
    # Import networking configuration
    ./modules/networking.nix
    
    # Import webserver-specific modules from the webserver directory
    ./modules/webserver/nginx-vhosts.nix
    ./modules/webserver/php-optimization.nix
    
    # Import enhanced service modules
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    ./modules/services/mysql.nix
  ];

  # High-level webserver coordination
  # This ensures all webserver components work together
  
  # System packages for web development
  environment.systemPackages = with pkgs; [
    tree
    htop
    php  # In NixOS 25.05, 'php' = PHP 8.4
  ];

  # Ensure web directories exist
  system.activationScripts.webserver-setup = ''
    # Create web directories
    mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}
    chown -R nginx:nginx /var/www
    chmod -R 755 /var/www
  '';
}
EOF

    success "Updated webserver.nix for flake compatibility"
}

# Check configuration.nix imports
check_configuration_imports() {
    log "Checking configuration.nix imports..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    
    if [[ -f "$config_file" ]]; then
        echo "Current imports in configuration.nix:"
        grep -A 10 "imports.*=.*\[" "$config_file" | head -15
        echo ""
        
        if ! grep -q "webserver.nix" "$config_file"; then
            warning "webserver.nix is not imported in configuration.nix"
            echo ""
            read -p "Would you like to add webserver.nix to imports? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                add_webserver_import
            fi
        else
            success "webserver.nix is already imported"
        fi
    else
        error "configuration.nix not found"
    fi
}

# Add webserver import to configuration.nix
add_webserver_import() {
    log "Adding webserver.nix to configuration.nix imports..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    
    # Add webserver.nix to imports
    sudo sed -i '/imports = \[/a\    ./webserver.nix' "$config_file"
    
    success "Added webserver.nix to imports"
}

# Test configuration
test_configuration() {
    log "Testing flake configuration..."
    
    # Test with flake
    if sudo nixos-rebuild dry-build --flake "$NIXOS_CONFIG_DIR#king" &>/dev/null; then
        success "Flake configuration is valid!"
        echo ""
        echo "🎉 Configuration is ready for deployment!"
        echo ""
        echo "Next steps:"
        echo "1. Run: sudo nixos-rebuild switch --flake /etc/nixos#king"
        echo "2. Access services:"
        echo "   - Dashboard: http://dashboard.local"
        echo "   - phpMyAdmin: http://phpmyadmin.local"
        echo "   - Sample sites: http://sample1.local, etc."
    else
        warning "Configuration still has issues. Let's see the error:"
        echo ""
        sudo nixos-rebuild dry-build --flake "$NIXOS_CONFIG_DIR#king" 2>&1 | head -30
        echo ""
        error "Please check the error above"
    fi
}

# Show current configuration structure
show_structure() {
    log "Current configuration structure:"
    echo ""
    echo "/etc/nixos/"
    echo "├── flake.nix                           # Flake configuration"
    echo "├── configuration.nix                   # Main config"
    echo "├── hardware-configuration.nix          # Hardware config"
    echo "├── webserver.nix                      # Webserver module"
    echo "└── modules/"
    echo "    ├── networking.nix                 # Networking config"
    echo "    ├── services/"
    echo "    │   ├── nginx.nix                  # Nginx service"
    echo "    │   ├── php.nix                    # PHP-FPM service"
    echo "    │   └── mysql.nix                  # MySQL service"
    echo "    └── webserver/"
    echo "        ├── nginx-vhosts.nix          # Virtual hosts"
    echo "        └── php-optimization.nix      # PHP optimization"
    echo ""
}

# Main function
main() {
    echo "🔧 Fix Flake Configuration for Webserver"
    echo "========================================"
    echo ""
    
    check_privileges
    check_flake_setup
    
    echo "This script will:"
    echo "  • Update webserver.nix for flake compatibility"
    echo "  • Check configuration.nix imports"
    echo "  • Test the flake configuration"
    echo ""
    
    read -p "Proceed with fix? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Fix cancelled by user"
    fi
    
    update_webserver_module
    check_configuration_imports
    show_structure
    test_configuration
}

# Run main function
main "$@"