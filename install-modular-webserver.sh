#!/usr/bin/env bash

# Modular NixOS Web Server Installation Script
# Handles both new and existing installations with proper module structure

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

# Detect installation type
detect_installation_type() {
    log "Detecting installation type..."
    
    local has_flake=false
    local has_modules_dir=false
    local has_existing_services=false
    
    # Check for flake
    if [[ -f "$NIXOS_CONFIG_DIR/flake.nix" ]]; then
        has_flake=true
        success "Detected flake-based configuration"
    fi
    
    # Check for existing modules directory
    if [[ -d "$NIXOS_CONFIG_DIR/modules" ]]; then
        has_modules_dir=true
        success "Detected existing modules directory"
    fi
    
    # Check for existing services in modules
    if [[ -d "$NIXOS_CONFIG_DIR/modules/services" ]]; then
        has_existing_services=true
        success "Detected existing services modules"
    fi
    
    echo "INSTALLATION_TYPE:" > "$BACKUP_DIR/installation-info.txt"
    echo "HAS_FLAKE=$has_flake" >> "$BACKUP_DIR/installation-info.txt"
    echo "HAS_MODULES_DIR=$has_modules_dir" >> "$BACKUP_DIR/installation-info.txt"
    echo "HAS_EXISTING_SERVICES=$has_existing_services" >> "$BACKUP_DIR/installation-info.txt"
    
    if [[ "$has_existing_services" == "true" ]]; then
        log "Will use existing /etc/nixos/modules/services directory"
        return 0
    elif [[ "$has_modules_dir" == "true" ]]; then
        log "Will create services directory in existing modules structure"
        return 1
    else
        log "Will create new modules structure"
        return 2
    fi
}

# Create backup
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
sudo rm "$NIXOS_CONFIG_DIR/installation-info.txt" 2>/dev/null || true
echo "Configuration restored. Run 'sudo nixos-rebuild switch' to apply."
EOF
    
    sudo chmod +x "$BACKUP_DIR/restore.sh"
    success "Backup created at: $BACKUP_DIR"
}

# Install service modules
install_service_modules() {
    local installation_type=$1
    
    log "Installing webserver service modules..."
    
    if [[ $installation_type -eq 0 ]]; then
        # Use existing /etc/nixos/modules/services
        local services_dir="$NIXOS_CONFIG_DIR/modules/services"
        log "Using existing services directory: $services_dir"
    elif [[ $installation_type -eq 1 ]]; then
        # Create services directory in existing modules
        local services_dir="$NIXOS_CONFIG_DIR/modules/services"
        sudo mkdir -p "$services_dir"
        log "Created services directory in existing modules: $services_dir"
    else
        # Create new modules structure
        local services_dir="$NIXOS_CONFIG_DIR/modules/services"
        sudo mkdir -p "$services_dir"
        log "Created new modules structure: $services_dir"
    fi
    
    # Copy service modules
    sudo cp "$SCRIPT_DIR/modules/services/webserver-nginx.nix" "$services_dir/"
    sudo cp "$SCRIPT_DIR/modules/services/webserver-php.nix" "$services_dir/"
    sudo cp "$SCRIPT_DIR/modules/services/webserver-mysql.nix" "$services_dir/"
    
    success "Service modules installed in: $services_dir"
}

# Install config modules
install_config_modules() {
    log "Installing webserver configuration modules..."
    
    local config_dir="$NIXOS_CONFIG_DIR/modules/config/webserver"
    sudo mkdir -p "$config_dir"
    
    # Copy config modules
    sudo cp "$SCRIPT_DIR/modules/config/webserver/virtual-hosts.nix" "$config_dir/"
    sudo cp "$SCRIPT_DIR/modules/config/webserver/security.nix" "$config_dir/"
    sudo cp "$SCRIPT_DIR/modules/config/webserver/optimization.nix" "$config_dir/"
    
    success "Configuration modules installed in: $config_dir"
}

# Install main webserver module
install_main_module() {
    log "Installing main webserver module..."
    
    # Create webserver.nix that imports from the correct locations
    sudo tee "$NIXOS_CONFIG_DIR/webserver.nix" > /dev/null << 'EOF'
# Main Web Server Module
# This module imports all required services and configurations

{ config, pkgs, lib, ... }:

{
  imports = [
    # Import service modules
    ./modules/services/webserver-nginx.nix
    ./modules/services/webserver-php.nix
    ./modules/services/webserver-mysql.nix
    
    # Import webserver-specific configuration
    ./modules/config/webserver/virtual-hosts.nix
    ./modules/config/webserver/security.nix
    ./modules/config/webserver/optimization.nix
  ];

  # High-level webserver configuration
  # System packages for web development
  environment.systemPackages = with pkgs; [
    tree
    htop
    php  # In NixOS 25.05, 'php' = PHP 8.4
  ];

  # Ensure web directories exist
  system.activationScripts.webserver-setup = ''
    # Create web directories
    mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}
    chown -R nginx:nginx /var/www
    chmod -R 755 /var/www
  '';

  # Firewall configuration for web services
  networking.firewall.allowedTCPPorts = lib.mkAfter [ 80 443 ];
}
EOF

    success "Main webserver module installed: $NIXOS_CONFIG_DIR/webserver.nix"
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
echo "<p>This is a placeholder page. Replace with your actual content.</p>";
echo "<p>PHP Version: " . PHP_VERSION . "</p>";
echo "<p>Server time: " . date('Y-m-d H:i:s') . "</p>";

