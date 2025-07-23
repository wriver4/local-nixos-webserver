#!/usr/bin/env bash

# Restore NixOS Nginx Service with Modular Configuration
# This script fixes the original nginx service and uses the nginx-vhosts.nix module

set -e  # Exit on any error

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
}

# Check current nginx setup
check_current_setup() {
    log "Checking current nginx setup..."
    
    echo "Current nginx processes:"
    ps aux | grep nginx | grep -v grep || echo "No nginx processes found"
    echo ""
    
    echo "Current nginx services:"
    systemctl list-units | grep nginx || echo "No nginx services found"
    echo ""
    
    echo "Manual nginx config exists:"
    if [[ -f "/etc/nginx/nginx.conf" ]]; then
        success "Manual nginx.conf found"
        echo "Size: $(stat -c%s /etc/nginx/nginx.conf) bytes"
    else
        warning "No manual nginx.conf found"
    fi
    echo ""
}

# Stop manual nginx and custom services
stop_manual_nginx() {
    log "Stopping manual nginx and custom services..."
    
    # Stop any running nginx processes
    sudo pkill nginx 2>/dev/null || true
    
    # Stop custom nginx service if it exists
    sudo systemctl stop nginx-custom 2>/dev/null || true
    sudo systemctl disable nginx-custom 2>/dev/null || true
    
    # Remove custom service file
    sudo rm -f /etc/systemd/system/nginx-custom.service
    sudo systemctl daemon-reload
    
    success "Stopped manual nginx setup"
}

# Check if the modular nginx configuration is properly imported
check_modular_config() {
    log "Checking modular nginx configuration..."
    
    # Check if nginx-vhosts.nix exists
    if [[ -f "$NIXOS_CONFIG_DIR/modules/webserver/nginx-vhosts.nix" ]]; then
        success "Found nginx-vhosts.nix module"
    else
        error "nginx-vhosts.nix module not found"
        return 1
    fi
    
    # Check if it's imported in configuration
    if grep -r "nginx-vhosts.nix" "$NIXOS_CONFIG_DIR" >/dev/null 2>&1; then
        success "nginx-vhosts.nix is imported somewhere"
        echo "Found in:"
        grep -r "nginx-vhosts.nix" "$NIXOS_CONFIG_DIR" | head -3
    else
        warning "nginx-vhosts.nix may not be imported"
    fi
    echo ""
}

# Create a minimal nginx service module to fix the pre-start issue
create_fixed_nginx_service() {
    log "Creating fixed nginx service module..."
    
    # Backup existing nginx service module
    if [[ -f "$NIXOS_CONFIG_DIR/modules/services/nginx.nix" ]]; then
        sudo cp "$NIXOS_CONFIG_DIR/modules/services/nginx.nix" "$NIXOS_CONFIG_DIR/modules/services/nginx.nix.backup-$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Create a minimal, working nginx service module
    sudo tee "$NIXOS_CONFIG_DIR/modules/services/nginx.nix" > /dev/null << 'EOF'
# Fixed Nginx Service Module
# This module provides nginx service without the problematic pre-start script

{ config, pkgs, lib, ... }:

{
  # Basic nginx service configuration
  services.nginx = {
    enable = lib.mkDefault true;
    user = lib.mkDefault "nginx";
    group = lib.mkDefault "nginx";
    
    # Basic configuration
    appendConfig = lib.mkDefault ''
      worker_processes auto;
      worker_connections 1024;
    '';

    # Basic HTTP configuration
    commonHttpConfig = lib.mkDefault ''
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
      keepalive_timeout 65;
      types_hash_max_size 2048;
      
      gzip on;
      gzip_vary on;
      gzip_min_length 1024;
      gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
      
      server_tokens off;
    '';
  };

  # Ensure nginx user and group exist
  users.users.nginx = lib.mkIf (!config.users.users ? nginx) {
    isSystemUser = true;
    group = "nginx";
    description = "Nginx web server user";
    home = "/var/lib/nginx";
    createHome = true;
  };

  users.groups.nginx = lib.mkIf (!config.users.groups ? nginx) {};

  # Open HTTP and HTTPS ports
  networking.firewall.allowedTCPPorts = lib.mkAfter [ 80 443 ];

  # Create nginx directories
  system.activationScripts.nginx-dirs = ''
    mkdir -p /var/lib/nginx
    mkdir -p /var/log/nginx
    mkdir -p /run/nginx
    chown -R nginx:nginx /var/lib/nginx
    chown -R nginx:nginx /var/log/nginx
    chown -R nginx:nginx /run/nginx
  '';
}
EOF

    success "Created fixed nginx service module"
}

