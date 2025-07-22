#!/usr/bin/env bash

# Enhanced NixOS Web Server Setup Script with Virtual Host Management (PHP 8.4)
# This script sets up the complete web environment with management capabilities

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

echo "🚀 Setting up Enhanced NixOS Web Server Environment with PHP 8.4..."

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

# Download and setup phpMyAdmin with PHP 8.4 compatibility
log "Setting up phpMyAdmin with PHP 8.4 compatibility..."
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

$cfg['blowfish_secret'] = 'nixos-webserver-phpmyadmin-secret-key-2024-php84';

$i = 0;
$i++;
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['host'] = 'localhost';
$cfg['Servers'][$i]['compress'] = false;
$cfg['Servers'][$i]['AllowNoPassword'] = false;

// PHP 8.4 optimizations
$cfg['OBGzip'] = true;
$cfg['PersistentConnections'] = true;
$cfg['ExecTimeLimit'] = 300;
$cfg['MemoryLimit'] = '256M';

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

# Create PHP error log
log "Setting up PHP 8.4 error logging..."
run_privileged mkdir -p /var/log
run_privileged touch /var/log/php_errors.log
run_privileged chown nginx:nginx /var/log/php_errors.log
run_privileged chmod 644 /var/log/php_errors.log

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

# Note: /etc/hosts is managed by NixOS configuration (networking.hosts)
log "Local domain configuration..."
success "Local domains are configured in NixOS configuration.nix (networking.hosts)"
log "Domains available after nixos-rebuild switch:"
log "  • dashboard.local"
log "  • phpmyadmin.local" 
log "  • sample1.local"
log "  • sample2.local"
log "  • sample3.local"

# Create backup directory for NixOS configurations
log "Creating backup directory..."
run_privileged mkdir -p /etc/nixos/backups

# Set up log rotation for virtual host management
log "Setting up log management..."
run_privileged mkdir -p /var/log/webserver-dashboard
run_privileged chown nginx:nginx /var/log/webserver-dashboard

# Create helper script for NixOS rebuilds with PHP 8.4
log "Creating helper scripts..."
run_privileged tee /usr/local/bin/rebuild-webserver > /dev/null << 'EOF'
#!/bin/bash

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi

echo "🔄 Rebuilding NixOS configuration with PHP 8.4..."
$SUDO_CMD nixos-rebuild switch
if [ $? -eq 0 ]; then
    echo "✅ NixOS rebuild successful!"
    echo "🌐 Restarting web services..."
    $SUDO_CMD systemctl restart nginx
    $SUDO_CMD systemctl restart phpfpm
    echo "✅ Web services restarted!"
    if command -v php &> /dev/null; then
        echo "🚀 PHP Version: $(php --version | head -1)"
    fi
else
    echo "❌ NixOS rebuild failed!"
    exit 1
fi
EOF

run_privileged chmod +x /usr/local/bin/rebuild-webserver

# Create virtual host template with PHP 8.4 optimizations
log "Creating virtual host template..."
run_privileged mkdir -p /etc/nixos/templates
run_privileged tee /etc/nixos/templates/virtualhost.nix > /dev/null << 'EOF'
# Virtual Host Template for PHP 8.4
# Replace DOMAIN_NAME with actual domain
"DOMAIN_NAME" = {
  root = "/var/www/DOMAIN_NAME";
  index = "index.php index.html";
  locations = {
    "/" = {
      tryFiles = "$uri $uri/ /index.php?$query_string";
    };
    "~ \\.php$" = {
      extraConfig = ''
        fastcgi_pass unix:${config.services.phpfpm.pools.www.socket};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PHP_VALUE "auto_prepend_file=none";
        fastcgi_read_timeout 300;
        include ${pkgs.nginx}/conf/fastcgi_params;
      '';
    };
    "~ /\\.ht" = {
      extraConfig = "deny all;";
    };
  };
};
EOF

# Create database management helper
log "Creating database management helper..."
run_privileged tee /usr/local/bin/create-site-db > /dev/null << 'EOF'
#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <database_name>"
    exit 1
fi

