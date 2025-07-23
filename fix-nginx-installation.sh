#!/usr/bin/env bash

# Fix Nginx Installation Issues
# This script fixes the missing nginx binary and directories

set -e  # Exit on any error

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

# Find nginx binary in nix store
find_nginx_binary() {
    log "Looking for nginx binary in nix store..."
    
    # Look for nginx binaries
    local nginx_paths=$(find /nix/store -name "nginx" -type f -executable 2>/dev/null | grep -E "nginx-[0-9]" | head -5)
    
    if [[ -n "$nginx_paths" ]]; then
        echo "Found nginx binaries:"
        echo "$nginx_paths" | while read path; do
            echo "  $path"
            "$path" -V 2>&1 | head -1 || echo "    (cannot execute)"
        done
        echo ""
        
        # Use the first one found
        local nginx_binary=$(echo "$nginx_paths" | head -1)
        echo "Using nginx binary: $nginx_binary"
        return 0
    else
        error "No nginx binary found in nix store"
        return 1
    fi
}

# Check if nginx is properly configured in NixOS
check_nixos_nginx_config() {
    log "Checking NixOS nginx configuration..."
    
    # Check if nginx is enabled in configuration
    if sudo nixos-rebuild dry-build 2>&1 | grep -q "services.nginx"; then
        success "Nginx service is configured in NixOS"
    else
        warning "Nginx service may not be properly configured in NixOS"
    fi
    
    # Look for nginx configuration in nix store
    local nginx_configs=$(find /nix/store -name "nginx.conf" -path "*nginx*" 2>/dev/null | head -3)
    if [[ -n "$nginx_configs" ]]; then
        echo "Found nginx configurations:"
        echo "$nginx_configs" | while read conf; do
            echo "  $conf"
        done
    else
        warning "No nginx configurations found in nix store"
    fi
    echo ""
}

# Create missing directories
create_missing_directories() {
    log "Creating missing nginx directories..."
    
    # Create /run/nginx
    sudo mkdir -p /run/nginx
    sudo chown nginx:nginx /run/nginx
    sudo chmod 755 /run/nginx
    success "Created /run/nginx"
    
    # Create /etc/nginx
    sudo mkdir -p /etc/nginx/conf.d
    sudo chown nginx:nginx /etc/nginx
    sudo chmod 755 /etc/nginx
    success "Created /etc/nginx"
    
    # Create other potentially needed directories
    sudo mkdir -p /var/lib/nginx/{tmp,proxy,fastcgi,uwsgi,scgi}
    sudo chown -R nginx:nginx /var/lib/nginx
    sudo chmod -R 755 /var/lib/nginx
    success "Created nginx subdirectories"
}

