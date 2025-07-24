#!/usr/bin/env bash

# Fix Servers.nix Import Paths
# This script fixes the incorrect import paths in servers.nix

set -e  # Exit on any error

NIXOS_CONFIG_DIR="/etc/nixos"
SERVERS_FILE="$NIXOS_CONFIG_DIR/modules/services/servers.nix"

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
}

# Show current servers.nix content
show_current_servers() {
    log "Current servers.nix content:"
    echo ""
    if [[ -f "$SERVERS_FILE" ]]; then
        echo "=== Current servers.nix ==="
        cat "$SERVERS_FILE"
        echo "=========================="
    else
        error "servers.nix not found at $SERVERS_FILE"
        return 1
    fi
    echo ""
}

# Check directory structure
check_directory_structure() {
    log "Checking directory structure..."
    echo ""
    echo "📁 Current structure:"
    tree /etc/nixos/modules 2>/dev/null || find /etc/nixos/modules -type f -name "*.nix" | sort
    echo ""
    
    echo "🔍 Path analysis:"
    echo "  servers.nix location: /etc/nixos/modules/services/servers.nix"
    echo "  nginx-vhosts.nix location: /etc/nixos/modules/webserver/nginx-vhosts.nix"
    echo ""
    echo "❌ Current import: ./webserver/nginx-vhosts.nix"
    echo "✅ Correct import: ../webserver/nginx-vhosts.nix"
    echo ""
}

# Fix the import paths
fix_import_paths() {
    log "Fixing import paths in servers.nix..."
    
    # Backup current file
    sudo cp "$SERVERS_FILE" "$SERVERS_FILE.path-fix-backup-$(date +%Y%m%d-%H%M%S)"
    success "Created backup of servers.nix"
    
    # Fix the import path
    sudo sed -i 's|./webserver/nginx-vhosts.nix|../webserver/nginx-vhosts.nix|g' "$SERVERS_FILE"
    
    # Also fix the file header if it's malformed
    if ! head -1 "$SERVERS_FILE" | grep -q "{ config"; then
        log "Fixing malformed file header..."
        
        # Create corrected servers.nix
        sudo tee "$SERVERS_FILE" > /dev/null << 'EOF'
# Services Servers Module
# This module imports all server-related services

{ config, pkgs, lib, ... }:

{
  imports = [
    ./mysql.nix
    ./php.nix
    ./nginx.nix
    ../webserver/nginx-vhosts.nix
  ];
  
  environment.systemPackages = with pkgs; [
    pm2  # Process manager for Node.js applications
  ];
}
EOF
        success "Fixed malformed file header and import paths"
    else
        success "Fixed import paths"
    fi
}

# Test the fixed servers.nix
test_fixed_servers() {
    log "Testing fixed servers.nix..."
    
    # Test syntax
    if nix-instantiate --parse "$SERVERS_FILE" &>/dev/null; then
        success "servers.nix syntax is valid"
    else
        error "servers.nix syntax is invalid"
        nix-instantiate --parse "$SERVERS_FILE" 2>&1 | head -5
        return 1
    fi
    
    # Test with configuration that imports servers.nix
    sudo tee "$NIXOS_CONFIG_DIR/test-servers.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/services/servers.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "25.05";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-servers.nix" &>/dev/null; then
        success "servers.nix imports work correctly!"
        sudo rm -f "$NIXOS_CONFIG_DIR/test-servers.nix"
        return 0
    else
        error "servers.nix still has import issues:"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-servers.nix" 2>&1 | head -10
        sudo rm -f "$NIXOS_CONFIG_DIR/test-servers.nix"
        return 1
    fi
}

# Check if servers.nix is imported in configuration.nix
check_servers_import() {
    log "Checking if servers.nix is imported in configuration.nix..."
    
    if grep -q "servers.nix" "$NIXOS_CONFIG_DIR/configuration.nix"; then
        warning "servers.nix is imported in configuration.nix"
        echo "Found import:"
        grep -n "servers.nix" "$NIXOS_CONFIG_DIR/configuration.nix"
        echo ""
        echo "⚠️  Note: servers.nix duplicates imports that are already in configuration.nix"
        echo "   This could cause conflicts. Consider:"
        echo "   1. Remove servers.nix import from configuration.nix, OR"
        echo "   2. Remove individual service imports and use only servers.nix"
    else
        success "servers.nix is not imported in configuration.nix (good - avoids conflicts)"
    fi
}

# Show final corrected content
show_corrected_content() {
    log "Corrected servers.nix content:"
    echo ""
    echo "=== Corrected servers.nix ==="
    cat "$SERVERS_FILE"
    echo "============================="
    echo ""
}

# Main function
main() {
    echo "🔧 Fix Servers.nix Import Paths"
    echo "==============================="
    echo ""
    
    show_current_servers
    check_directory_structure
    
    echo "The servers.nix file has incorrect import paths."
    echo "This will fix the path from './webserver/' to '../webserver/'"
    echo ""
    
    read -p "Proceed with path fix? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    fix_import_paths
    
    if test_fixed_servers; then
        show_corrected_content
        check_servers_import
        
        echo ""
        echo "🎯 Summary:"
        echo "✅ Fixed import path: ../webserver/nginx-vhosts.nix"
        echo "✅ servers.nix syntax is valid"
        echo "✅ Import paths work correctly"
        echo ""
        echo "📋 Note: servers.nix is a convenience module that imports:"
        echo "  - mysql.nix"
        echo "  - php.nix" 
        echo "  - nginx.nix"
        echo "  - nginx-vhosts.nix"
        echo ""
        echo "You can use either:"
        echo "  1. Import servers.nix (imports all services)"
        echo "  2. Import individual service modules"
        echo "  (But not both to avoid conflicts)"
    else
        error "servers.nix still has issues. Check the error output above."
    fi
}

# Run main function
main "$@"