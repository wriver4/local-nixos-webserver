#!/usr/bin/env bash

# NixOS Web Server Installation Script for Existing Systems (PHP 8.4)
# This script safely integrates web server functionality into existing NixOS installations

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_CONFIG_DIR="/etc/nixos"
BACKUP_DIR="/etc/nixos/webserver-backups/$(date +%Y%m%d-%H%M%S)"
WEB_ROOT="/var/www"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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
        # Running as root - this is actually fine for this script
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

# Check if this is a NixOS system
check_nixos() {
    if [[ ! -f /etc/NIXOS ]]; then
        error "This script is designed for NixOS systems only."
    fi
    
    if [[ ! -f "$NIXOS_CONFIG_DIR/configuration.nix" ]]; then
        error "NixOS configuration file not found at $NIXOS_CONFIG_DIR/configuration.nix"
    fi
    
    success "NixOS system detected"
}

# Check NixOS channel version
check_nixos_channel() {
    log "Checking NixOS channel version..."
    
    local current_channel=$(nix-channel --list | grep nixos | head -1 | awk '{print $2}')
    
    if [[ $current_channel == *"25.05"* ]]; then
        success "NixOS 25.05 channel detected - PHP 8.4 available"
    elif [[ $current_channel == *"24."* ]]; then
        warning "NixOS 24.x channel detected. PHP 8.4 may not be available."
        echo "Consider upgrading to NixOS 25.05 channel for PHP 8.4 support:"
        echo "  sudo nix-channel --add https://nixos.org/channels/nixos-25.05 nixos"
        echo "  sudo nix-channel --update"
        echo
        read -p "Continue with current channel? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation cancelled. Please upgrade to NixOS 25.05 for PHP 8.4 support."
        fi
    else
        warning "Unknown NixOS channel: $current_channel"
        echo "PHP 8.4 requires NixOS 25.05 or later."
        echo
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation cancelled by user"
        fi
    fi
}

