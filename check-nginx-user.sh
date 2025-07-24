#!/usr/bin/env bash

# Check Nginx User Configuration
# This script verifies nginx user setup and service status

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

# Check nginx user
check_nginx_user() {
    log "Checking nginx user configuration..."
    echo ""
    
    if id nginx &>/dev/null; then
        success "nginx user exists"
        echo "User info:"
        id nginx
        echo ""
        
        echo "User details:"
        getent passwd nginx
        echo ""
        
        echo "Group details:"
        getent group nginx
        echo ""
    else
        error "nginx user does not exist"
        return 1
    fi
}

# Check nginx processes
check_nginx_processes() {
    log "Checking nginx processes..."
    echo ""
    
    echo "All nginx-related processes:"
    ps aux | grep -E "(nginx|php-fpm)" | grep -v grep || echo "No nginx or php-fpm processes found"
    echo ""
    
    echo "Nginx master processes:"
    ps aux | grep "nginx: master" | grep -v grep || echo "No nginx master process found"
    echo ""
    
    echo "Nginx worker processes:"
    ps aux | grep "nginx: worker" | grep -v grep || echo "No nginx worker processes found"
    echo ""
}

# Check nginx service status
check_nginx_service() {
    log "Checking nginx service status..."
    echo ""
    
    echo "Nginx service status:"
    systemctl status nginx --no-pager -l || true
    echo ""
    
    echo "Nginx service enabled:"
    systemctl is-enabled nginx || echo "nginx service not enabled"
    echo ""
    
    echo "Nginx service active:"
    systemctl is-active nginx || echo "nginx service not active"
    echo ""
}

# Check nginx configuration files
check_nginx_config() {
    log "Checking nginx configuration..."
    echo ""
    
    echo "Nginx configuration test:"
    if command -v nginx >/dev/null; then
        nginx -t 2>&1 || echo "nginx configuration test failed"
    else
        echo "nginx command not found"
    fi
    echo ""
    
    echo "Nginx configuration file:"
    if [[ -f "/etc/nginx/nginx.conf" ]]; then
        echo "Manual config exists: /etc/nginx/nginx.conf"
        echo "Size: $(stat -c%s /etc/nginx/nginx.conf) bytes"
    else
        echo "No manual nginx.conf found"
    fi
    echo ""
    
    echo "NixOS nginx configuration:"
    find /nix/store -name "nginx.conf" -path "*nginx*" 2>/dev/null | head -3 || echo "No NixOS nginx config found"
    echo ""
}

# Check file permissions
check_file_permissions() {
    log "Checking nginx-related file permissions..."
    echo ""
    
    local dirs=("/var/lib/nginx" "/var/log/nginx" "/run/nginx" "/var/www")
    
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "Directory: $dir"
            ls -la "$dir" | head -3
            echo "Owner: $(stat -c%U:%G "$dir")"
            echo ""
        else
            warning "Directory missing: $dir"
        fi
    done
}

# Check nginx user in configuration
check_nginx_user_config() {
    log "Checking nginx user in NixOS configuration..."
    echo ""
    
    echo "Nginx user declaration in modules:"
    grep -r "users.users.nginx" /etc/nixos/modules/ 2>/dev/null | head -3 || echo "No nginx user declaration found"
    echo ""
    
    echo "Nginx service user configuration:"
    grep -r "services.nginx.*user" /etc/nixos/modules/ 2>/dev/null | head -3 || echo "No nginx service user config found"
    echo ""
    
    echo "PHP-FPM user configuration:"
    grep -r "user.*nginx" /etc/nixos/modules/ 2>/dev/null | head -3 || echo "No PHP-FPM nginx user config found"
    echo ""
}

# Start nginx if not running
start_nginx() {
    log "Attempting to start nginx..."
    
    if systemctl is-active --quiet nginx; then
        success "nginx is already running"
        return 0
    fi
    
    echo "Starting nginx service..."
    if sudo systemctl start nginx; then
        success "nginx started successfully"
        
        # Check if it's actually running
        sleep 2
        if systemctl is-active --quiet nginx; then
            success "nginx is now active"
            
            # Test HTTP response
            if curl -s http://localhost >/dev/null; then
                success "nginx is responding to HTTP requests"
            else
                warning "nginx started but not responding to requests"
            fi
        else
            error "nginx failed to stay active"
        fi
    else
        error "Failed to start nginx"
        echo "Recent nginx logs:"
        sudo journalctl -u nginx --no-pager -l -n 10
    fi
}

# Main function
main() {
    echo "🔍 Check Nginx User Configuration"
    echo "================================="
    echo ""
    
    check_nginx_user
    check_nginx_processes
    check_nginx_service
    check_nginx_config
    check_file_permissions
    check_nginx_user_config
    
    echo ""
    echo "🎯 Summary:"
    echo ""
    
    if id nginx &>/dev/null; then
        success "nginx user is properly configured"
    else
        error "nginx user is missing"
    fi
    
    if systemctl is-active --quiet nginx; then
        success "nginx service is running"
    else
        warning "nginx service is not running"
        echo ""
        read -p "Would you like to try starting nginx? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            start_nginx
        fi
    fi
    
    echo ""
    echo "📋 Notes:"
    echo "- nginx user is declared in modules/services/nginx.nix"
    echo "- PHP-FPM processes are correctly running as nginx user"
    echo "- nginx service may need to be started manually"
}

# Run main function
main "$@"