# Create a basic nginx configuration
create_basic_nginx_config() {
    log "Creating basic nginx configuration..."
    
    # Create mime.types if it doesn't exist
    if [[ ! -f "/etc/nginx/mime.types" ]]; then
        sudo tee /etc/nginx/mime.types > /dev/null << 'EOF'
types {
    text/html                             html htm shtml;
    text/css                              css;
    text/xml                              xml;
    image/gif                             gif;
    image/jpeg                            jpeg jpg;
    application/javascript                js;
    application/atom+xml                  atom;
    application/rss+xml                   rss;
    text/plain                            txt;
    image/png                             png;
    image/x-icon                          ico;
    image/svg+xml                         svg svgz;
    application/pdf                       pdf;
    application/zip                       zip;
}
EOF
        success "Created /etc/nginx/mime.types"
    fi
    
    # Create basic nginx.conf
    sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Include additional configs
    include /etc/nginx/conf.d/*.conf;

    # Default server
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;
        root /var/www/html;
        index index.html index.htm;

        location / {
            try_files $uri $uri/ =404;
        }

        error_page 404 /404.html;
        location = /404.html {
            root /var/www/html;
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /var/www/html;
        }
    }
}
EOF
    success "Created basic /etc/nginx/nginx.conf"
    
    # Create web root
    sudo mkdir -p /var/www/html
    sudo tee /var/www/html/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to nginx!</title>
</head>
<body>
    <h1>Welcome to nginx!</h1>
    <p>If you can see this page, the nginx web server is successfully installed and working.</p>
    <p>For online documentation and support please refer to <a href="http://nginx.org/">nginx.org</a>.</p>
</body>
</html>
EOF
    sudo chown -R nginx:nginx /var/www/html
    sudo chmod -R 755 /var/www/html
    success "Created web root with test page"
}

# Test nginx configuration
test_nginx_config() {
    log "Testing nginx configuration..."
    
    # Find nginx binary
    local nginx_binary=$(find /nix/store -name "nginx" -type f -executable 2>/dev/null | grep -E "nginx-[0-9]" | head -1)
    
    if [[ -n "$nginx_binary" ]]; then
        echo "Testing with nginx binary: $nginx_binary"
        
        if sudo "$nginx_binary" -t; then
            success "Nginx configuration test passed"
            return 0
        else
            error "Nginx configuration test failed"
            return 1
        fi
    else
        error "Cannot find nginx binary to test configuration"
        return 1
    fi
}

# Try to start nginx manually
start_nginx_manually() {
    log "Attempting to start nginx manually..."
    
    # Find nginx binary
    local nginx_binary=$(find /nix/store -name "nginx" -type f -executable 2>/dev/null | grep -E "nginx-[0-9]" | head -1)
    
    if [[ -n "$nginx_binary" ]]; then
        echo "Starting nginx with: $nginx_binary"
        
        # Stop any existing nginx processes
        sudo pkill nginx 2>/dev/null || true
        
        if sudo "$nginx_binary"; then
            success "Nginx started manually"
            
            # Test if it responds
            sleep 2
            if curl -s http://localhost >/dev/null; then
                success "Nginx is responding to HTTP requests"
                echo "Test page content:"
                curl -s http://localhost | head -3
            else
                warning "Nginx started but not responding to requests"
            fi
            
            # Stop nginx
            sudo "$nginx_binary" -s quit 2>/dev/null || sudo pkill nginx
            success "Stopped nginx"
        else
            error "Failed to start nginx manually"
        fi
    else
        error "Cannot find nginx binary"
    fi
}

# Rebuild NixOS to ensure nginx is properly installed
rebuild_nixos() {
    log "Rebuilding NixOS to ensure nginx is properly installed..."
    
    if sudo nixos-rebuild switch; then
        success "NixOS rebuild completed"
        
        # Check if nginx is now available
        if command -v nginx >/dev/null; then
            success "Nginx binary is now available in PATH"
            nginx -V 2>&1 | head -1
        else
            warning "Nginx binary still not in PATH after rebuild"
        fi
        
        # Try to start nginx service
        if sudo systemctl start nginx; then
            success "Nginx service started successfully"
            systemctl status nginx --no-pager -l
        else
            warning "Nginx service still fails to start"
            sudo journalctl -u nginx --no-pager -l -n 10
        fi
    else
        error "NixOS rebuild failed"
        sudo nixos-rebuild switch 2>&1 | tail -10
    fi
}

# Main function
main() {
    echo "🔧 Fix Nginx Installation Issues"
    echo "==============================="
    echo ""
    
    find_nginx_binary
    check_nixos_nginx_config
    
    echo ""
    echo "Choose fix approach:"
    echo "1. Create missing directories and basic config, then test manually"
    echo "2. Rebuild NixOS to ensure proper nginx installation"
    echo "3. Do both: fix directories + rebuild NixOS"
    echo ""
    read -p "Enter choice (1-3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            create_missing_directories
            create_basic_nginx_config
            test_nginx_config
            start_nginx_manually
            ;;
        2)
            rebuild_nixos
            ;;
        3)
            create_missing_directories
            create_basic_nginx_config
            test_nginx_config
            rebuild_nixos
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    echo ""
    echo "🎯 Summary:"
    echo "- Nginx binary should be available after NixOS rebuild"
    echo "- Missing directories have been created"
    echo "- Basic configuration is in place"
    echo "- Test with: sudo systemctl start nginx"
}

# Run main function
main "$@"