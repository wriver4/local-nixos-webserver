#!/usr/bin/env bash

# Fix Nginx Infinite Recursion (Final Fix)
# This script fixes the nginx service module that's causing infinite recursion

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
}

# Show current nginx module
show_current_nginx() {
    log "Current nginx module causing recursion:"
    echo ""
    if [[ -f "$NGINX_MODULE" ]]; then
        echo "=== Current nginx.nix ==="
        cat "$NGINX_MODULE"
        echo "========================="
    else
        error "Nginx module not found"
    fi
    echo ""
}

# Create absolutely minimal nginx module
create_minimal_nginx() {
    log "Creating minimal nginx module without recursion..."
    
    # Backup current module
    if [[ -f "$NGINX_MODULE" ]]; then
        sudo cp "$NGINX_MODULE" "$NGINX_MODULE.recursion-backup-$(date +%Y%m%d-%H%M%S)"
        success "Backed up current nginx module"
    fi
    
    # Create minimal nginx module
    sudo tee "$NGINX_MODULE" > /dev/null << 'EOF'
# Minimal Nginx Service Module (No Recursion)
# This module provides basic nginx service without circular references

{ config, pkgs, lib, ... }:

{
  # Basic nginx service - no complex configurations
  services.nginx.enable = lib.mkDefault true;
  
  # Open firewall ports
  networking.firewall.allowedTCPPorts = lib.mkAfter [ 80 443 ];
  
  # Ensure nginx user exists
  users.users.nginx = lib.mkIf (!config.users.users ? nginx) {
    isSystemUser = true;
    group = "nginx";
    description = "Nginx web server user";
  };
  
  users.groups.nginx = lib.mkIf (!config.users.groups ? nginx) {};
}
EOF

    success "Created minimal nginx module"
}

# Fix system.stateVersion in configuration.nix
fix_state_version() {
    log "Fixing system.stateVersion to 25.05..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    
    if [[ -f "$config_file" ]]; then
        # Update stateVersion from 23.11 to 25.05
        sudo sed -i 's/system\.stateVersion = "23\.11"/system.stateVersion = "25.05"/' "$config_file"
        
        # Also check for other common old versions
        sudo sed -i 's/system\.stateVersion = "24\.05"/system.stateVersion = "25.05"/' "$config_file"
        sudo sed -i 's/system\.stateVersion = "24\.11"/system.stateVersion = "25.05"/' "$config_file"
        
        success "Updated system.stateVersion to 25.05"
        
        # Show the change
        echo "Current stateVersion:"
        grep "system\.stateVersion" "$config_file" || echo "No stateVersion found"
    else
        error "configuration.nix not found"
    fi
}

# Test the fixed nginx module
test_nginx_fix() {
    log "Testing fixed nginx module..."
    
    # Test nginx module syntax
    if nix-instantiate --parse "$NGINX_MODULE" &>/dev/null; then
        success "Nginx module syntax is valid"
    else
        error "Nginx module syntax is invalid"
        return 1
    fi
    
    # Test with just nginx module
    sudo tee "$NIXOS_CONFIG_DIR/test-nginx-fixed.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/services/nginx.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "25.05";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-nginx-fixed.nix" &>/dev/null; then
        success "Fixed nginx module works!"
        sudo rm -f "$NIXOS_CONFIG_DIR/test-nginx-fixed.nix"
        return 0
    else
        error "Fixed nginx module still has issues:"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-nginx-fixed.nix" 2>&1 | head -10
        sudo rm -f "$NIXOS_CONFIG_DIR/test-nginx-fixed.nix"
        return 1
    fi
}