# Create backup of existing configuration
backup_configuration() {
    log "Creating backup of existing NixOS configuration..."
    
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp -r "$NIXOS_CONFIG_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
    
    # Create restore script
    sudo tee "$BACKUP_DIR/restore.sh" > /dev/null << EOF
#!/bin/bash
# Restore script created on $(date)
echo "Restoring NixOS configuration from backup..."
sudo cp -r "$BACKUP_DIR"/* "$NIXOS_CONFIG_DIR/"
sudo rm "$NIXOS_CONFIG_DIR/restore.sh"  # Remove this script
echo "Configuration restored. Run 'sudo nixos-rebuild switch' to apply."
EOF
    
    sudo chmod +x "$BACKUP_DIR/restore.sh"
    success "Configuration backed up to: $BACKUP_DIR"
}

# Analyze existing configuration
analyze_existing_config() {
    log "Analyzing existing NixOS configuration..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    local conflicts=()
    
    # Check for existing web server configurations
    if grep -q "services\.nginx" "$config_file"; then
        conflicts+=("nginx")
    fi
    
    if grep -q "services\.apache" "$config_file"; then
        conflicts+=("apache")
    fi
    
    if grep -q "services\.phpfpm" "$config_file"; then
        conflicts+=("php-fpm")
    fi
    
    if grep -q "services\.mysql\|services\.mariadb\|services\.postgresql" "$config_file"; then
        conflicts+=("database")
    fi
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        warning "Potential conflicts detected with existing services:"
        for conflict in "${conflicts[@]}"; do
            echo "  - $conflict"
        done
        echo
        read -p "Do you want to continue? This may override existing configurations. (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation cancelled by user"
        fi
    fi
    
    success "Configuration analysis complete"
}

# Generate web server configuration module with PHP 8.4
generate_webserver_module() {
    log "Generating web server configuration module with PHP 8.4..."
    
    sudo tee "$NIXOS_CONFIG_DIR/webserver.nix" > /dev/null << 'EOF'
# Web Server Configuration Module with PHP 8.4
# Generated by NixOS Web Server Installation Script

{ config, pkgs, ... }:

{
  # System packages for web development
  environment.systemPackages = with pkgs; [
    mysql80
    tree
    htop
    php84  # PHP 8.4 CLI
  ];

  # Enable services
  services.openssh.enable = true;
  
  # MySQL/MariaDB configuration
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialDatabases = [
      { name = "dashboard_db"; }
      { name = "sample1_db"; }
      { name = "sample2_db"; }
      { name = "sample3_db"; }
    ];
    initialScript = pkgs.writeText "mysql-init.sql" ''
      CREATE USER IF NOT EXISTS 'webuser'@'localhost' IDENTIFIED BY 'webpass123';
      GRANT ALL PRIVILEGES ON dashboard_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample1_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample2_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample3_db.* TO 'webuser'@'localhost';
      
      CREATE USER IF NOT EXISTS 'phpmyadmin'@'localhost' IDENTIFIED BY 'pmapass123';
      GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost' WITH GRANT OPTION;
      
      FLUSH PRIVILEGES;
    '';
  };

  # PHP-FPM configuration with PHP 8.4
  services.phpfpm = {
    pools.www = {
      user = "nginx";
      group = "nginx";
      settings = {
        "listen.owner" = "nginx";
        "listen.group" = "nginx";
        "listen.mode" = "0600";
        "pm" = "dynamic";
        "pm.max_children" = 75;
        "pm.start_servers" = 10;
        "pm.min_spare_servers" = 5;
        "pm.max_spare_servers" = 20;
        "pm.max_requests" = 500;
      };
      phpPackage = pkgs.php84.buildEnv {
        extensions = ({ enabled, all }: enabled ++ (with all; [
          mysqli
          pdo_mysql
          mbstring
          zip
          gd
          curl
          json
          session
          filter
          openssl
          fileinfo
          intl
          exif
        ]));
        extraConfig = ''
          memory_limit = 256M
          upload_max_filesize = 64M
          post_max_size = 64M
          max_execution_time = 300
          max_input_vars = 3000
          date.timezone = UTC
          
          ; PHP 8.4 optimizations
          opcache.enable = 1
          opcache.memory_consumption = 128
          opcache.interned_strings_buffer = 8
          opcache.max_accelerated_files = 4000
          opcache.revalidate_freq = 2
          opcache.fast_shutdown = 1
          
          ; Security settings
          expose_php = Off
          display_errors = Off
          log_errors = On
          error_log = /var/log/php_errors.log
        '';
      };
    };
  };

  # Nginx configuration
  services.nginx = {
    enable = true;
    user = "nginx";
    group = "nginx";
    
    # Global configuration
    appendConfig = ''
      worker_processes auto;
      worker_connections 1024;
    '';

    # Common configuration for PHP
    commonHttpConfig = ''
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
      keepalive_timeout 65;
      types_hash_max_size 2048;
      client_max_body_size 64M;
      
      gzip on;
      gzip_vary on;
      gzip_min_length 1024;
      gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
      
      # Security headers
      add_header X-Frame-Options DENY;
      add_header X-Content-Type-Options nosniff;
      add_header X-XSS-Protection "1; mode=block";
    '';

    virtualHosts = {
      # Dashboard
      "dashboard.local" = {
        root = "/var/www/dashboard";
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
            index = "index.php index.html";
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

      # phpMyAdmin
      "phpmyadmin.local" = {
        root = "/var/www/phpmyadmin";
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
            index = "index.php";
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

      # Sample Domain 1
      "sample1.local" = {
        root = "/var/www/sample1";
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
            index = "index.php index.html";
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

      # Sample Domain 2
      "sample2.local" = {
        root = "/var/www/sample2";
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
            index = "index.php index.html";
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

      # Sample Domain 3
      "sample3.local" = {
        root = "/var/www/sample3";
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
            index = "index.php index.html";
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
    };
  };

  # Firewall configuration - only add ports if not already configured
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 3306 ];
  };

  # System activation script to create directories and files
  system.activationScripts.websetup = ''
    # Create web directories
    mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}
    chown -R nginx:nginx /var/www
    chmod -R 755 /var/www
    
    # Create PHP error log directory
    mkdir -p /var/log
    touch /var/log/php_errors.log
    chown nginx:nginx /var/log/php_errors.log
    chmod 644 /var/log/php_errors.log
  '';
}
EOF

    success "Web server module with PHP 8.4 created at $NIXOS_CONFIG_DIR/webserver.nix"
}

# Update main configuration to import web server module
update_main_configuration() {
    log "Updating main NixOS configuration..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    local temp_file=$(mktemp)
    
    # Check if webserver.nix is already imported
    if grep -q "webserver.nix" "$config_file"; then
        warning "Web server module already imported in configuration"
        return 0
    fi
    
    # Find the imports section and add our module
    awk '
    /imports = \[/ {
        print $0
        print "    ./webserver.nix"
        next
    }
    { print }
    ' "$config_file" > "$temp_file"
    
    # If no imports section found, add it after the opening brace
    if ! grep -q "imports = \[" "$temp_file"; then
        awk '
        /^{/ && !found {
            print $0
            print "  imports = ["
            print "    ./webserver.nix"
            print "  ];"
            print ""
            found = 1
            next
        }
        { print }
        ' "$config_file" > "$temp_file"
    fi
    
    sudo cp "$temp_file" "$config_file"
    rm "$temp_file"
    
    success "Main configuration updated to import web server module"
}

# Setup web directories and content
setup_web_content() {
    log "Setting up web directories and content..."
    
    # Create web directories
    sudo mkdir -p "$WEB_ROOT"/{dashboard,phpmyadmin,sample1,sample2,sample3}
    
    # Copy web content if available
    if [[ -d "$SCRIPT_DIR/web-content" ]]; then
        log "Copying web content from script directory..."
        sudo cp -r "$SCRIPT_DIR/web-content/dashboard"/* "$WEB_ROOT/dashboard/" 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample1"/* "$WEB_ROOT/sample1/" 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample2"/* "$WEB_ROOT/sample2/" 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample3"/* "$WEB_ROOT/sample3/" 2>/dev/null || true
    else
        warning "Web content directory not found. Creating basic placeholder files..."
        
        # Create basic index files for each site with PHP 8.4 info
        for site in dashboard sample1 sample2 sample3; do
            sudo tee "$WEB_ROOT/$site/index.php" > /dev/null << EOF
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
    sudo chown -R nginx:nginx "$WEB_ROOT"
    sudo chmod -R 755 "$WEB_ROOT"
    
    success "Web directories and content set up"
}

# Setup phpMyAdmin with PHP 8.4 compatibility
setup_phpmyadmin() {
    log "Setting up phpMyAdmin with PHP 8.4 compatibility..."
    
    local phpmyadmin_dir="$WEB_ROOT/phpmyadmin"
    local temp_dir="/tmp/phpmyadmin-setup"
    
    # Download and extract phpMyAdmin (latest version for PHP 8.4 compatibility)
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    if ! wget -q "https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz"; then
        warning "Failed to download phpMyAdmin. You'll need to set it up manually."
        return 1
    fi
    
    tar -xzf phpMyAdmin-5.2.1-all-languages.tar.gz
    sudo cp -r phpMyAdmin-5.2.1-all-languages/* "$phpmyadmin_dir/"
    
    # Create phpMyAdmin configuration with PHP 8.4 optimizations
    if [[ -f "$SCRIPT_DIR/web-content/phpmyadmin/config.inc.php" ]]; then
        sudo cp "$SCRIPT_DIR/web-content/phpmyadmin/config.inc.php" "$phpmyadmin_dir/"
    else
        sudo tee "$phpmyadmin_dir/config.inc.php" > /dev/null << 'EOF'
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
    
    # Clean up
    cd "$SCRIPT_DIR"
    rm -rf "$temp_dir"
    
    success "phpMyAdmin set up successfully with PHP 8.4 compatibility"
}

# Create helper scripts with PHP 8.4 support
create_helper_scripts() {
    log "Creating helper scripts with PHP 8.4 support..."
    
    # Rebuild script
    sudo tee /usr/local/bin/rebuild-webserver > /dev/null << 'EOF'
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

    # Database creation script
    sudo tee /usr/local/bin/create-site-db > /dev/null << 'EOF'
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

    # Site directory creation script with PHP 8.4 template
    sudo tee /usr/local/bin/create-site-dir > /dev/null << 'EOF'
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
    echo '<li>Property hooks for cleaner code</li>';
    echo '<li>Asymmetric visibility modifiers</li>';
    echo '<li>Enhanced performance and memory usage</li>';
    echo '<li>New array and string functions</li>';
    echo '</ul>';
}
?>
PHP

chown -R nginx:nginx "$SITE_DIR"
chmod -R 755 "$SITE_DIR"

echo "✅ Site directory created successfully with PHP 8.4 template!"
EOF

    sudo chmod +x /usr/local/bin/{rebuild-webserver,create-site-db,create-site-dir}
    
    success "Helper scripts created with PHP 8.4 support"
}

# Update hosts file configuration in NixOS
update_hosts_configuration() {
    log "Configuring local domains in NixOS configuration..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    
    # Check if networking.extraHosts already exists
    if grep -q "networking.extraHosts" "$config_file"; then
        success "networking.extraHosts already configured in NixOS configuration"
        return 0
    fi
    
    # Add networking.extraHosts to the configuration
    local temp_file=$(mktemp)
    
    # Find networking section and add extraHosts
    awk '
    /networking\./ && !found_networking {
        found_networking = 1
        print $0
        if ($0 ~ /networking\.hostName/) {
            print "  networking.extraHosts = ''"
            print "    127.0.0.1 dashboard.local"
            print "    127.0.0.1 phpmyadmin.local"
            print "    127.0.0.1 sample1.local"
            print "    127.0.0.1 sample2.local"
            print "    127.0.0.1 sample3.local"
            print "  '';"
        }
        next
    }
    { print }
    ' "$config_file" > "$temp_file"
    
    # If no networking section found, add it after imports
    if ! grep -q "networking.extraHosts" "$temp_file"; then
        awk '
        /imports = \[/,/\];/ { print; next }
        /^{/ && !added {
            print $0
            print ""
            print "  # Network configuration"
            print "  networking.extraHosts = ''"
            print "    127.0.0.1 dashboard.local"
            print "    127.0.0.1 phpmyadmin.local"
            print "    127.0.0.1 sample1.local"
            print "    127.0.0.1 sample2.local"
            print "    127.0.0.1 sample3.local"
            print "  '';"
            print ""
            added = 1
            next
        }
        { print }
        ' "$temp_file" > "${temp_file}.tmp" && mv "${temp_file}.tmp" "$temp_file"
    fi
    
    sudo cp "$temp_file" "$config_file"
    rm "$temp_file"
    
    success "Local domain configuration added to NixOS configuration"
}

# Test configuration syntax
test_configuration() {
    log "Testing NixOS configuration syntax..."
    
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "Configuration syntax is valid"
    else
        error "Configuration syntax error detected. Please check the configuration manually."
    fi
}

# Main installation function
main() {
    echo "🚀 NixOS Web Server Installation for Existing Systems (PHP 8.4)"
    echo "=============================================================="
    echo
    
    check_privileges
    check_nixos
    check_nixos_channel
    
    echo "This script will:"
    echo "  • Create a backup of your current NixOS configuration"
    echo "  • Add web server functionality with PHP 8.4 as a separate module"
    echo "  • Set up nginx, PHP-FPM 8.4, and MariaDB"
    echo "  • Create sample websites and management dashboard"
    echo "  • Install phpMyAdmin with PHP 8.4 compatibility"
    echo "  • Configure PHP 8.4 optimizations and security settings"
    echo
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation cancelled by user"
    fi
    
    backup_configuration
    analyze_existing_config
    generate_webserver_module
    update_main_configuration
    setup_web_content
    setup_phpmyadmin
    create_helper_scripts
    update_hosts_configuration
    test_configuration
    
    echo
    success "Installation completed successfully with PHP 8.4!"
    echo
    echo "🎯 Next steps:"
    echo "1. Run: sudo nixos-rebuild switch"
    echo "2. Wait for the system to rebuild and restart services"
    echo "3. Access your sites:"
    echo "   • Dashboard: http://dashboard.local"
    echo "   • phpMyAdmin: http://phpmyadmin.local"
    echo "   • Sample sites: http://sample1.local, http://sample2.local, http://sample3.local"
    echo
    echo "🚀 PHP 8.4 Features:"
    echo "   • Property hooks for cleaner object-oriented code"
    echo "   • Asymmetric visibility modifiers"
    echo "   • Enhanced performance and memory optimizations"
    echo "   • New array and string manipulation functions"
    echo "   • Improved type system and error handling"
    echo
    echo "🔧 Helper commands available:"
    echo "   • rebuild-webserver - Rebuild NixOS and restart web services"
    echo "   • create-site-db <db_name> - Create new database"
    echo "   • create-site-dir <domain> <site_name> - Create new site directory with PHP 8.4 template"
    echo
    echo "📦 Backup location: $BACKUP_DIR"
    echo "   • Run $BACKUP_DIR/restore.sh to restore original configuration"
    echo
    warning "Remember to change default database passwords in production!"
    echo
    echo "🔍 Verify PHP version after rebuild:"
    echo "   php --version"
}

# Run main function
main "$@"