// Display PHP 8.4 features
if (version_compare(PHP_VERSION, '8.4.0', '>=')) {
    echo "<h2>🚀 PHP 8.4 Features Available</h2>";
    echo "<ul>";
    echo "<li>Property hooks</li>";
    echo "<li>Asymmetric visibility</li>";
    echo "<li>New array functions</li>";
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
        error "Configuration syntax error detected. Check the configuration manually."
    fi
}

# Generate integration instructions
generate_instructions() {
    local installation_type=$1
    
    sudo tee "$NIXOS_CONFIG_DIR/WEBSERVER_INTEGRATION.md" > /dev/null << EOF
# Webserver Integration Instructions

## Installation Summary
- Installation Date: $(date)
- Installation Type: $([[ $installation_type -eq 0 ]] && echo "Existing services directory" || [[ $installation_type -eq 1 ]] && echo "Existing modules directory" || echo "New modules structure")
- Backup Location: $BACKUP_DIR

## Module Structure Created
\`\`\`
/etc/nixos/
├── webserver.nix                           # Main webserver module
├── modules/
│   ├── services/
│   │   ├── webserver-nginx.nix            # Nginx service
│   │   ├── webserver-php.nix              # PHP-FPM service
│   │   └── webserver-mysql.nix            # MySQL service
│   └── config/
│       └── webserver/
│           ├── virtual-hosts.nix          # Virtual hosts config
│           ├── security.nix               # Security hardening
│           └── optimization.nix           # Performance tuning
\`\`\`

## Integration Steps

### 1. Import the webserver module
Add to your main configuration or flake:
\`\`\`nix
{
  imports = [
    ./webserver.nix
    # ... your other imports
  ];
}
\`\`\`

### 2. Add networking hosts
Add to your host configuration (e.g., modules/hosts/king.nix):
\`\`\`nix
{
  networking.hosts = {
    "127.0.0.1" = [ 
      "localhost" 
      "dashboard.local" 
      "phpmyadmin.local" 
      "sample1.local" 
      "sample2.local" 
      "sample3.local" 
    ];
    "127.0.0.2" = [ "king" ];
  };
}
\`\`\`

### 3. Rebuild the system
\`\`\`bash
sudo nixos-rebuild switch
\`\`\`

## Conflict Resolution
The modules use lib.mkDefault extensively to avoid conflicts with existing configurations:
- MySQL package can be overridden by existing configurations
- Nginx settings merge with existing virtual hosts
- Firewall ports are appended to existing configurations

## Accessing Services
After successful rebuild:
- Dashboard: http://dashboard.local
- phpMyAdmin: http://phpmyadmin.local
- Sample sites: http://sample1.local, http://sample2.local, http://sample3.local

## Troubleshooting
If you encounter issues:
1. Check the backup: $BACKUP_DIR
2. Run the restore script: $BACKUP_DIR/restore.sh
3. Review the configuration syntax: sudo nixos-rebuild dry-build

## Customization
- Virtual hosts: Edit modules/config/webserver/virtual-hosts.nix
- Security settings: Edit modules/config/webserver/security.nix
- Performance tuning: Edit modules/config/webserver/optimization.nix
EOF

    success "Integration instructions created: $NIXOS_CONFIG_DIR/WEBSERVER_INTEGRATION.md"
}

# Main installation function
main() {
    echo "🏗️  Modular NixOS Web Server Installation"
    echo "========================================"
    echo ""
    
    check_privileges
    create_backup
    
    # Detect installation type
    detect_installation_type
    local installation_type=$?
    
    echo ""
    echo "This installation will:"
    echo "  • Use existing modules directory structure when available"
    echo "  • Install webserver services in modules/services/"
    echo "  • Create webserver config modules in modules/config/webserver/"
    echo "  • Use lib.mkDefault for conflict-free integration"
    echo "  • Create comprehensive backup and restore capability"
    echo ""
    
    read -p "Proceed with modular installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation cancelled by user"
    fi
    
    install_service_modules $installation_type
    install_config_modules
    install_main_module
    setup_web_content
    test_configuration
    generate_instructions $installation_type
    
    echo ""
    success "Modular webserver installation complete!"
    echo ""
    echo "🎯 Next steps:"
    echo "1. Review integration instructions: $NIXOS_CONFIG_DIR/WEBSERVER_INTEGRATION.md"
    echo "2. Import webserver.nix in your main configuration"
    echo "3. Add networking.hosts to your host configuration"
    echo "4. Run: sudo nixos-rebuild switch"
    echo ""
    echo "📦 Backup location: $BACKUP_DIR"
    echo "📁 Module structure created in: $NIXOS_CONFIG_DIR/modules/"
    echo ""
    warning "Remember to add networking.hosts to your host-specific configuration!"
}

# Run main function
main "$@"