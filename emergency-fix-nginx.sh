#!/usr/bin/env bash

# Emergency Fix for Nginx Infinite Recursion
# This script replaces nginx.nix with an absolutely minimal version

set -e  # Exit on any error

NIXOS_CONFIG_DIR="/etc/nixos"
NGINX_MODULE="$NIXOS_CONFIG_DIR/modules/services/nginx.nix"

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

# Emergency fix - create absolutely minimal nginx
emergency_fix() {
    log "Creating emergency minimal nginx module..."
    
    # Create backup
    if [[ -f "$NGINX_MODULE" ]]; then
        sudo cp "$NGINX_MODULE" "$NGINX_MODULE.emergency-backup-$(date +%Y%m%d-%H%M%S)"
        success "Created emergency backup"
    fi
    
    # Create absolutely minimal nginx - just enable it, nothing else
    sudo tee "$NGINX_MODULE" > /dev/null << 'EOF'
# Emergency Minimal Nginx Module
# Absolutely minimal configuration to break recursion

{ config, pkgs, lib, ... }:

{
  # Just enable nginx with minimal config
  services.nginx.enable = true;
  
  # Open ports
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
EOF

    success "Created emergency minimal nginx module"
}

# Test the emergency fix
test_emergency_fix() {
    log "Testing emergency nginx fix..."
    
    # Test syntax
    if nix-instantiate --parse "$NGINX_MODULE" &>/dev/null; then
        success "Emergency nginx syntax is valid"
    else
        error "Emergency nginx still has syntax errors"
        return 1
    fi
    
    # Test full config
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "🎉 Emergency fix successful! Recursion resolved."
        echo ""
        echo "✅ You can now rebuild with:"
        echo "   sudo nixos-rebuild switch --upgrade --impure"
        echo ""
        echo "⚠️  Note: This is minimal nginx. You'll need to add virtual hosts separately."
        return 0
    else
        warning "Still has issues. Let's see what's left:"
        sudo nixos-rebuild dry-build 2>&1 | head -15
        return 1
    fi
}

# Create step-by-step nginx builder
create_step_builder() {
    log "Creating step-by-step nginx builder..."
    
    # Create a script to add nginx features incrementally
    sudo tee "$NIXOS_CONFIG_DIR/build-nginx-step-by-step.sh" > /dev/null << 'EOF'
#!/bin/bash
# Step-by-step nginx builder
# Add features one at a time to avoid recursion

NGINX_MODULE="/etc/nixos/modules/services/nginx.nix"

echo "🔧 Step-by-step nginx builder"
echo "Current nginx module is minimal. Choose what to add:"
echo ""
echo "1. Add basic configuration (user, worker settings)"
echo "2. Add HTTP optimization (gzip, caching)"
echo "3. Add security headers"
echo "4. Add virtual hosts support"
echo "5. Show current nginx module"
echo ""

read -p "Enter choice (1-5): " choice

case $choice in
    1)
        echo "Adding basic configuration..."
        sudo tee "$NGINX_MODULE" > /dev/null << 'BASIC'
# Basic Nginx Module
{ config, pkgs, lib, ... }:
{
  services.nginx = {
    enable = true;
    user = "nginx";
    group = "nginx";
    appendConfig = ''
      worker_processes auto;
      worker_connections 1024;
    '';
  };
  
  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
  };
  users.groups.nginx = {};
  
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
BASIC
        echo "✅ Added basic configuration"
        ;;
    2)
        echo "Adding HTTP optimization..."
        # Add to existing config...
        ;;
    5)
        echo "Current nginx module:"
        cat "$NGINX_MODULE"
        ;;
    *)
        echo "Invalid choice"
        ;;
esac

echo ""
echo "Test with: sudo nixos-rebuild dry-build"
EOF

    sudo chmod +x "$NIXOS_CONFIG_DIR/build-nginx-step-by-step.sh"
    success "Created step-by-step builder at /etc/nixos/build-nginx-step-by-step.sh"
}

# Show what to do next
show_next_steps() {
    echo ""
    echo "🎯 Next Steps:"
    echo ""
    echo "1. **Test the emergency fix:**"
    echo "   sudo nixos-rebuild switch --upgrade --impure"
    echo ""
    echo "2. **Add virtual hosts manually:**"
    echo "   Create a separate virtual-hosts.nix module"
    echo ""
    echo "3. **Use the step-by-step builder:**"
    echo "   sudo /etc/nixos/build-nginx-step-by-step.sh"
    echo ""
    echo "4. **Test after each addition:**"
    echo "   sudo nixos-rebuild dry-build"
    echo ""
    echo "📋 Current nginx module location:"
    echo "   $NGINX_MODULE"
    echo ""
    echo "🔄 To restore from backup:"
    echo "   sudo cp $NGINX_MODULE.emergency-backup-* $NGINX_MODULE"
}

# Main function
main() {
    echo "🚨 Emergency Nginx Recursion Fix"
    echo "==============================="
    echo ""
    
    echo "This will replace nginx.nix with an absolutely minimal version"
    echo "to break the infinite recursion immediately."
    echo ""
    
    read -p "Proceed with emergency fix? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Emergency fix cancelled"
    fi
    
    emergency_fix
    
    if test_emergency_fix; then
        create_step_builder
        show_next_steps
        
        echo ""
        echo "🎉 Emergency fix complete!"
        echo "The infinite recursion should be resolved."
        echo "You can now rebuild your system safely."
    else
        echo ""
        echo "❌ Emergency fix didn't resolve all issues."
        echo "There may be other modules causing recursion."
        echo "Check the error output above."
    fi
}

# Run main function
main "$@"