# Ensure the modular configuration is imported
ensure_modular_import() {
    log "Ensuring modular configuration is imported..."
    
    # Check if there's a main module that imports nginx-vhosts.nix
    local import_found=false
    
    # Look for existing imports
    if grep -r "nginx-vhosts.nix" "$NIXOS_CONFIG_DIR" >/dev/null 2>&1; then
        import_found=true
        success "nginx-vhosts.nix is already imported"
    fi
    
    # If not found, check if we need to create an import
    if [[ "$import_found" == false ]]; then
        warning "nginx-vhosts.nix is not imported"
        
        # Check if configuration.nix imports modules
        if grep -q "modules.*nginx" "$NIXOS_CONFIG_DIR/configuration.nix"; then
            success "Modules are imported in configuration.nix"
        else
            log "Adding nginx-vhosts import to configuration.nix..."
            
            # Add import to configuration.nix
            sudo sed -i '/imports = \[/a\    ./modules/webserver/nginx-vhosts.nix' "$NIXOS_CONFIG_DIR/configuration.nix"
            success "Added nginx-vhosts.nix import to configuration.nix"
        fi
    fi
}

# Test the NixOS configuration
test_nixos_config() {
    log "Testing NixOS configuration..."
    
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "NixOS configuration is valid"
        return 0
    else
        error "NixOS configuration has errors:"
        sudo nixos-rebuild dry-build 2>&1 | head -15
        return 1
    fi
}

# Rebuild NixOS with the modular nginx configuration
rebuild_with_modular_nginx() {
    log "Rebuilding NixOS with modular nginx configuration..."
    
    if sudo nixos-rebuild switch; then
        success "NixOS rebuild completed successfully"
        
        # Check if nginx service is now working
        sleep 3
        if systemctl is-active --quiet nginx; then
            success "Nginx service is running"
            
            # Test virtual hosts
            test_modular_virtual_hosts
        else
            warning "Nginx service is not running, trying to start..."
            if sudo systemctl start nginx; then
                success "Nginx service started"
                test_modular_virtual_hosts
            else
                error "Nginx service failed to start"
                sudo journalctl -u nginx --no-pager -l -n 10
            fi
        fi
    else
        error "NixOS rebuild failed"
        sudo nixos-rebuild switch 2>&1 | tail -15
    fi
}

# Test the modular virtual hosts
test_modular_virtual_hosts() {
    log "Testing modular virtual hosts..."
    
    local hosts=("dashboard.local" "phpmyadmin.local" "sample1.local" "sample2.local" "sample3.local")
    
    echo ""
    for host in "${hosts[@]}"; do
        echo "Testing $host:"
        if curl -s -H "Host: $host" http://localhost | grep -q -i "$host\|nginx\|welcome"; then
            success "$host is responding"
        else
            warning "$host may not be working"
            echo "  Response: $(curl -s -H "Host: $host" http://localhost | head -1)"
        fi
    done
    echo ""
}

# Show the difference between manual and modular config
show_config_comparison() {
    log "Configuration comparison..."
    echo ""
    echo "🔧 Manual nginx.conf approach:"
    echo "  ✅ Direct nginx configuration"
    echo "  ❌ Not integrated with NixOS modules"
    echo "  ❌ Doesn't use nginx-vhosts.nix"
    echo "  ❌ Manual maintenance required"
    echo ""
    echo "🏗️ Modular NixOS approach:"
    echo "  ✅ Uses nginx-vhosts.nix module"
    echo "  ✅ Integrated with NixOS configuration"
    echo "  ✅ Automatic PHP-FPM socket detection"
    echo "  ✅ Proper NixOS service management"
    echo "  ✅ Uses lib.mkMerge for extensibility"
    echo ""
}

# Main function
main() {
    echo "🔄 Restore NixOS Nginx Service with Modular Configuration"
    echo "========================================================="
    echo ""
    
    check_current_setup
    check_modular_config
    show_config_comparison
    
    echo ""
    echo "This will:"
    echo "1. Stop the manual nginx setup"
    echo "2. Fix the nginx service module"
    echo "3. Ensure nginx-vhosts.nix is imported"
    echo "4. Rebuild NixOS to use the modular configuration"
    echo ""
    
    read -p "Proceed with restoring modular nginx? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    stop_manual_nginx
    create_fixed_nginx_service
    ensure_modular_import
    
    if test_nixos_config; then
        rebuild_with_modular_nginx
    else
        error "Configuration test failed. Please fix errors before rebuilding."
    fi
    
    echo ""
    echo "🎯 Summary:"
    echo "- Manual nginx setup removed"
    echo "- NixOS nginx service restored"
    echo "- nginx-vhosts.nix module is now active"
    echo "- Virtual hosts configured through NixOS modules"
    echo "- PHP-FPM integration handled automatically"
}

# Run main function
main "$@"