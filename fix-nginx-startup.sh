#!/usr/bin/env bash

# Fix Nginx Startup Issues
# This script diagnoses and fixes nginx startup failures

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

# Check nginx service status
check_nginx_status() {
    log "Checking nginx service status..."
    
    echo "Current nginx service status:"
    systemctl status nginx --no-pager -l || true
    echo ""
}

# Check nginx configuration
check_nginx_config() {
    log "Checking nginx configuration..."
    
    # Test nginx configuration syntax
    if sudo nginx -t 2>/dev/null; then
        success "Nginx configuration syntax is valid"
    else
        error "Nginx configuration has syntax errors:"
        sudo nginx -t 2>&1 | head -10
        echo ""
    fi
}

# Check nginx directories and permissions
check_nginx_directories() {
    log "Checking nginx directories and permissions..."
    
    # Check if nginx user exists
    if id nginx &>/dev/null; then
        success "Nginx user exists"
    else
        warning "Nginx user does not exist"
        echo "Creating nginx user..."
        sudo useradd -r -s /bin/false nginx || warning "Could not create nginx user"
    fi
    
    # Check nginx directories
    local dirs=("/var/lib/nginx" "/var/log/nginx" "/run/nginx" "/var/cache/nginx")
    
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            success "Directory exists: $dir"
            ls -la "$dir" | head -3
        else
            warning "Directory missing: $dir"
            echo "Creating directory: $dir"
            sudo mkdir -p "$dir"
            sudo chown nginx:nginx "$dir"
            sudo chmod 755 "$dir"
            success "Created: $dir"
        fi
        echo ""
    done
}

# Check nginx pre-start script
check_prestart_script() {
    log "Checking nginx pre-start script..."
    
    # Find the pre-start script
    local prestart_script=$(systemctl show nginx.service -p ExecStartPre --value | grep -o '/nix/store/[^/]*/bin/nginx-pre-start')
    
    if [[ -n "$prestart_script" && -f "$prestart_script" ]]; then
        echo "Pre-start script: $prestart_script"
        echo "Script contents:"
        cat "$prestart_script" | head -20
        echo ""
        
        # Try to run the pre-start script manually
        log "Testing pre-start script manually..."
        if sudo "$prestart_script" 2>&1; then
            success "Pre-start script runs successfully"
        else
            error "Pre-start script failed:"
            sudo "$prestart_script" 2>&1 | tail -10
        fi
    else
        warning "Could not find pre-start script"
    fi
}

# Check for conflicting processes
check_port_conflicts() {
    log "Checking for port conflicts..."
    
    # Check if anything is using port 80
    if sudo netstat -tlnp | grep :80; then
        warning "Something is already using port 80:"
        sudo netstat -tlnp | grep :80
        echo ""
    else
        success "Port 80 is available"
    fi
    
    # Check if anything is using port 443
    if sudo netstat -tlnp | grep :443; then
        warning "Something is already using port 443:"
        sudo netstat -tlnp | grep :443
        echo ""
    else
        success "Port 443 is available"
    fi
}

# Check nginx configuration files
check_nginx_files() {
    log "Checking nginx configuration files..."
    
    # Check main nginx config
    if [[ -f "/etc/nginx/nginx.conf" ]]; then
        echo "Main nginx config exists: /etc/nginx/nginx.conf"
        echo "Config file size: $(stat -c%s /etc/nginx/nginx.conf) bytes"
    else
        warning "Main nginx config missing: /etc/nginx/nginx.conf"
    fi
    
    # Check for NixOS nginx config
    local nixos_nginx_conf=$(find /nix/store -name "nginx.conf" -path "*/nginx-*" 2>/dev/null | head -1)
    if [[ -n "$nixos_nginx_conf" ]]; then
        echo "NixOS nginx config: $nixos_nginx_conf"
        echo "First 10 lines:"
        head -10 "$nixos_nginx_conf"
    fi
    echo ""
}

