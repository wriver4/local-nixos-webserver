#!/usr/bin/env bash

# Fix Ownership Issue
# This script fixes the ownership of the project files

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_CONFIG_DIR="/etc/nixos"
PHP_OPT_MODULE="$NIXOS_CONFIG_DIR/modules/webserver/php-optimization.nix"
PROJECT_PHP_OPT="$SCRIPT_DIR/modules/webserver/php-optimization.nix"

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

# Get current user info
get_user_info() {
    local current_user=$(whoami)
    local current_group=$(id -gn)
    
    echo "Current user: $current_user"
    echo "Primary group: $current_group"
    echo ""
    
    # Return the correct ownership string
    echo "$current_user:$current_group"
}

# Fix the project module ownership
fix_project_module() {
    log "Fixing project module ownership..."
    
    local ownership=$(get_user_info | tail -1)
    echo "Using ownership: $ownership"
    
    if [[ -f "$PHP_OPT_MODULE" ]]; then
        # Copy the fixed version back to project
        sudo cp "$PHP_OPT_MODULE" "$PROJECT_PHP_OPT"
        
        # Fix ownership with correct user:group
        sudo chown "$ownership" "$PROJECT_PHP_OPT"
        
        success "Updated project module with correct ownership"
    else
        error "System module not found at $PHP_OPT_MODULE"
        return 1
    fi
}

# Test the configuration
test_configuration() {
    log "Testing configuration..."
    
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "Configuration is valid!"
        return 0
    else
        warning "Configuration still has issues:"
        sudo nixos-rebuild dry-build 2>&1 | head -10
        return 1
    fi
}

# Main function
main() {
    echo "🔧 Fix Ownership Issue"
    echo "====================="
    echo ""
    
    fix_project_module
    
    if test_configuration; then
        echo ""
        echo "🎯 Success! You can now run:"
        echo "  sudo nixos-rebuild switch"
        echo ""
        echo "This will activate your modular nginx setup with:"
        echo "  ✅ nginx-vhosts.nix for virtual hosts"
        echo "  ✅ php-optimization.nix for PHP tuning"
        echo "  ✅ Proper NixOS service integration"
    else
        error "Configuration test failed. Check the error output above."
    fi
}

# Run main function
main "$@"