# Test incremental build
test_incremental_build() {
    log "Testing incremental module addition..."
    
    echo "Testing: hardware + networking + nginx..."
    sudo tee "$NIXOS_CONFIG_DIR/test-incremental.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/networking.nix
    ./modules/services/nginx.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "25.05";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-incremental.nix" &>/dev/null; then
        success "✅ hardware + networking + nginx work together"
        
        echo "Testing: + PHP..."
        sudo sed -i '/modules\/services\/nginx.nix/a\    ./modules/services/php.nix' "$NIXOS_CONFIG_DIR/test-incremental.nix"
        
        if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-incremental.nix" &>/dev/null; then
            success "✅ + PHP works"
            
            echo "Testing: + MySQL..."
            sudo sed -i '/modules\/services\/php.nix/a\    ./modules/services/mysql.nix' "$NIXOS_CONFIG_DIR/test-incremental.nix"
            
            if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-incremental.nix" &>/dev/null; then
                success "✅ + MySQL works"
                
                echo "Testing: + nginx-vhosts..."
                sudo sed -i '/modules\/services\/mysql.nix/a\    ./modules/webserver/nginx-vhosts.nix' "$NIXOS_CONFIG_DIR/test-incremental.nix"
                
                if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-incremental.nix" &>/dev/null; then
                    success "✅ + nginx-vhosts works"
                    
                    echo "Testing: + php-optimization..."
                    sudo sed -i '/modules\/webserver\/nginx-vhosts.nix/a\    ./modules/webserver/php-optimization.nix' "$NIXOS_CONFIG_DIR/test-incremental.nix"
                    
                    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-incremental.nix" &>/dev/null; then
                        success "🎉 ALL MODULES WORK TOGETHER!"
                        return 0
                    else
                        error "❌ php-optimization causes issues"
                    fi
                else
                    error "❌ nginx-vhosts causes issues"
                fi
            else
                error "❌ MySQL causes issues"
            fi
        else
            error "❌ PHP causes issues"
        fi
    else
        error "❌ Still have issues with hardware + networking + nginx"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-incremental.nix" 2>&1 | head -5
    fi
    
    sudo rm -f "$NIXOS_CONFIG_DIR/test-incremental.nix"
    return 1
}

# Create final working configuration
create_final_config() {
    log "Creating final working configuration..."
    
    # Backup current config
    sudo cp "$NIXOS_CONFIG_DIR/configuration.nix" "$NIXOS_CONFIG_DIR/configuration.nix.final-backup-$(date +%Y%m%d-%H%M%S)"
    
    # Create working configuration
    sudo tee "$NIXOS_CONFIG_DIR/configuration.nix" > /dev/null << 'EOF'
# Final Working NixOS Configuration
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/networking.nix
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    ./modules/services/mysql.nix
    ./modules/webserver/nginx-vhosts.nix
    ./modules/webserver/php-optimization.nix
  ];

  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # User configuration
  users.users.webadmin = {
    isNormalUser = true;
    description = "Web Administrator";
    extraGroups = [ "wheel" "nginx" ];
  };

  # Basic system packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    tree
    htop
  ];

  # Enable SSH
  services.openssh.enable = true;

  system.stateVersion = "25.05";
}
EOF

    success "Created final working configuration"
}

# Main function
main() {
    echo "🔧 Fix Nginx Infinite Recursion (Final Fix)"
    echo "==========================================="
    echo ""
    
    echo "You've identified that the nginx service module causes infinite recursion."
    echo "This will create a minimal nginx module and fix the state version."
    echo ""
    
    read -p "Proceed with nginx fix? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    show_current_nginx
    create_minimal_nginx
    fix_state_version
    
    if test_nginx_fix; then
        if test_incremental_build; then
            create_final_config
            
            echo ""
            echo "🎉 SUCCESS! All modules work together!"
            echo ""
            echo "🎯 Next steps:"
            echo "1. Test: sudo nixos-rebuild dry-build --impure"
            echo "2. Apply: sudo nixos-rebuild switch --impure"
            echo "3. Your modular webserver will be active!"
            echo ""
            echo "✅ Features:"
            echo "  - nginx-vhosts.nix for virtual hosts"
            echo "  - php-optimization.nix for PHP 8.4 tuning"
            echo "  - Proper NixOS service integration"
            echo "  - No more infinite recursion!"
        else
            warning "Some modules still have issues. Check the output above."
        fi
    else
        error "Nginx fix didn't work. Check the error output above."
    fi
}

# Run main function
main "$@"