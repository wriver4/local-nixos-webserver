#!/usr/bin/env bash

# Fix PHP Module and Test Configuration
# This script fixes the PHP module that was causing syntax errors

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

# Update PHP module
update_php_module() {
    log "Updating PHP module to fix syntax error..."
    
    if [[ -f "$NIXOS_CONFIG_DIR/modules/services/php.nix" ]]; then
        # Backup the current PHP module
        sudo cp "$NIXOS_CONFIG_DIR/modules/services/php.nix" "$NIXOS_CONFIG_DIR/modules/services/php.nix.backup"
        
        # Install the fixed PHP module
        sudo cp "$SCRIPT_DIR/modules/services/php.nix" "$NIXOS_CONFIG_DIR/modules/services/"
        
        success "PHP module updated (backup saved as php.nix.backup)"
    else
        error "PHP module not found at $NIXOS_CONFIG_DIR/modules/services/php.nix"
    fi
}

# Test individual modules
test_modules() {
    log "Testing individual module syntax..."
    
    # Test networking module
    if nix-instantiate --parse "$NIXOS_CONFIG_DIR/modules/networking.nix" &>/dev/null; then
        success "Networking module syntax is valid"
    else
        error "Networking module has syntax errors"
    fi
    
    # Test PHP module
    if nix-instantiate --parse "$NIXOS_CONFIG_DIR/modules/services/php.nix" &>/dev/null; then
        success "PHP module syntax is valid"
    else
        error "PHP module has syntax errors"
    fi
    
    # Test nginx module
    if nix-instantiate --parse "$NIXOS_CONFIG_DIR/modules/services/nginx.nix" &>/dev/null; then
        success "Nginx module syntax is valid"
    else
        error "Nginx module has syntax errors"
    fi
    
    # Test mysql module
    if nix-instantiate --parse "$NIXOS_CONFIG_DIR/modules/services/mysql.nix" &>/dev/null; then
        success "MySQL module syntax is valid"
    else
        error "MySQL module has syntax errors"
    fi
    
    # Test webserver module
    if nix-instantiate --parse "$NIXOS_CONFIG_DIR/webserver.nix" &>/dev/null; then
        success "Webserver module syntax is valid"
    else
        error "Webserver module has syntax errors"
    fi
}

# Test main configuration
test_main_configuration() {
    log "Testing main NixOS configuration..."
    
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "Main configuration syntax is valid!"
        echo ""
        echo "���� Configuration is ready for deployment!"
        echo ""
        echo "Next steps:"
        echo "1. Run: sudo nixos-rebuild switch"
        echo "2. Access services:"
        echo "   - Dashboard: http://dashboard.local"
        echo "   - phpMyAdmin: http://phpmyadmin.local"
        echo "   - Sample sites: http://sample1.local, etc."
    else
        warning "Main configuration still has issues. Let's see the error:"
        echo ""
        sudo nixos-rebuild dry-build 2>&1 | head -30
        echo ""
        error "Please check the error above and fix manually"
    fi
}

# Main function
main() {
    echo "🔧 Fix PHP Module and Test Configuration"
    echo "======================================="
    echo ""
    
    check_privileges
    
    echo "This script will:"
    echo "  • Update the PHP module to fix the syntax error"
    echo "  • Test all individual modules"
    echo "  • Test the main NixOS configuration"
    echo ""
    
    read -p "Proceed with fix? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Fix cancelled by user"
    fi
    
    update_php_module
    test_modules
    test_main_configuration
}

# Run main function
main "$@"