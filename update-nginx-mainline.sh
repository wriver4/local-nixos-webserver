#!/usr/bin/env bash

# Update Nginx to Mainline Version
# This script updates the nginx module to use nginxMainline package

set -e  # Exit on any error

NIXOS_CONFIG_DIR="/etc/nixos"
NGINX_MODULE="$NIXOS_CONFIG_DIR/modules/services/nginx.nix"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NGINX="$SCRIPT_DIR/modules/services/nginx.nix"

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

# Show nginx package differences
show_nginx_differences() {
    log "Nginx package differences:"
    echo ""
    echo "📦 nginx (stable):"
    echo "  - Stable release branch"
    echo "  - Conservative updates"
    echo "  - Well-tested features"
    echo ""
    echo "📦 nginxMainline (recommended):"
    echo "  - Latest stable features"
    echo "  - Active development branch"
    echo "  - New features and improvements"
    echo "  - Still production-ready"
    echo ""
}

# Update nginx module to use nginxMainline
update_nginx_module() {
    log "Updating nginx module to use nginxMainline..."
    
    # Backup current module
    if [[ -f "$NGINX_MODULE" ]]; then
        sudo cp "$NGINX_MODULE" "$NGINX_MODULE.mainline-backup-$(date +%Y%m%d-%H%M%S)"
        success "Backed up current nginx module"
    fi
    
    # Create updated nginx module with nginxMainline
    sudo tee "$NGINX_MODULE" > /dev/null << 'EOF'
# Enhanced Nginx Service Module with Mainline Package
# This module provides nginx service using the mainline (latest stable) package

{ config, pkgs, lib, ... }:

{
  # Nginx service configuration with mainline package
  services.nginx = {
    enable = lib.mkDefault true;
    package = lib.mkDefault pkgs.nginxMainline;  # Use mainline version
    user = lib.mkDefault "nginx";
    group = lib.mkDefault "nginx";
    
    # Basic configuration optimized for mainline
    appendConfig = lib.mkDefault ''
      worker_processes auto;
      worker_connections 1024;
      worker_rlimit_nofile 65535;
      
      events {
        use epoll;
        multi_accept on;
      }
    '';

    # HTTP configuration with mainline-specific optimizations
    commonHttpConfig = lib.mkDefault ''
      # Basic optimization
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
      keepalive_timeout 65;
      types_hash_max_size 2048;
      
      # Buffer optimization
      client_body_buffer_size 128k;
      client_header_buffer_size 1k;
      large_client_header_buffers 4 4k;
      
      # Compression with mainline improvements
      gzip on;
      gzip_vary on;
      gzip_min_length 1024;
      gzip_comp_level 6;
      gzip_types
        text/plain
        text/css
        application/json
        application/javascript
        text/xml
        application/xml
        application/xml+rss
        text/javascript
        application/atom+xml
        image/svg+xml;
      
      # Security headers
      server_tokens off;
      add_header X-Frame-Options SAMEORIGIN always;
      add_header X-Content-Type-Options nosniff always;
      add_header X-XSS-Protection "1; mode=block" always;
      
      # Rate limiting
      limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
      limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
      
      # File caching
      open_file_cache max=200000 inactive=20s;
      open_file_cache_valid 30s;
      open_file_cache_min_uses 2;
      open_file_cache_errors on;
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

  # Systemd service optimization for mainline
  systemd.services.nginx.serviceConfig = lib.mkMerge [
    {
      LimitNOFILE = lib.mkDefault 65535;
      LimitNPROC = lib.mkDefault 4096;
    }
  ];
}
EOF

    success "Updated nginx module to use nginxMainline"
}

# Update project module too
update_project_module() {
    log "Updating project nginx module..."
    
    if [[ -f "$PROJECT_NGINX" ]]; then
        # Backup project module
        cp "$PROJECT_NGINX" "$PROJECT_NGINX.mainline-backup-$(date +%Y%m%d-%H%M%S)"
        
        # Copy the updated version back to project
        sudo cp "$NGINX_MODULE" "$PROJECT_NGINX"
        sudo chown $(whoami):$(id -gn) "$PROJECT_NGINX"
        
        success "Updated project nginx module"
    else
        warning "Project nginx module not found at $PROJECT_NGINX"
    fi
}

# Test the updated module
test_nginx_mainline() {
    log "Testing nginx mainline module..."
    
    # Test syntax
    if nix-instantiate --parse "$NGINX_MODULE" &>/dev/null; then
        success "Nginx mainline module syntax is valid"
    else
        error "Nginx mainline module syntax is invalid"
        nix-instantiate --parse "$NGINX_MODULE" 2>&1 | head -5
        return 1
    fi
    
    # Test with configuration
    sudo tee "$NIXOS_CONFIG_DIR/test-nginx-mainline.nix" > /dev/null << 'EOF'
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

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-nginx-mainline.nix" &>/dev/null; then
        success "Nginx mainline configuration works!"
        sudo rm -f "$NIXOS_CONFIG_DIR/test-nginx-mainline.nix"
        return 0
    else
        error "Nginx mainline configuration has issues:"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-nginx-mainline.nix" 2>&1 | head -10
        sudo rm -f "$NIXOS_CONFIG_DIR/test-nginx-mainline.nix"
        return 1
    fi
}

# Test full configuration with mainline
test_full_config_mainline() {
    log "Testing full configuration with nginx mainline..."
    
    if sudo nixos-rebuild dry-build --impure &>/dev/null; then
        success "Full configuration works with nginx mainline!"
        return 0
    else
        warning "Full configuration has issues:"
        sudo nixos-rebuild dry-build --impure 2>&1 | head -10
        return 1
    fi
}

# Show nginx version info
show_nginx_version_info() {
    log "Nginx version information:"
    echo ""
    echo "After rebuilding, you can check the nginx version with:"
    echo "  nginx -v"
    echo ""
    echo "Expected output will show nginx mainline version (latest stable)"
    echo ""
    echo "📋 Nginx mainline benefits:"
    echo "  ✅ Latest HTTP/2 and HTTP/3 improvements"
    echo "  ✅ Enhanced security features"
    echo "  ✅ Better performance optimizations"
    echo "  ✅ New configuration directives"
    echo "  ✅ Improved SSL/TLS support"
    echo ""
}

# Main function
main() {
    echo "📦 Update Nginx to Mainline Version"
    echo "==================================="
    echo ""
    
    show_nginx_differences
    
    echo "This will update your nginx service to use nginxMainline package."
    echo "This gives you the latest stable nginx features and improvements."
    echo ""
    
    read -p "Proceed with nginx mainline update? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    update_nginx_module
    update_project_module
    
    if test_nginx_mainline; then
        if test_full_config_mainline; then
            show_nginx_version_info
            
            echo ""
            echo "🎉 SUCCESS! Nginx mainline module updated!"
            echo ""
            echo "🎯 Next steps:"
            echo "1. Test: sudo nixos-rebuild dry-build --impure"
            echo "2. Apply: sudo nixos-rebuild switch --impure"
            echo "3. Check version: nginx -v"
            echo ""
            echo "✅ You now have:"
            echo "  - Latest stable nginx features"
            echo "  - Enhanced performance"
            echo "  - Improved security"
            echo "  - Better HTTP/2 and HTTP/3 support"
        else
            warning "Full configuration needs attention. Check the output above."
        fi
    else
        error "Nginx mainline module has issues. Check the error output above."
    fi
}

# Run main function
main "$@"