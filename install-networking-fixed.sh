#!/usr/bin/env bash

# NixOS Web Server Installation with Separate Networking Module (Fixed)
# This script installs the webserver with networking configuration in a separate module

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_CONFIG_DIR="/etc/nixos"
BACKUP_DIR="/etc/nixos/webserver-backups/$(date +%Y%m%d-%H%M%S)"

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

# Check privileges
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        SUDO_CMD=""
        success "Running as root"
    else
        if ! command -v sudo &> /dev/null; then
            error "This script requires root privileges or sudo access."
        fi
        
        if ! sudo -n true 2>/dev/null; then
            log "This script requires sudo access. You may be prompted for your password."
            if ! sudo -v; then
                error "Failed to obtain sudo privileges"
            fi
        fi
        SUDO_CMD="sudo"
        success "Sudo access confirmed"
    fi
}

# Create comprehensive backup
create_backup() {
    log "Creating comprehensive backup..."
    
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp -r "$NIXOS_CONFIG_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
    
    # Create restore script
    sudo tee "$BACKUP_DIR/restore.sh" > /dev/null << EOF
#!/bin/bash
# Restore script created on $(date)
echo "Restoring NixOS configuration from backup..."
sudo cp -r "$BACKUP_DIR"/* "$NIXOS_CONFIG_DIR/"
sudo rm "$NIXOS_CONFIG_DIR/restore.sh"
echo "Configuration restored. Run 'sudo nixos-rebuild switch' to apply."
EOF
    
    sudo chmod +x "$BACKUP_DIR/restore.sh"
    success "Backup created at: $BACKUP_DIR"
}

# Analyze existing structure
analyze_existing_structure() {
    log "Analyzing existing module structure..."
    
    local has_modules=false
    local has_services=false
    local has_hosts=false
    local has_networking=false
    
    # Check for existing directories
    if [[ -d "$NIXOS_CONFIG_DIR/modules" ]]; then
        has_modules=true
        success "Found existing modules directory"
    fi
    
    if [[ -d "$NIXOS_CONFIG_DIR/modules/services" ]]; then
        has_services=true
        success "Found existing services directory"
    fi
    
    if [[ -d "$NIXOS_CONFIG_DIR/modules/hosts" ]]; then
        has_hosts=true
        success "Found existing hosts directory"
    fi
    
    if [[ -f "$NIXOS_CONFIG_DIR/modules/networking.nix" ]]; then
        has_networking=true
        warning "Networking module already exists - will backup and replace"
    fi
    
    # Check for networking.hosts in king.nix
    if [[ -f "$NIXOS_CONFIG_DIR/modules/hosts/king.nix" ]]; then
        if grep -q "networking\.hosts" "$NIXOS_CONFIG_DIR/modules/hosts/king.nix"; then
            warning "Found networking.hosts in king.nix - will move to networking.nix"
        fi
    fi
    
    # Write analysis with proper permissions
    sudo tee "$BACKUP_DIR/structure-analysis.txt" > /dev/null << EOF
STRUCTURE_ANALYSIS:
HAS_MODULES=$has_modules
HAS_SERVICES=$has_services
HAS_HOSTS=$has_hosts
HAS_NETWORKING=$has_networking
EOF
}

# Install networking module
install_networking_module() {
    log "Installing networking module..."
    
    # Ensure modules directory exists
    sudo mkdir -p "$NIXOS_CONFIG_DIR/modules"
    
    # Install networking module
    sudo cp "$SCRIPT_DIR/modules/networking.nix" "$NIXOS_CONFIG_DIR/modules/"
    
    success "Networking module installed: $NIXOS_CONFIG_DIR/modules/networking.nix"
}

# Install service modules
install_service_modules() {
    log "Installing enhanced service modules..."
    
    local services_dir="$NIXOS_CONFIG_DIR/modules/services"
    
    # Ensure services directory exists
    sudo mkdir -p "$services_dir"
    
    # Install enhanced service modules
    sudo cp "$SCRIPT_DIR/modules/services/nginx.nix" "$services_dir/"
    sudo cp "$SCRIPT_DIR/modules/services/php.nix" "$services_dir/"
    sudo cp "$SCRIPT_DIR/modules/services/mysql.nix" "$services_dir/"
    
    success "Enhanced service modules installed in: $services_dir"
}

# Install webserver modules
install_webserver_modules() {
    log "Installing webserver-specific modules..."
    
    local webserver_dir="$NIXOS_CONFIG_DIR/modules/webserver"
    
    # Create webserver directory
    sudo mkdir -p "$webserver_dir"
    
    # Install webserver modules
    sudo cp "$SCRIPT_DIR/modules/webserver/nginx-vhosts.nix" "$webserver_dir/"
    sudo cp "$SCRIPT_DIR/modules/webserver/php-optimization.nix" "$webserver_dir/"
    
    success "Webserver modules installed in: $webserver_dir"
}

# Install main webserver module
install_main_module() {
    log "Installing main webserver module..."
    
    # Install the main webserver.nix
    sudo cp "$SCRIPT_DIR/webserver.nix" "$NIXOS_CONFIG_DIR/"
    
    success "Main webserver module installed: $NIXOS_CONFIG_DIR/webserver.nix"
}

# Clean up king.nix (remove networking.hosts if present)
cleanup_king_config() {
    log "Cleaning up host configuration..."
    
    local king_config="$NIXOS_CONFIG_DIR/modules/hosts/king.nix"
    
    if [[ -f "$king_config" ]]; then
        if grep -q "networking\.hosts" "$king_config"; then
            log "Removing networking.hosts from king.nix (moved to networking.nix)"
            
            # Remove networking.hosts section from king.nix
            sudo sed -i '/networking\.hosts.*=/,/};/d' "$king_config"
            
            # Clean up any empty networking blocks
            sudo sed -i '/networking[[:space:]]*=[[:space:]]*{[[:space:]]*}/d' "$king_config"
            
            success "Cleaned up king.nix - networking moved to networking.nix"
        fi
    else
        # Create a minimal king.nix if it doesn't exist
        sudo mkdir -p "$NIXOS_CONFIG_DIR/modules/hosts"
        sudo tee "$king_config" > /dev/null << 'EOF'
# Host-specific configuration for king
{ config, pkgs, lib, ... }:

{
  # Host-specific settings can go here
  # Networking configuration is now in modules/networking.nix
}
EOF
        success "Created minimal king.nix configuration"
    fi
}

# Setup web content
setup_web_content() {
    log "Setting up web content..."
    
    # Create web directories
    sudo mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}
    
    # Copy web content if available
    if [[ -d "$SCRIPT_DIR/web-content" ]]; then
        log "Copying web content from script directory..."
        sudo cp -r "$SCRIPT_DIR/web-content/dashboard"/* /var/www/dashboard/ 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample1"/* /var/www/sample1/ 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample2"/* /var/www/sample2/ 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample3"/* /var/www/sample3/ 2>/dev/null || true
    else
        warning "Web content directory not found. Creating basic placeholder files..."
        
        # Create basic index files for each site
        for site in dashboard sample1 sample2 sample3; do
            sudo tee "/var/www/$site/index.php" > /dev/null << EOF
<?php
echo "<h1>Welcome to $site.local</h1>";
echo "<p>Modular NixOS webserver with separate networking module</p>";
echo "<p>PHP Version: " . PHP_VERSION . "</p>";
echo "<p>Server time: " . date('Y-m-d H:i:s') . "</p>";

if (version_compare(PHP_VERSION, '8.4.0', '>=')) {
    echo "<h2>🚀 PHP 8.4 Features Available</h2>";
    echo "<ul>";
    echo "<li>Property hooks</li>";
    echo "<li>Asymmetric visibility</li>";
    echo "<li>JIT compilation</li>";
    echo "<li>Performance improvements</li>";
    echo "</ul>";
}
?>
EOF
        done
    fi
    
    # Set proper permissions
    sudo chown -R nginx:nginx /var/www
    sudo chmod -R 755 /var/www
    
    success "Web content set up"
}

# Test configuration
test_configuration() {
    log "Testing configuration syntax..."
    
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "Configuration syntax is valid"
    else
        warning "Configuration syntax test failed - checking individual components..."
        
        # Test networking module syntax
        if nix-instantiate --parse "$NIXOS_CONFIG_DIR/modules/networking.nix" &>/dev/null; then
            success "Networking module syntax is valid"
        else
            error "Networking module has syntax errors"
        fi
        
        # Test webserver module syntax
        if nix-instantiate --parse "$NIXOS_CONFIG_DIR/webserver.nix" &>/dev/null; then
            success "Webserver module syntax is valid"
        else
            error "Webserver module has syntax errors"
        fi
        
        error "Main configuration still has syntax errors. Please check manually."
    fi
}

# Generate integration instructions
generate_instructions() {
    sudo tee "$NIXOS_CONFIG_DIR/NETWORKING_MODULE_SETUP.md" > /dev/null << EOF
# Networking Module Setup Complete

## New Module Structure
\`\`\`
/etc/nixos/
├── configuration.nix                       # Main config
├── webserver.nix                          # Webserver orchestrator
├── modules/
│   ├── networking.nix                     # ALL networking configuration
│   ├── services/
│   │   ├── nginx.nix                      # Enhanced nginx
│   │   ├── php.nix                        # Enhanced PHP-FPM
│   │   └── mysql.nix                      # Enhanced MySQL
│   ├── webserver/
│   │   ├── nginx-vhosts.nix              # Virtual hosts
│   │   └── php-optimization.nix          # PHP optimization
│   └── hosts/
│       └── king.nix                       # Host-specific (no networking)
\`\`\`

## What Was Moved
- ✅ All networking configuration moved to \`modules/networking.nix\`
- ✅ networking.hosts moved from \`modules/hosts/king.nix\`
- ✅ Firewall configuration centralized
- ✅ Network optimization settings included

## Integration Steps

### 1. Import webserver module
Add to your main configuration:
\`\`\`nix
{
  imports = [
    ./webserver.nix
    # ... your other imports
  ];
}
\`\`\`

### 2. Rebuild the system
\`\`\`bash
sudo nixos-rebuild switch
\`\`\`

## Accessing Services
After successful rebuild:
- Dashboard: http://dashboard.local
- phpMyAdmin: http://phpmyadmin.local
- Sample sites: http://sample1.local, http://sample2.local, http://sample3.local

## Backup Location
- Full backup: $BACKUP_DIR
- Restore command: \`sudo $BACKUP_DIR/restore.sh\`
EOF

    success "Setup instructions created: $NIXOS_CONFIG_DIR/NETWORKING_MODULE_SETUP.md"
}

# Main function
main() {
    echo "🌐 NixOS Webserver Installation with Separate Networking Module (Fixed)"
    echo "====================================================================="
    echo ""
    
    check_privileges
    
    echo "This installation will:"
    echo "  • Create a separate networking.nix module for all networking config"
    echo "  • Move networking.hosts from king.nix to networking.nix"
    echo "  • Install enhanced service modules with conflict resolution"
    echo "  • Create webserver-specific configuration modules"
    echo "  • Centralize firewall and network optimization"
    echo ""
    
    read -p "Proceed with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation cancelled by user"
    fi
    
    create_backup
    analyze_existing_structure
    install_networking_module
    install_service_modules
    install_webserver_modules
    install_main_module
    cleanup_king_config
    setup_web_content
    test_configuration
    generate_instructions
    
    echo ""
    success "Networking module installation complete!"
    echo ""
    echo "🎯 Next steps:"
    echo "1. Import webserver.nix in your main configuration"
    echo "2. Run: sudo nixos-rebuild switch"
    echo "3. Access services at their .local domains"
    echo ""
    echo "📦 Backup location: $BACKUP_DIR"
    echo "🌐 Networking config: $NIXOS_CONFIG_DIR/modules/networking.nix"
    echo "📋 Instructions: $NIXOS_CONFIG_DIR/NETWORKING_MODULE_SETUP.md"
    echo ""
    warning "All networking configuration is now centralized in modules/networking.nix!"
}

# Run main function
main "$@"