#!/usr/bin/env bash

# Fix Installed PHP Module
# This script removes the problematic services.phpfpm.enable line

set -e  # Exit on any error

NIXOS_CONFIG_DIR="/etc/nixos"
PHP_MODULE="$NIXOS_CONFIG_DIR/modules/services/php.nix"

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

# Check if PHP module exists
if [[ ! -f "$PHP_MODULE" ]]; then
    error "PHP module not found at $PHP_MODULE"
fi

log "Fixing PHP module by removing services.phpfpm.enable..."

# Create backup
sudo cp "$PHP_MODULE" "$PHP_MODULE.backup-$(date +%Y%m%d-%H%M%S)"
success "Created backup of PHP module"

# Remove the problematic line
sudo sed -i '/services\.phpfpm[[:space:]]*=[[:space:]]*{/,/enable[[:space:]]*=[[:space:]]*lib\.mkDefault[[:space:]]*true;/s/enable[[:space:]]*=[[:space:]]*lib\.mkDefault[[:space:]]*true;//' "$PHP_MODULE"

# Also remove any standalone enable line
sudo sed -i '/^[[:space:]]*enable[[:space:]]*=[[:space:]]*lib\.mkDefault[[:space:]]*true;[[:space:]]*$/d' "$PHP_MODULE"

# Remove any enable = true line in phpfpm block
sudo sed -i '/services\.phpfpm/,/^[[:space:]]*};/{/enable[[:space:]]*=/d}' "$PHP_MODULE"

success "Removed problematic enable line from PHP module"

# Test the syntax
log "Testing PHP module syntax..."
if nix-instantiate --parse "$PHP_MODULE" &>/dev/null; then
    success "PHP module syntax is valid"
else
    error "PHP module still has syntax errors"
fi

# Test the full configuration
log "Testing full configuration..."
if sudo nixos-rebuild dry-build &>/dev/null; then
    success "Configuration is valid! Ready to rebuild."
    echo ""
    echo "🎉 You can now run:"
    echo "   sudo nixos-rebuild switch --upgrade --impure"
else
    warning "Configuration still has issues. Let's see the error:"
    sudo nixos-rebuild dry-build 2>&1 | head -20
fi