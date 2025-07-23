#!/usr/bin/env bash

# Debug Nginx Pre-start Script Failure
# This script examines the nginx pre-start script to identify the exact failure

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

# Get detailed nginx logs
get_nginx_logs() {
    log "Getting detailed nginx failure logs..."
    echo ""
    echo "=== Recent nginx service logs ==="
    sudo journalctl -u nginx --no-pager -l -n 30
    echo ""
    echo "=== Detailed nginx logs with errors ==="
    sudo journalctl -xeu nginx.service --no-pager -l -n 20
    echo ""
}

# Examine the pre-start script
examine_prestart_script() {
    log "Examining nginx pre-start script..."
    
    # Find the pre-start script path
    local prestart_path="/nix/store/vmkwsnm6bs8qiy642s8mw1rdj92f7xzd-unit-script-nginx-pre-start/bin/nginx-pre-start"
    
    if [[ -f "$prestart_path" ]]; then
        echo "Pre-start script found: $prestart_path"
        echo ""
        echo "=== Pre-start script contents ==="
        cat "$prestart_path"
        echo ""
        echo "=== End of pre-start script ==="
        echo ""
        
        # Try to run the pre-start script manually with verbose output
        log "Running pre-start script manually..."
        echo "Command: sudo $prestart_path"
        echo ""
        
        if sudo bash -x "$prestart_path" 2>&1; then
            success "Pre-start script executed successfully when run manually"
        else
            error "Pre-start script failed when run manually:"
            echo "Exit code: $?"
        fi
    else
        error "Pre-start script not found at expected path"
        echo "Looking for nginx pre-start scripts..."
        find /nix/store -name "*nginx-pre-start*" 2>/dev/null | head -5
    fi
}

# Check nginx configuration files
check_nginx_config_files() {
    log "Checking nginx configuration files..."
    
    # Find nginx configuration
    local nginx_conf_paths=(
        "/etc/nginx/nginx.conf"
        "/run/current-system/etc/nginx/nginx.conf"
    )
    
    for conf_path in "${nginx_conf_paths[@]}"; do
        if [[ -f "$conf_path" ]]; then
            echo "Found nginx config: $conf_path"
            echo "File size: $(stat -c%s "$conf_path") bytes"
            echo "Permissions: $(stat -c%A "$conf_path")"
            echo ""
            
            # Test configuration syntax
            if sudo nginx -t -c "$conf_path" 2>&1; then
                success "Configuration syntax is valid"
            else
                error "Configuration syntax error in $conf_path"
            fi
            echo ""
        fi
    done
    
    # Look for NixOS-generated nginx configs
    echo "Looking for NixOS nginx configurations..."
    find /nix/store -name "nginx.conf" -path "*nginx*" 2>/dev/null | head -3 | while read conf; do
        echo "NixOS config: $conf"
        echo "First few lines:"
        head -5 "$conf" 2>/dev/null || echo "Cannot read file"
        echo ""
    done
}

# Check for missing files or directories that nginx might need
check_nginx_dependencies() {
    log "Checking nginx dependencies..."
    
    # Check for nginx binary
    if command -v nginx >/dev/null; then
        success "Nginx binary found: $(which nginx)"
        nginx -V 2>&1 | head -3
    else
        error "Nginx binary not found in PATH"
    fi
    echo ""
    
    # Check for required directories
    local required_dirs=(
        "/var/lib/nginx"
        "/var/log/nginx" 
        "/run/nginx"
        "/etc/nginx"
        "/var/cache/nginx"
        "/tmp"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            success "Directory exists: $dir"
            echo "  Owner: $(stat -c%U:%G "$dir")"
            echo "  Permissions: $(stat -c%A "$dir")"
        else
            error "Missing directory: $dir"
        fi
    done
    echo ""
}

# Try to create a minimal working nginx setup
create_minimal_nginx() {
    log "Creating minimal nginx setup..."
    
    # Stop any running nginx
    sudo systemctl stop nginx 2>/dev/null || true
    sudo pkill nginx 2>/dev/null || true
    
    # Create minimal directories
    sudo mkdir -p /etc/nginx/conf.d
    sudo mkdir -p /var/www/html
    sudo mkdir -p /var/lib/nginx/tmp
    sudo mkdir -p /var/log/nginx
    sudo mkdir -p /run/nginx
    
    # Create minimal nginx.conf
    sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /run/nginx/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    keepalive_timeout 65;
    
    server {
        listen 80;
        server_name localhost;
        root /var/www/html;
        index index.html;
        
        location / {
            try_files $uri $uri/ =404;
        }
    }
}
EOF

    # Create simple index page
    sudo tee /var/www/html/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Nginx Test</title></head>
<body><h1>Nginx is working!</h1></body>
</html>
EOF

    # Set permissions
    sudo chown -R nginx:nginx /var/lib/nginx /var/log/nginx /run/nginx /var/www/html
    sudo chmod -R 755 /var/lib/nginx /var/log/nginx /run/nginx /var/www/html
    
    # Test the configuration
    if sudo nginx -t; then
        success "Minimal nginx configuration is valid"
        
        # Try to start nginx directly (not via systemd)
        if sudo nginx; then
            success "Nginx started successfully with minimal config"
            
            # Test if it responds
            if curl -s http://localhost >/dev/null; then
                success "Nginx is responding to requests"
            else
                warning "Nginx started but not responding"
            fi
            
            # Stop nginx
            sudo nginx -s quit 2>/dev/null || sudo pkill nginx
        else
            error "Nginx failed to start even with minimal config"
        fi
    else
        error "Minimal nginx configuration has syntax errors"
    fi
}

# Check systemd service definition
check_systemd_service() {
    log "Checking nginx systemd service definition..."
    
    echo "=== Nginx service file ==="
    systemctl cat nginx.service
    echo ""
    
    echo "=== Service environment ==="
    sudo systemctl show nginx.service -p Environment
    echo ""
}

# Main function
main() {
    echo "🔍 Debug Nginx Pre-start Script Failure"
    echo "======================================="
    echo ""
    
    get_nginx_logs
    examine_prestart_script
    check_nginx_config_files
    check_nginx_dependencies
    check_systemd_service
    
    echo ""
    echo "Choose action:"
    echo "1. Try minimal nginx setup"
    echo "2. Show only the pre-start script failure details"
    echo "3. Disable nginx and investigate manually"
    echo ""
    read -p "Enter choice (1-3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            create_minimal_nginx
            ;;
        2)
            echo "=== Pre-start script failure details ==="
            examine_prestart_script
            ;;
        3)
            sudo systemctl disable nginx
            echo "Nginx service disabled. You can investigate manually and re-enable with:"
            echo "  sudo systemctl enable nginx"
            echo "  sudo systemctl start nginx"
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    echo ""
    echo "🎯 Next steps:"
    echo "- Check the pre-start script output above for specific errors"
    echo "- Look for missing files or permission issues"
    echo "- Try running nginx directly: sudo nginx -t && sudo nginx"
}

# Run main function
main "$@"