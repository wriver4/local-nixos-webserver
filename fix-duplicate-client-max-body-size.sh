#!/usr/bin/env bash

# Fix Duplicate client_max_body_size Directive
# This script finds and removes duplicate client_max_body_size directives

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

# Find all occurrences of client_max_body_size
find_duplicates() {
    log "Searching for client_max_body_size directives..."
    echo ""
    
    echo "🔍 In NixOS modules:"
    find "$NIXOS_CONFIG_DIR" -name "*.nix" -exec grep -l "client_max_body_size" {} \; 2>/dev/null | while read file; do
        echo "📄 $file:"
        grep -n "client_max_body_size" "$file" | sed 's/^/  /'
        echo ""
    done
    
    echo "🔍 In manual nginx config (if exists):"
    if [[ -f "/etc/nginx/nginx.conf" ]]; then
        echo "📄 /etc/nginx/nginx.conf:"
        grep -n "client_max_body_size" "/etc/nginx/nginx.conf" | sed 's/^/  /' || echo "  No client_max_body_size found"
        echo ""
    fi
    
    echo "🔍 In generated nginx config:"
    local nginx_conf=$(find /nix/store -name "nginx.conf" -path "*nginx*" 2>/dev/null | head -1)
    if [[ -n "$nginx_conf" ]]; then
        echo "📄 $nginx_conf:"
        grep -n "client_max_body_size" "$nginx_conf" | sed 's/^/  /' || echo "  No client_max_body_size found"
        echo ""
    fi
}

# Check which modules define client_max_body_size
check_module_definitions() {
    log "Checking which modules define client_max_body_size..."
    echo ""
    
    local modules_with_directive=()
    
    # Check each module
    find "$NIXOS_CONFIG_DIR/modules" -name "*.nix" -type f | while read module; do
        if grep -q "client_max_body_size" "$module"; then
            echo "❌ Found in: $(basename "$module")"
            echo "   Lines:"
            grep -n "client_max_body_size" "$module" | sed 's/^/     /'
            echo ""
        fi
    done
}

# Remove duplicate from nginx-vhosts.nix
fix_nginx_vhosts() {
    log "Fixing nginx-vhosts.nix..."
    
    local vhosts_file="$NIXOS_CONFIG_DIR/modules/webserver/nginx-vhosts.nix"
    
    if [[ -f "$vhosts_file" ]]; then
        if grep -q "client_max_body_size" "$vhosts_file"; then
            warning "Found client_max_body_size in nginx-vhosts.nix"
            
            # Backup the file
            sudo cp "$vhosts_file" "$vhosts_file.duplicate-fix-backup-$(date +%Y%m%d-%H%M%S)"
            
            # Remove the duplicate directive
            sudo sed -i '/client_max_body_size/d' "$vhosts_file"
            
            success "Removed client_max_body_size from nginx-vhosts.nix"
        else
            success "No client_max_body_size found in nginx-vhosts.nix"
        fi
    else
        warning "nginx-vhosts.nix not found"
    fi
}

# Keep client_max_body_size only in nginx service module
fix_nginx_service() {
    log "Ensuring client_max_body_size is only in nginx service module..."
    
    local nginx_file="$NIXOS_CONFIG_DIR/modules/services/nginx.nix"
    
    if [[ -f "$nginx_file" ]]; then
        if ! grep -q "client_max_body_size" "$nginx_file"; then
            warning "client_max_body_size not found in nginx service module"
            echo "Adding it to the nginx service module..."
            
            # Backup the file
            sudo cp "$nginx_file" "$nginx_file.client-max-backup-$(date +%Y%m%d-%H%M%S)"
            
            # Add client_max_body_size to commonHttpConfig
            sudo sed -i '/commonHttpConfig.*=/,/^[[:space:]]*'\'\'';/{
                /types_hash_max_size/a\      client_max_body_size 64M;
            }' "$nginx_file"
            
            success "Added client_max_body_size to nginx service module"
        else
            success "client_max_body_size already in nginx service module"
        fi
    else
        error "nginx service module not found"
    fi
}

