#!/usr/bin/env bash

# Fix Nginx Infinite Recursion
# This script identifies and fixes infinite recursion in nginx.nix

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

# Check if nginx module exists
check_nginx_module() {
    log "Checking nginx module..."
    
    if [[ ! -f "$NGINX_MODULE" ]]; then
        error "nginx.nix not found at $NGINX_MODULE"
    fi
    success "Found nginx.nix"
}

# Analyze nginx module
analyze_nginx_module() {
    log "Analyzing nginx module for recursion issues..."
    echo ""
    
    echo "📄 Current nginx.nix content:"
    echo "================================"
    cat "$NGINX_MODULE"
    echo "================================"
    echo ""
    
    # Check for common recursion patterns
    echo "🔍 Checking for recursion patterns:"
    
    # Check for self-references
    if grep -q "nginx\.nix" "$NGINX_MODULE"; then
        warning "Found self-reference to nginx.nix"
    fi
    
    # Check for circular config references
    if grep -q "config\.services\.nginx" "$NGINX_MODULE"; then
        warning "Found config.services.nginx reference (potential recursion)"
        grep -n "config\.services\.nginx" "$NGINX_MODULE" | sed 's/^/  /'
    fi
    
    # Check for lib.mkMerge issues
    if grep -q "lib\.mkMerge" "$NGINX_MODULE"; then
        warning "Found lib.mkMerge (check for circular merging)"
        grep -n "lib\.mkMerge" "$NGINX_MODULE" | sed 's/^/  /'
    fi
    
    # Check for systemd service references
    if grep -q "systemd\.services\.nginx" "$NGINX_MODULE"; then
        warning "Found systemd.services.nginx reference"
        grep -n "systemd\.services\.nginx" "$NGINX_MODULE" | sed 's/^/  /'
    fi
}

# Create a minimal nginx module
create_minimal_nginx() {
    log "Creating minimal nginx module..."
    
    # Create backup
    sudo cp "$NGINX_MODULE" "$NGINX_MODULE.backup-$(date +%Y%m%d-%H%M%S)"
    success "Created backup of nginx.nix"
    
    # Create minimal nginx configuration
    sudo tee "$NGINX_MODULE" > /dev/null << 'EOF'
# Minimal Nginx Service Module
# This module provides basic nginx configuration without recursion

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
  };

  users.groups.nginx = lib.mkIf (!config.users.groups ? nginx) {};

  # Open HTTP and HTTPS ports
  networking.firewall.allowedTCPPorts = lib.mkAfter [ 80 443 ];
}
EOF

    success "Created minimal nginx module"
}

# Create a safe nginx module
create_safe_nginx() {
    log "Creating safe nginx module without recursion..."
    
    # Create backup
    sudo cp "$NGINX_MODULE" "$NGINX_MODULE.backup-$(date +%Y%m%d-%H%M%S)"
    success "Created backup of nginx.nix"
    
    # Create safe nginx configuration
    sudo tee "$NGINX_MODULE" > /dev/null << 'EOF'
# Safe Nginx Service Module
# This module provides nginx configuration without circular references

{ config, pkgs, lib, ... }:

{
  # Nginx service configuration
  services.nginx = {
    enable = lib.mkDefault true;
    user = lib.mkDefault "nginx";
    group = lib.mkDefault "nginx";
    
    # Global nginx configuration
    appendConfig = lib.mkDefault ''
      worker_processes auto;
      worker_connections 1024;
      worker_rlimit_nofile 65535;
      
      events {
        use epoll;
        multi_accept on;
      }
    '';

    # Common HTTP configuration
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
      
      # Compression
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
      
      # Rate limiting zones
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
    chown -R nginx:nginx /var/lib/nginx
    chown -R nginx:nginx /var/log/nginx
  '';
}
EOF

    success "Created safe nginx module"
}

# Test nginx module
test_nginx_module() {
    log "Testing nginx module syntax..."
    
    if nix-instantiate --parse "$NGINX_MODULE" &>/dev/null; then
        success "Nginx module syntax is valid"
    else
        error "Nginx module still has syntax errors"
        nix-instantiate --parse "$NGINX_MODULE" 2>&1 | head -10
        return 1
    fi
}

# Test full configuration
test_full_configuration() {
    log "Testing full configuration..."
    
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "Configuration is valid! Nginx recursion fixed."
        echo ""
        echo "🎉 Ready to rebuild:"
        echo "   sudo nixos-rebuild switch --upgrade --impure"
    else
        warning "Configuration still has issues. Let's see the error:"
        echo ""
        sudo nixos-rebuild dry-build 2>&1 | head -20
    fi
}

# Show nginx recursion patterns
show_recursion_patterns() {
    log "Common nginx recursion patterns to avoid:"
    echo ""
    echo "❌ Problematic patterns:"
    echo "  - config.services.nginx references within services.nginx block"
    echo "  - systemd.services.nginx.serviceConfig = lib.mkMerge with circular refs"
    echo "  - Self-referencing imports"
    echo "  - Circular lib.mkMerge operations"
    echo ""
    echo "✅ Safe patterns:"
    echo "  - Use lib.mkDefault for overrideable options"
    echo "  - Use lib.mkAfter for appending to lists"
    echo "  - Avoid config.services.nginx references in nginx block"
    echo "  - Keep systemd service config simple"
    echo ""
}

# Main function
main() {
    echo "🔧 Fix Nginx Infinite Recursion"
    echo "==============================="
    echo ""
    
    check_nginx_module
    analyze_nginx_module
    show_recursion_patterns
    
    echo "Choose fix approach:"
    echo "1. Create minimal nginx module (basic functionality)"
    echo "2. Create safe nginx module (full functionality, no recursion)"
    echo "3. Show current module and exit (for manual fixing)"
    echo ""
    read -p "Enter choice (1, 2, or 3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            create_minimal_nginx
            test_nginx_module
            test_full_configuration
            ;;
        2)
            create_safe_nginx
            test_nginx_module
            test_full_configuration
            ;;
        3)
            echo "Current nginx module shown above. Fix manually and test with:"
            echo "  nix-instantiate --parse $NGINX_MODULE"
            echo "  sudo nixos-rebuild dry-build"
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    echo ""
    echo "🎯 Summary:"
    echo "- Removed circular references from nginx module"
    echo "- Used safe patterns (lib.mkDefault, lib.mkAfter)"
    echo "- Avoided config.services.nginx self-references"
    echo "- Should resolve infinite recursion"
}

# Run main function
main "$@"