DB_NAME=$1
echo "Creating database: $DB_NAME"

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    MYSQL_CMD="mysql"
else
    MYSQL_CMD="sudo mysql"
fi

$MYSQL_CMD -u root << SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO 'webuser'@'localhost';
FLUSH PRIVILEGES;
SQL

if [ $? -eq 0 ]; then
    echo "✅ Database $DB_NAME created successfully!"
else
    echo "❌ Failed to create database $DB_NAME"
    exit 1
fi
EOF

run_privileged chmod +x /usr/local/bin/create-site-db

# Create site directory helper with PHP 8.4 template
log "Creating site directory helper..."
run_privileged tee /usr/local/bin/create-site-dir > /dev/null << 'EOF'
#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <domain> <site_name>"
    exit 1
fi

DOMAIN=$1
SITE_NAME=$2
SITE_DIR="/var/www/$DOMAIN"

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi

echo "Creating site directory: $SITE_DIR"
$SUDO_CMD mkdir -p "$SITE_DIR"

# Create PHP 8.4 optimized index.php
$SUDO_CMD tee "$SITE_DIR/index.php" > /dev/null << PHP
<?php
// $SITE_NAME - PHP 8.4 Ready
echo '<h1>Welcome to $SITE_NAME</h1>';
echo '<p>This site is hosted on $DOMAIN</p>';
echo '<p>PHP Version: ' . PHP_VERSION . '</p>';
echo '<p>Created: ' . date('Y-m-d H:i:s') . '</p>';

if (version_compare(PHP_VERSION, '8.4.0', '>=')) {
    echo '<h2>🚀 PHP 8.4 Features Available</h2>';
    echo '<ul>';
    echo '<li>Property hooks for cleaner object-oriented code</li>';
    echo '<li>Asymmetric visibility modifiers</li>';
    echo '<li>Enhanced performance and memory optimizations</li>';
    echo '<li>New array and string manipulation functions</li>';
    echo '<li>Improved type system and error handling</li>';
    echo '</ul>';
}
?>
PHP

# Set proper ownership
$SUDO_CMD chown -R nginx:nginx "$SITE_DIR"
$SUDO_CMD chmod -R 755 "$SITE_DIR"

echo "✅ Site directory created successfully with PHP 8.4 template!"
echo "📝 PHP 8.4 optimized index.php file created"
echo "🔐 Permissions set correctly"
EOF

run_privileged chmod +x /usr/local/bin/create-site-dir

success "Enhanced setup complete with PHP 8.4!"
echo ""
echo "🎯 Next steps:"
echo "1. Copy configuration.nix to /etc/nixos/configuration.nix"
echo "2. Run: sudo nixos-rebuild switch"
echo "3. Run this setup script: ./enhanced-setup-script.sh"
echo ""
echo "🌐 Access your sites at:"
echo "   • Dashboard (with Virtual Host Management): http://dashboard.local"
echo "   • phpMyAdmin: http://phpmyadmin.local"
echo "   • Sample 1 (E-commerce): http://sample1.local"
echo "   • Sample 2 (Blog): http://sample2.local"
echo "   • Sample 3 (Portfolio): http://sample3.local"
echo ""
echo "🚀 PHP 8.4 Features:"
echo "   • Property hooks for cleaner object-oriented code"
echo "   • Asymmetric visibility modifiers (public readonly, private(set))"
echo "   • Enhanced performance with JIT improvements"
echo "   • New array functions and string manipulation"
echo "   • Improved type system and error handling"
echo "   • Better memory management and garbage collection"
echo ""
echo "🔧 Helper commands available:"
echo "   • rebuild-webserver - Rebuild NixOS and restart services"
echo "   • create-site-db <db_name> - Create new database for site"
echo "   • create-site-dir <domain> <site_name> - Create new site directory with PHP 8.4 template"
echo ""
echo "📊 Virtual Host Management Features:"
echo "   • Add/Remove virtual hosts via web interface"
echo "   • Automatic NixOS configuration updates"
echo "   • Database creation for new sites"
echo "   • Activity logging and monitoring"
echo "   • PHP 8.4 optimized templates for new sites"
echo ""
echo "🔍 Verify PHP version after setup:"
echo "   php --version"