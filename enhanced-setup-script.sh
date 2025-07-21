#!/usr/bin/env bash

# Enhanced NixOS Web Server Setup Script with Virtual Host Management (PHP 8.4)
# This script sets up the complete web environment with management capabilities

echo "🚀 Setting up Enhanced NixOS Web Server Environment with PHP 8.4..."

# Create web directories
echo "📁 Creating web directories..."
sudo mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}

# Copy web content to appropriate directories
echo "📋 Copying web content..."
sudo cp -r web-content/dashboard/* /var/www/dashboard/
sudo cp -r web-content/sample1/* /var/www/sample1/
sudo cp -r web-content/sample2/* /var/www/sample2/
sudo cp -r web-content/sample3/* /var/www/sample3/

# Download and setup phpMyAdmin with PHP 8.4 compatibility
echo "📥 Setting up phpMyAdmin with PHP 8.4 compatibility..."
cd /tmp
if [ ! -f "phpMyAdmin-5.2.1-all-languages.tar.gz" ]; then
    wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz
fi
tar -xzf phpMyAdmin-5.2.1-all-languages.tar.gz
sudo cp -r phpMyAdmin-5.2.1-all-languages/* /var/www/phpmyadmin/
sudo cp web-content/phpmyadmin/config.inc.php /var/www/phpmyadmin/

# Set proper permissions
echo "🔐 Setting permissions..."
sudo chown -R nginx:nginx /var/www
sudo chmod -R 755 /var/www

# Create PHP error log
echo "📝 Setting up PHP 8.4 error logging..."
sudo mkdir -p /var/log
sudo touch /var/log/php_errors.log
sudo chown nginx:nginx /var/log/php_errors.log
sudo chmod 644 /var/log/php_errors.log

# Create phpMyAdmin configuration storage
echo "🗄️ Setting up phpMyAdmin configuration storage..."
sudo mysql -u root << 'EOF'
CREATE DATABASE IF NOT EXISTS phpmyadmin;
USE phpmyadmin;
SOURCE /var/www/phpmyadmin/sql/create_tables.sql;
EOF

# Add hosts entries for local development
echo "🌐 Adding local domain entries to /etc/hosts..."
sudo tee -a /etc/hosts << 'EOF'

# NixOS Web Server Local Domains (PHP 8.4)
127.0.0.1 dashboard.local
127.0.0.1 phpmyadmin.local
127.0.0.1 sample1.local
127.0.0.1 sample2.local
127.0.0.1 sample3.local
EOF

# Create backup directory for NixOS configurations
echo "📦 Creating backup directory..."
sudo mkdir -p /etc/nixos/backups

# Set up log rotation for virtual host management
echo "📊 Setting up log management..."
sudo mkdir -p /var/log/webserver-dashboard
sudo chown nginx:nginx /var/log/webserver-dashboard

# Create helper script for NixOS rebuilds with PHP 8.4
echo "🔧 Creating helper scripts..."
sudo tee /usr/local/bin/rebuild-webserver << 'EOF'
#!/bin/bash
echo "🔄 Rebuilding NixOS configuration with PHP 8.4..."
sudo nixos-rebuild switch
if [ $? -eq 0 ]; then
    echo "✅ NixOS rebuild successful!"
    echo "🌐 Restarting web services..."
    sudo systemctl restart nginx
    sudo systemctl restart phpfpm
    echo "✅ Web services restarted!"
    echo "🚀 PHP Version: $(php --version | head -1)"
else
    echo "❌ NixOS rebuild failed!"
    exit 1
fi
EOF

sudo chmod +x /usr/local/bin/rebuild-webserver

# Create virtual host template with PHP 8.4 optimizations
echo "📝 Creating virtual host template..."
sudo mkdir -p /etc/nixos/templates
sudo tee /etc/nixos/templates/virtualhost.nix << 'EOF'
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
echo "🗃️ Creating database management helper..."
sudo tee /usr/local/bin/create-site-db << 'EOF'
#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Usage: $0 <database_name>"
    exit 1
fi

DB_NAME=$1
echo "Creating database: $DB_NAME"

mysql -u root << SQL
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

sudo chmod +x /usr/local/bin/create-site-db

# Create site directory helper with PHP 8.4 template
echo "📁 Creating site directory helper..."
sudo tee /usr/local/bin/create-site-dir << 'EOF'
#!/bin/bash
if [ $# -ne 2 ]; then
    echo "Usage: $0 <domain> <site_name>"
    exit 1
fi

DOMAIN=$1
SITE_NAME=$2
SITE_DIR="/var/www/$DOMAIN"

echo "Creating site directory: $SITE_DIR"
mkdir -p "$SITE_DIR"

# Create PHP 8.4 optimized index.php
cat > "$SITE_DIR/index.php" << PHP
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
chown -R nginx:nginx "$SITE_DIR"
chmod -R 755 "$SITE_DIR"

echo "✅ Site directory created successfully with PHP 8.4 template!"
echo "📝 PHP 8.4 optimized index.php file created"
echo "🔐 Permissions set correctly"
EOF

sudo chmod +x /usr/local/bin/create-site-dir

echo "✅ Enhanced setup complete with PHP 8.4!"
echo ""
echo "🎯 Next steps:"
echo "1. Copy configuration.nix to /etc/nixos/configuration.nix"
echo "2. Run: sudo nixos-rebuild switch"
echo "3. Run this setup script: bash enhanced-setup-script.sh"
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
