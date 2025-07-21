#!/usr/bin/env bash

# NixOS Web Server Setup Script
# This script helps set up the web directories and content after NixOS rebuild

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
    exit 1
}

# Check if running as root or with sudo
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        # Running as root - no need for sudo
        SUDO_CMD=""
        success "Running as root"
    else
        # Check if sudo is available and user can use it
        if ! command -v sudo &> /dev/null; then
            error "This script requires root privileges or sudo access. Please install sudo or run as root."
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

# Function to run commands with appropriate privileges
run_privileged() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

echo "🚀 Setting up NixOS Web Server Environment..."

# Check privileges first
check_privileges

# Store original directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create web directories
log "Creating web directories..."
run_privileged mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}

# Copy web content to appropriate directories
log "Copying web content..."
if [[ -d "$SCRIPT_DIR/web-content/dashboard" ]]; then
    run_privileged cp -r "$SCRIPT_DIR/web-content/dashboard"/* /var/www/dashboard/ 2>/dev/null || warning "Dashboard content not found"
else
    warning "Dashboard content directory not found"
fi

if [[ -d "$SCRIPT_DIR/web-content/sample1" ]]; then
    run_privileged cp -r "$SCRIPT_DIR/web-content/sample1"/* /var/www/sample1/ 2>/dev/null || warning "Sample1 content not found"
else
    warning "Sample1 content directory not found"
fi

if [[ -d "$SCRIPT_DIR/web-content/sample2" ]]; then
    run_privileged cp -r "$SCRIPT_DIR/web-content/sample2"/* /var/www/sample2/ 2>/dev/null || warning "Sample2 content not found"
else
    warning "Sample2 content directory not found"
fi

if [[ -d "$SCRIPT_DIR/web-content/sample3" ]]; then
    run_privileged cp -r "$SCRIPT_DIR/web-content/sample3"/* /var/www/sample3/ 2>/dev/null || warning "Sample3 content not found"
else
    warning "Sample3 content directory not found"
fi

# Download and setup phpMyAdmin
log "Setting up phpMyAdmin..."
cd /tmp
if [ ! -f "phpMyAdmin-5.2.1-all-languages.tar.gz" ]; then
    if ! wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz; then
        warning "Failed to download phpMyAdmin. You'll need to set it up manually."
    fi
fi

if [[ -f "phpMyAdmin-5.2.1-all-languages.tar.gz" ]]; then
    tar -xzf phpMyAdmin-5.2.1-all-languages.tar.gz
    run_privileged cp -r phpMyAdmin-5.2.1-all-languages/* /var/www/phpmyadmin/
    
    # Copy phpMyAdmin config if available
    if [[ -f "$SCRIPT_DIR/web-content/phpmyadmin/config.inc.php" ]]; then
        run_privileged cp "$SCRIPT_DIR/web-content/phpmyadmin/config.inc.php" /var/www/phpmyadmin/
    else
        warning "phpMyAdmin config not found, creating basic config"
        run_privileged tee /var/www/phpmyadmin/config.inc.php > /dev/null << 'EOF'
<?php
declare(strict_types=1);

$cfg['blowfish_secret'] = 'nixos-webserver-phpmyadmin-secret-key-2024';

$i = 0;
$i++;
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['host'] = 'localhost';
$cfg['Servers'][$i]['compress'] = false;
$cfg['Servers'][$i]['AllowNoPassword'] = false;

// Security settings
$cfg['ForceSSL'] = false;
$cfg['CheckConfigurationPermissions'] = true;
$cfg['AllowArbitraryServer'] = false;
EOF
    fi
fi

# Return to original directory
cd "$SCRIPT_DIR"

# Set proper permissions
log "Setting permissions..."
run_privileged chown -R nginx:nginx /var/www
run_privileged chmod -R 755 /var/www

# Create phpMyAdmin configuration storage
log "Setting up phpMyAdmin configuration storage..."
if command -v mysql &> /dev/null; then
    run_privileged mysql -u root << 'EOF' || warning "Failed to setup phpMyAdmin database - you may need to do this manually after MySQL is running"
CREATE DATABASE IF NOT EXISTS phpmyadmin;
USE phpmyadmin;
SOURCE /var/www/phpmyadmin/sql/create_tables.sql;
EOF
else
    warning "MySQL not found - database setup will be skipped"
fi

# Note: /etc/hosts is managed by NixOS configuration (networking.extraHosts)
log "Local domain configuration..."
success "Local domains are configured in NixOS configuration.nix (networking.extraHosts)"
log "Domains available after nixos-rebuild switch:"
log "  • dashboard.local"
log "  • phpmyadmin.local" 
log "  • sample1.local"
log "  • sample2.local"
log "  • sample3.local"

success "Setup complete!"
echo ""
echo "🎯 Next steps:"
echo "1. Copy configuration.nix to /etc/nixos/configuration.nix"
echo "2. Run: sudo nixos-rebuild switch"
echo "3. Run this setup script: ./setup-script.sh"
echo ""
echo "🌐 Access your sites at:"
echo "   • Dashboard: http://dashboard.local"
echo "   • phpMyAdmin: http://phpmyadmin.local"
echo "   • Sample 1 (E-commerce): http://sample1.local"
echo "   • Sample 2 (Blog): http://sample2.local"
echo "   • Sample 3 (Portfolio): http://sample3.local"