# Remove from other modules
remove_from_other_modules() {
    log "Removing client_max_body_size from other modules..."
    
    # List of modules to check (excluding nginx.nix)
    local modules=(
        "$NIXOS_CONFIG_DIR/modules/webserver/php-optimization.nix"
        "$NIXOS_CONFIG_DIR/configuration.nix"
    )
    
    for module in "${modules[@]}"; do
        if [[ -f "$module" ]]; then
            if grep -q "client_max_body_size" "$module"; then
                warning "Found client_max_body_size in $(basename "$module")"
                
                # Backup and remove
                sudo cp "$module" "$module.client-max-removed-$(date +%Y%m%d-%H%M%S)"
                sudo sed -i '/client_max_body_size/d' "$module"
                
                success "Removed client_max_body_size from $(basename "$module")"
            fi
        fi
    done
}

# Test nginx configuration
test_nginx_config() {
    log "Testing nginx configuration..."
    
    if sudo nixos-rebuild dry-build --impure &>/dev/null; then
        success "NixOS configuration builds successfully"
        
        # Test nginx specifically
        if command -v nginx >/dev/null; then
            if sudo nginx -t 2>/dev/null; then
                success "Nginx configuration test passed"
                return 0
            else
                error "Nginx configuration test failed:"
                sudo nginx -t 2>&1
                return 1
            fi
        else
            warning "nginx command not available for testing"
            return 0
        fi
    else
        error "NixOS configuration build failed:"
        sudo nixos-rebuild dry-build --impure 2>&1 | head -10
        return 1
    fi
}

# Start nginx service
start_nginx_service() {
    log "Attempting to start nginx service..."
    
    # Reset any failed state
    sudo systemctl reset-failed nginx 2>/dev/null || true
    
    if sudo systemctl start nginx; then
        success "Nginx started successfully!"
        
        # Check status
        systemctl status nginx --no-pager -l
        
        # Test HTTP response
        sleep 2
        if curl -s http://localhost >/dev/null; then
            success "Nginx is responding to HTTP requests"
        else
            warning "Nginx started but not responding to requests"
        fi
    else
        error "Nginx failed to start:"
        sudo journalctl -u nginx --no-pager -l -n 5
    fi
}

# Show final configuration
show_final_config() {
    log "Final client_max_body_size configuration:"
    echo ""
    
    echo "✅ Should be defined in nginx service module only:"
    grep -A 5 -B 5 "client_max_body_size" "$NIXOS_CONFIG_DIR/modules/services/nginx.nix" 2>/dev/null || echo "Not found in nginx service module"
    echo ""
    
    echo "❌ Should NOT be in other modules:"
    find "$NIXOS_CONFIG_DIR/modules" -name "*.nix" -not -path "*/services/nginx.nix" -exec grep -l "client_max_body_size" {} \; 2>/dev/null || echo "✅ No duplicates found"
}

# Main function
main() {
    echo "🔧 Fix Duplicate client_max_body_size Directive"
    echo "==============================================="
    echo ""
    
    echo "Error found: nginx configuration has duplicate client_max_body_size directives"
    echo "This will find and remove the duplicates, keeping only one definition."
    echo ""
    
    find_duplicates
    check_module_definitions
    
    echo ""
    read -p "Proceed with fixing duplicates? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    fix_nginx_vhosts
    remove_from_other_modules
    fix_nginx_service
    
    if test_nginx_config; then
        show_final_config
        
        echo ""
        echo "🎯 Configuration fixed! Attempting to start nginx..."
        start_nginx_service
        
        echo ""
        echo "🎉 Summary:"
        echo "✅ Removed duplicate client_max_body_size directives"
        echo "✅ Kept single definition in nginx service module"
        echo "✅ Nginx configuration is valid"
        echo "✅ Nginx service should now start successfully"
    else
        error "Configuration still has issues. Check the output above."
    fi
}

# Run main function
main "$@"