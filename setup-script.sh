#!/usr/bin/env bash

# NixOS Web Server Setup Script
# This script helps set up the web directories and content after NixOS rebuild

echo "🚀 Setting up NixOS Web Server Environment..."

# Create web directories
echo "📁 Creating web directories..."
sudo mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}

# Copy web content to appropriate directories
echo "📋 Copying web content..."
sudo cp -r web-content/dashboard/* /var/www/dashboard/
sudo cp -r web-content/sample1/* /var/www/sample1/
sudo cp -r web-content/sample2/* /var/www/sample2/
sudo cp -r web-content/sample3/* /var/www/sample3/

# Download and setup phpMyAdmin
echo "📥 Setting up phpMyAdmin..."
cd /tmp
wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz
tar -xzf phpMyAdmin-5.2.1-all-languages.tar.gz
sudo cp -r phpMyAdmin-5.2.1-all-languages/* /var/www/phpmyadmin/
sudo cp web-content/phpmyadmin/config.inc.php /var/www/phpmyadmin/

# Set proper permissions
echo "🔐 Setting permissions..."
sudo chown -R nginx /var/www
sudo chgrp -R nginx /var/www
sudo chmod -R 755 /var/www

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

# NixOS Web Server Local Domains
127.0.0.1 dashboard.local
127.0.0.1 phpmyadmin.local
127.0.0.1 sample1.local
127.0.0.1 sample2.local
127.0.0.1 sample3.local
EOF

echo "✅ Setup complete!"
echo ""
echo "🎯 Next steps:"
echo "1. Copy configuration.nix to /etc/nixos/configuration.nix"
echo "2. Run: sudo nixos-rebuild switch"
echo "3. Run this setup script: bash setup-script.sh"
echo ""
echo "🌐 Access your sites at:"
echo "   • Dashboard: http://dashboard.local"
echo "   • phpMyAdmin: http://phpmyadmin.local"
echo "   • Sample 1 (E-commerce): http://sample1.local"
echo "   • Sample 2 (Blog): http://sample2.local"
echo "   • Sample 3 (Portfolio): http://sample3.local"
