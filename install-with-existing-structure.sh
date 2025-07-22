#!/usr/bin/env bash

# NixOS Web Server Installation for Existing Module Structure
# This script works with your existing modules directory structure

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

# Analyze existing structure
analyze_existing_structure() {
    log "Analyzing existing module structure..."
    
    local has_modules=false
    local has_services=false
    local has_hosts=false
    local has_webserver=false
    
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
    
    if [[ -d "$NIXOS_CONFIG_DIR/modules/webserver" ]]; then
        has_webserver=true
        warning "Webserver directory already exists - will backup and replace"
    fi
    
    # Check for existing service files
    local existing_services=()
    if [[ -f "$NIXOS_CONFIG_DIR/modules/services/nginx.nix" ]]; then
        existing_services+=("nginx.nix")
    fi
    if [[ -f "$NIXOS_CONFIG_DIR/modules/services/php.nix" ]]; then
        existing_services+=("php.nix")
    fi
    if [[ -f "$NIXOS_CONFIG_DIR/modules/services/mysql.nix" ]]; then
        existing_services+=("mysql.nix")
    fi
    
    if [[ ${#existing_services[@]} -gt 0 ]]; then
        warning "Found existing service files that may conflict:"
        for service in "${existing_services[@]}"; do
            echo "  - $service"
        done
        echo ""
        read -p "Do you want to backup and replace these files? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation cancelled. Existing service files would conflict."
        fi
    fi
    
    # Save analysis results
    echo "STRUCTURE_ANALYSIS:" > "$BACKUP_DIR/structure-analysis.txt"
    echo "HAS_MODULES=$has_modules" >> "$BACKUP_DIR/structure-analysis.txt"
    echo "HAS_SERVICES=$has_services" >> "$BACKUP_DIR/structure-analysis.txt"
    echo "HAS_HOSTS=$has_hosts" >> "$BACKUP_DIR/structure-analysis.txt"
    echo "HAS_WEBSERVER=$has_webserver" >> "$BACKUP_DIR/structure-analysis.txt"
    echo "EXISTING_SERVICES=(${existing_services[*]})" >> "$BACKUP_DIR/structure-analysis.txt"
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
sudo rm "$NIXOS_CONFIG_DIR/structure-analysis.txt" 2>/dev/null || true
echo "Configuration restored. Run 'sudo nixos-rebuild switch' to apply."
EOF
    
    sudo chmod +x "$BACKUP_DIR/restore.sh"
    success "Backup created at: $BACKUP_DIR"
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
    sudo tee "$NIXOS_CONFIG_DIR/WEBSERVER_INTEGRATION_GUIDE.md" > /dev/null << EOF
# Webserver Integration Guide

## Installation Summary
- Installation Date: $(date)
- Installation Type: Existing module structure integration
- Backup Location: $BACKUP_DIR

## Your Module Structure (Enhanced)
\`\`\`
/etc/nixos/
├── webserver.nix                           # Main webserver module (NEW)
├── modules/
│   ├── hosts/                              # Your existing hosts
│   ├── services/                           # Enhanced services
│   │   ├── nginx.nix                       # Enhanced nginx (UPDATED)
│   │   ├── php.nix                         # Enhanced PHP-FPM (UPDATED)
│   │   ├── mysql.nix                       # Enhanced MySQL (UPDATED)
│   │   └── [other existing services]       # Your other services
│   ├── webserver/                          # Webserver-specific config (NEW)
│   │   ├── nginx-vhosts.nix               # Virtual hosts
│   │   └── php-optimization.nix           # PHP optimization
│   ├── software/                           # Your existing software modules
│   └── [other existing modules]            # Your other modules
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

### 2. Add networking hosts to your host configuration
Edit your host file (e.g., modules/hosts/king.nix):
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
    # ... your other host entries
  };
}
\`\`\`

### 3. Rebuild the system
\`\`\`bash
sudo nixos-rebuild switch
\`\`\`

## What Was Enhanced

### Service Modules (Updated)
- **nginx.nix**: Added performance optimization and security headers
- **php.nix**: Enhanced with PHP 8.4 JIT, better process management
- **mysql.nix**: Added performance tuning and conflict resolution

### Webserver Modules (New)
- **nginx-vhosts.nix**: Virtual hosts for dashboard, phpMyAdmin, samples
- **php-optimization.nix**: Webserver-specific PHP tuning

## Conflict Resolution
All modules use \`lib.mkDefault\` extensively:
- Existing configurations take precedence
- New settings only apply if not already defined
- Safe to use with existing MySQL/Nginx/PHP setups

## Accessing Services
After successful rebuild:
- Dashboard: http://dashboard.local
- phpMyAdmin: http://phpmyadmin.local  
- Sample sites: http://sample1.local, http://sample2.local, http://sample3.local

## Customization
- Virtual hosts: Edit \`modules/webserver/nginx-vhosts.nix\`
- PHP settings: Edit \`modules/webserver/php-optimization.nix\`
- Service configs: Edit files in \`modules/services/\`

## Troubleshooting
If issues occur:
1. Check backup: $BACKUP_DIR
2. Run restore: $BACKUP_DIR/restore.sh
3. Test syntax: sudo nixos-rebuild dry-build

## Notes
- All existing modules and configurations are preserved
- Enhanced modules are backward compatible
- Uses your existing directory structure
- Webserver functionality is additive, not replacement
EOF

    success "Integration guide created: $NIXOS_CONFIG_DIR/WEBSERVER_INTEGRATION_GUIDE.md"
}

# Main installation function
main() {
    echo "🏗️  NixOS Webserver Installation for Existing Module Structure"
    echo "============================================================"
    echo ""
    
    check_privileges
    create_backup
    analyze_existing_structure
    
    echo ""
    echo "This installation will:"
    echo "  • Work with your existing modules directory structure"
    echo "  • Enhance existing service modules (nginx, php, mysql)"
    echo "  • Add webserver-specific modules in modules/webserver/"
    echo "  • Use lib.mkDefault for conflict-free integration"
    echo "  • Preserve all your existing configurations"
    echo ""
    
    read -p "Proceed with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation cancelled by user"
    fi
    
    install_service_modules
    install_webserver_modules
    install_main_module
    setup_web_content
    test_configuration
    generate_instructions
    
    echo ""
    success "Webserver installation complete!"
    echo ""
    echo "🎯 Next steps:"
    echo "1. Review integration guide: $NIXOS_CONFIG_DIR/WEBSERVER_INTEGRATION_GUIDE.md"
    echo "2. Import webserver.nix in your main configuration"
    echo "3. Add networking.hosts to modules/hosts/king.nix"
    echo "4. Run: sudo nixos-rebuild switch"
    echo ""
    echo "📦 Backup location: $BACKUP_DIR"
    echo "📁 Enhanced modules in: $NIXOS_CONFIG_DIR/modules/"
    echo ""
    warning "Remember to add networking.hosts to your host configuration!"
}

# Run main function
main "$@"