# Fix common nginx issues
fix_nginx_issues() {
    log "Fixing common nginx issues..."
    
    # Stop nginx if running
    sudo systemctl stop nginx 2>/dev/null || true
    
    # Create necessary directories
    sudo mkdir -p /var/lib/nginx/{tmp,proxy,fastcgi,uwsgi,scgi}
    sudo mkdir -p /var/log/nginx
    sudo mkdir -p /run/nginx
    sudo mkdir -p /var/cache/nginx
    
    # Set proper ownership
    sudo chown -R nginx:nginx /var/lib/nginx
    sudo chown -R nginx:nginx /var/log/nginx
    sudo chown -R nginx:nginx /run/nginx
    sudo chown -R nginx:nginx /var/cache/nginx
    
    # Set proper permissions
    sudo chmod -R 755 /var/lib/nginx
    sudo chmod -R 755 /var/log/nginx
    sudo chmod -R 755 /run/nginx
    sudo chmod -R 755 /var/cache/nginx
    
    success "Fixed nginx directories and permissions"
}

# Create minimal nginx test config
create_test_config() {
    log "Creating minimal nginx test configuration..."
    
    # Create a minimal test config
    sudo tee /tmp/nginx-test.conf > /dev/null << 'EOF'
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

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;
        root /var/www/html;

        location / {
            return 200 "Nginx test page\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

    # Test the minimal config
    if sudo nginx -t -c /tmp/nginx-test.conf; then
        success "Minimal nginx config is valid"
        
        # Try to start nginx with test config
        log "Testing nginx startup with minimal config..."
        if sudo nginx -c /tmp/nginx-test.conf; then
            success "Nginx started successfully with test config"
            sudo nginx -s quit 2>/dev/null || true
        else
            error "Nginx failed to start even with minimal config"
        fi
    else
        error "Even minimal nginx config has issues"
    fi
    
    # Clean up
    sudo rm -f /tmp/nginx-test.conf
}

# Restart nginx service
restart_nginx() {
    log "Attempting to restart nginx service..."
    
    # Reset failed state
    sudo systemctl reset-failed nginx
    
    # Try to start nginx
    if sudo systemctl start nginx; then
        success "Nginx started successfully!"
        
        # Check status
        systemctl status nginx --no-pager -l
        
        # Test HTTP response
        if curl -s http://localhost >/dev/null; then
            success "Nginx is responding to HTTP requests"
        else
            warning "Nginx started but not responding to requests"
        fi
    else
        error "Nginx failed to start"
        echo "Service status:"
        systemctl status nginx --no-pager -l
        echo ""
        echo "Recent logs:"
        sudo journalctl -u nginx --no-pager -l -n 20
    fi
}

# Show nginx logs
show_nginx_logs() {
    log "Recent nginx logs..."
    echo ""
    echo "=== Systemd Journal (last 20 lines) ==="
    sudo journalctl -u nginx --no-pager -l -n 20
    echo ""
    echo "=== Nginx Error Log ==="
    if [[ -f "/var/log/nginx/error.log" ]]; then
        sudo tail -20 /var/log/nginx/error.log
    else
        echo "No error log found"
    fi
}

# Main function
main() {
    echo "🔧 Fix Nginx Startup Issues"
    echo "==========================="
    echo ""
    
    check_nginx_status
    check_nginx_config
    check_nginx_directories
    check_port_conflicts
    check_nginx_files
    check_prestart_script
    
    echo ""
    echo "Choose action:"
    echo "1. Fix common nginx issues and restart"
    echo "2. Test with minimal configuration"
    echo "3. Show detailed logs only"
    echo "4. Reset and restart nginx service"
    echo ""
    read -p "Enter choice (1-4): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            fix_nginx_issues
            restart_nginx
            ;;
        2)
            create_test_config
            ;;
        3)
            show_nginx_logs
            ;;
        4)
            restart_nginx
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    echo ""
    echo "🎯 Summary:"
    echo "- Check nginx configuration syntax with: sudo nginx -t"
    echo "- View logs with: sudo journalctl -u nginx -f"
    echo "- Test HTTP response with: curl http://localhost"
}

# Run main function
main "$@"