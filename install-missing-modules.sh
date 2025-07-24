#!/usr/bin/env bash

# Install Missing Webserver Modules
# This script copies the webserver modules to the NixOS configuration directory

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# Check what modules exist in project vs system
check_module_status() {
    log "Checking module status..."
    echo ""
    
    echo "📁 Project modules (source):"
    if [[ -d "$SCRIPT_DIR/modules" ]]; then
        find "$SCRIPT_DIR/modules" -name "*.nix" | while read file; do
            local rel_path=${file#$SCRIPT_DIR/}
            echo "  ✅ $rel_path"
        done
    else
        error "No modules directory found in project"
        return 1
    fi
    echo ""
    
    echo "📁 System modules (installed):"
    if [[ -d "$NIXOS_CONFIG_DIR/modules" ]]; then
        find "$NIXOS_CONFIG_DIR/modules" -name "*.nix" | while read file; do
            local rel_path=${file#$NIXOS_CONFIG_DIR/}
            echo "  ✅ $rel_path"
        done
    else
        warning "No modules directory found in system"
    fi
    echo ""
    
    echo "🔍 Missing modules:"
    local missing_count=0
    
    # Check webserver modules
    if [[ ! -d "$NIXOS_CONFIG_DIR/modules/webserver" ]]; then
        error "  modules/webserver/ directory missing"
        ((missing_count++))
    else
        if [[ ! -f "$NIXOS_CONFIG_DIR/modules/webserver/nginx-vhosts.nix" ]]; then
            error "  modules/webserver/nginx-vhosts.nix missing"
            ((missing_count++))
        fi
        if [[ ! -f "$NIXOS_CONFIG_DIR/modules/webserver/php-optimization.nix" ]]; then
            error "  modules/webserver/php-optimization.nix missing"
            ((missing_count++))
        fi
    fi
    
    if [[ $missing_count -eq 0 ]]; then
        success "All webserver modules are installed"
    else
        warning "Found $missing_count missing modules"
    fi
    
    return $missing_count
}

# Install missing webserver modules
install_webserver_modules() {
    log "Installing webserver modules..."
    
    # Create webserver directory
    sudo mkdir -p "$NIXOS_CONFIG_DIR/modules/webserver"
    
    # Copy webserver modules from project
    if [[ -f "$SCRIPT_DIR/modules/webserver/nginx-vhosts.nix" ]]; then
        sudo cp "$SCRIPT_DIR/modules/webserver/nginx-vhosts.nix" "$NIXOS_CONFIG_DIR/modules/webserver/"
        success "Installed nginx-vhosts.nix"
    else
        error "nginx-vhosts.nix not found in project"
    fi
    
    if [[ -f "$SCRIPT_DIR/modules/webserver/php-optimization.nix" ]]; then
        sudo cp "$SCRIPT_DIR/modules/webserver/php-optimization.nix" "$NIXOS_CONFIG_DIR/modules/webserver/"
        success "Installed php-optimization.nix"
    else
        error "php-optimization.nix not found in project"
    fi
    
    # Set proper ownership
    sudo chown -R root:root "$NIXOS_CONFIG_DIR/modules/webserver"
    sudo chmod -R 644 "$NIXOS_CONFIG_DIR/modules/webserver"/*.nix
    
    success "Webserver modules installed"
}

# Update service modules if needed
update_service_modules() {
    log "Checking and updating service modules..."
    
    local services_dir="$NIXOS_CONFIG_DIR/modules/services"
    sudo mkdir -p "$services_dir"
    
    # Update nginx service module
    if [[ -f "$SCRIPT_DIR/modules/services/nginx.nix" ]]; then
        if [[ -f "$services_dir/nginx.nix" ]]; then
            # Backup existing
            sudo cp "$services_dir/nginx.nix" "$services_dir/nginx.nix.backup-$(date +%Y%m%d-%H%M%S)"
        fi
        sudo cp "$SCRIPT_DIR/modules/services/nginx.nix" "$services_dir/"
        success "Updated nginx service module"
    fi
    
    # Update PHP service module
    if [[ -f "$SCRIPT_DIR/modules/services/php.nix" ]]; then
        if [[ -f "$services_dir/php.nix" ]]; then
            # Backup existing
            sudo cp "$services_dir/php.nix" "$services_dir/php.nix.backup-$(date +%Y%m%d-%H%M%S)"
        fi
        sudo cp "$SCRIPT_DIR/modules/services/php.nix" "$services_dir/"
        success "Updated PHP service module"
    fi
    
    # Update MySQL service module
    if [[ -f "$SCRIPT_DIR/modules/services/mysql.nix" ]]; then
        if [[ -f "$services_dir/mysql.nix" ]]; then
            # Backup existing
            sudo cp "$services_dir/mysql.nix" "$services_dir/mysql.nix.backup-$(date +%Y%m%d-%H%M%S)"
        fi
        sudo cp "$SCRIPT_DIR/modules/services/mysql.nix" "$services_dir/"
        success "Updated MySQL service module"
    fi
    
    # Install networking module if it exists
    if [[ -f "$SCRIPT_DIR/modules/networking.nix" ]]; then
        if [[ -f "$NIXOS_CONFIG_DIR/modules/networking.nix" ]]; then
            # Backup existing
            sudo cp "$NIXOS_CONFIG_DIR/modules/networking.nix" "$NIXOS_CONFIG_DIR/modules/networking.nix.backup-$(date +%Y%m%d-%H%M%S)"
        fi
        sudo cp "$SCRIPT_DIR/modules/networking.nix" "$NIXOS_CONFIG_DIR/modules/"
        success "Updated networking module"
    fi
}

# Check imports in configuration.nix
check_configuration_imports() {
    log "Checking configuration.nix imports..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    
    echo "Current imports in configuration.nix:"
    grep -A 10 "imports.*=.*\[" "$config_file" | head -15 || echo "No imports section found"
    echo ""
    
    # Check for webserver module imports
    local needs_imports=()
    
    if ! grep -q "nginx-vhosts.nix" "$config_file"; then
        needs_imports+=("./modules/webserver/nginx-vhosts.nix")
    fi
    
    if ! grep -q "php-optimization.nix" "$config_file"; then
        needs_imports+=("./modules/webserver/php-optimization.nix")
    fi
    
    if ! grep -q "modules/services/nginx.nix" "$config_file"; then
        needs_imports+=("./modules/services/nginx.nix")
    fi
    
    if ! grep -q "modules/services/php.nix" "$config_file"; then
        needs_imports+=("./modules/services/php.nix")
    fi
    
    if ! grep -q "modules/services/mysql.nix" "$config_file"; then
        needs_imports+=("./modules/services/mysql.nix")
    fi
    
    if [[ ${#needs_imports[@]} -gt 0 ]]; then
        warning "Missing imports in configuration.nix:"
        for import in "${needs_imports[@]}"; do
            echo "  - $import"
        done
        echo ""
        
        read -p "Add missing imports to configuration.nix? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            add_missing_imports "${needs_imports[@]}"
        fi
    else
        success "All required imports are present"
    fi
}

# Add missing imports to configuration.nix
add_missing_imports() {
    local imports=("$@")
    
    log "Adding missing imports to configuration.nix..."
    
    for import in "${imports[@]}"; do
        sudo sed -i "/imports = \[/a\\    $import" "$NIXOS_CONFIG_DIR/configuration.nix"
        success "Added import: $import"
    done
}

# Test the configuration
test_configuration() {
    log "Testing NixOS configuration..."
    
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "Configuration syntax is valid"
        return 0
    else
        error "Configuration has errors:"
        sudo nixos-rebuild dry-build 2>&1 | head -15
        return 1
    fi
}

# Show final module structure
show_final_structure() {
    log "Final module structure:"
    echo ""
    echo "/etc/nixos/modules/"
    tree "$NIXOS_CONFIG_DIR/modules" 2>/dev/null || find "$NIXOS_CONFIG_DIR/modules" -type f -name "*.nix" | sort
    echo ""
}

# Main function
main() {
    echo "📦 Install Missing Webserver Modules"
    echo "===================================="
    echo ""
    
    if ! check_module_status; then
        echo ""
        echo "This will:"
        echo "1. Install missing webserver modules (nginx-vhosts.nix, php-optimization.nix)"
        echo "2. Update service modules with latest versions"
        echo "3. Check and fix imports in configuration.nix"
        echo "4. Test the configuration"
        echo ""
        
        read -p "Proceed with module installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
        
        install_webserver_modules
        update_service_modules
        check_configuration_imports
        
        if test_configuration; then
            show_final_structure
            
            echo ""
            echo "🎯 Next steps:"
            echo "1. Run: sudo nixos-rebuild switch"
            echo "2. The nginx-vhosts.nix module will be active"
            echo "3. Virtual hosts will be configured through NixOS modules"
        else
            error "Configuration test failed. Please fix errors before rebuilding."
        fi
    else
        success "All modules are already installed"
        show_final_structure
    fi
}

# Run main function
main "$@"