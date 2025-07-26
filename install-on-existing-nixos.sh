#!/usr/bin/env bash

# NixOS Web Server Installation Script for Existing Systems (PHP 8.4)
# This script safely integrates web server functionality into existing NixOS installations
# Handles single imports entry limitation in configuration.nix
# Correctly manages NixOS hosts file in /nix/store

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

# Find the actual NixOS hosts file in /nix/store
find_nixos_hosts_file() {
    log "Locating NixOS hosts file in /nix/store..."
    
    # Search for hosts files in /nix/store with the pattern *-hosts
    local hosts_files=($(find /nix/store -maxdepth 1 -name "*-hosts" -type f 2>/dev/null | head -5))
    
    if [[ ${#hosts_files[@]} -eq 0 ]]; then
        warning "No hosts files found in /nix/store. Using /etc/hosts as fallback."
        echo "/etc/hosts"
        return 0
    fi
    
    # If multiple hosts files found, try to find the most recent or active one
    local active_hosts_file=""
    
    # Check if any of the hosts files contain localhost entries (indicating it's active)
    for hosts_file in "${hosts_files[@]}"; do
        if grep -q "127.0.0.1.*localhost" "$hosts_file" 2>/dev/null; then
            active_hosts_file="$hosts_file"
            break
        fi
    done
    
    # If no active hosts file found, use the first one
    if [[ -z "$active_hosts_file" ]]; then
        active_hosts_file="${hosts_files[0]}"
    fi
    
    log "Found NixOS hosts file: $active_hosts_file"
    echo "$active_hosts_file"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user with sudo access."
    fi
    
    if ! sudo -n true 2>/dev/null; then
        error "This script requires sudo access. Please ensure you can run sudo commands."
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
    
    # Also backup the current hosts file
    local current_hosts_file=$(find_nixos_hosts_file)
    if [[ -f "$current_hosts_file" ]]; then
        sudo cp "$current_hosts_file" "$BACKUP_DIR/hosts.backup"
        log "Hosts file backed up from: $current_hosts_file"
    fi
    
    # Create restore script
    sudo tee "$BACKUP_DIR/restore.sh" > /dev/null << EOF
#!/usr/bin/env bash
# Restore script created on $(date)
echo "Restoring NixOS configuration from backup..."
sudo cp -r "$BACKUP_DIR"/* "$NIXOS_CONFIG_DIR/"
sudo rm "$NIXOS_CONFIG_DIR/restore.sh"  # Remove this script
sudo rm "$NIXOS_CONFIG_DIR/hosts.backup" 2>/dev/null || true  # Remove hosts backup
echo "Configuration restored. Run 'sudo nixos-rebuild switch' to apply."
echo "Note: Hosts file changes require NixOS rebuild to take effect."
EOF
    
    sudo chmod +x "$BACKUP_DIR/restore.sh"
    success "Configuration backed up to: $BACKUP_DIR"
}

# Analyze existing configuration and imports structure
analyze_existing_config() {
    log "Analyzing existing NixOS configuration and imports structure..."
    
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
    
    # Analyze imports structure
    log "Analyzing imports structure..."
    
    if grep -q "imports = \[" "$config_file"; then
        success "Existing imports section found"
        
        # Extract current imports
        local imports_section=$(sed -n '/imports = \[/,/\];/p' "$config_file")
        echo "Current imports:"
        echo "$imports_section" | grep -E '\./|\.nix|<' | sed 's/^[[:space:]]*/  /'
        
        # Check if webserver.nix is already imported
        if echo "$imports_section" | grep -q "webserver.nix"; then
            warning "webserver.nix already imported in configuration"
            return 0
        fi
    else
        warning "No imports section found - will create one"
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

# Generate web server configuration module with PHP 8.4 and hosts management
generate_webserver_module() {
    log "Generating web server configuration module with PHP 8.4 and hosts management..."
    
    sudo tee "$NIXOS_CONFIG_DIR/webserver.nix" > /dev/null << 'EOF'
# Web Server Configuration Module with PHP 8.4
# Generated by NixOS Web Server Installation Script
# Includes proper hosts file management for NixOS

{ config, pkgs, ... }:

{
  # System packages for web development
  environment.systemPackages = with pkgs; [
    mysql80
    tree
    htop
    php84  # PHP 8.4 CLI
    php84Packages.composer
  ];

  # Enable services
  services.openssh.enable = true;
  
  # Hosts file configuration for local domains
  networking.hosts = {
    "127.0.0.1" = [ 
      "dashboard.local" 
      "phpmyadmin.local" 
      "sample1.local" 
      "sample2.local" 
      "sample3.local" 
    ];
  };
  
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

  # Redis configuration
  services.redis.servers.main = {
    enable = true;
    bind = "127.0.0.1";
    port = 6379;
    databases = 16;
    maxmemory = "256mb";
    maxmemoryPolicy = "allkeys-lru";
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
          redis
          opcache
          apcu
        ]));
        extraConfig = ''
          memory_limit = 256M
          upload_max_filesize = 64M
          post_max_size = 64M
          max_execution_time = 300
          max_input_vars = 3000
          date.timezone = UTC
          
          ; OPcache Configuration (PHP 8.4 Optimized)
          opcache.enable = 1
          opcache.enable_cli = 0
          opcache.memory_consumption = 256
          opcache.interned_strings_buffer = 16
          opcache.max_accelerated_files = 10000
          opcache.max_wasted_percentage = 5
          opcache.use_cwd = 1
          opcache.validate_timestamps = 1
          opcache.revalidate_freq = 2
          opcache.revalidate_path = 0
          opcache.save_comments = 1
          opcache.fast_shutdown = 1
          opcache.enable_file_override = 0
          opcache.optimization_level = 0x7FFFBFFF
          
          ; OPcache JIT (PHP 8.4)
          opcache.jit_buffer_size = 64M
          opcache.jit = 1255
          
          ; APCu Configuration
          apc.enabled = 1
          apc.shm_size = 64M
          apc.ttl = 7200
          
          ; Redis Configuration
          redis.session.locking_enabled = 1
          redis.session.lock_expire = 60
          
          ; Session Configuration with Redis
          session.save_handler = redis
          session.save_path = "tcp://127.0.0.1:6379?database=1"
          session.gc_maxlifetime = 3600
          
          ; Security settings
          expose_php = Off
          display_errors = Off
          log_errors = On
          error_log = /var/log/php_errors.log
          
          ; Performance settings
          realpath_cache_size = 4096K
          realpath_cache_ttl = 600
        '';
      };
    };
  };

  # Nginx configuration with caching support
  services.nginx = {
    enable = true;
    user = "nginx";
    group = "nginx";
    
    # Global configuration
    appendConfig = ''
      worker_processes auto;
      worker_connections 1024;
    '';

    # Common configuration for PHP with caching
    commonHttpConfig = ''
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
      keepalive_timeout 65;
      types_hash_max_size 2048;
      client_max_body_size 64M;
      
      # Gzip compression
      gzip on;
      gzip_vary on;
      gzip_min_length 1024;
      gzip_comp_level 6;
      gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
      
      # FastCGI caching
      fastcgi_cache_path /var/cache/nginx/fastcgi levels=1:2 keys_zone=WORDPRESS:100m inactive=60m;
      fastcgi_cache_key "$scheme$request_method$host$request_uri";
      fastcgi_cache_use_stale error timeout invalid_header http_500;
      fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
      
      # Security headers
      add_header X-Frame-Options DENY;
      add_header X-Content-Type-Options nosniff;
      add_header X-XSS-Protection "1; mode=block";
    '';

    virtualHosts = {
      # Dashboard
      "dashboard.local" = {
        root = "/var/www/dashboard";
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
              
              # FastCGI caching for dashboard
              fastcgi_cache WORDPRESS;
              fastcgi_cache_valid 200 60m;
              fastcgi_cache_bypass $skip_cache;
              fastcgi_no_cache $skip_cache;
              add_header X-FastCGI-Cache $upstream_cache_status;
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
        index = "index.php";
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

      # Sample Domain 1
      "sample1.local" = {
        root = "/var/www/sample1";
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
              
              # FastCGI caching
              fastcgi_cache WORDPRESS;
              fastcgi_cache_valid 200 30m;
              fastcgi_cache_bypass $skip_cache;
              fastcgi_no_cache $skip_cache;
              add_header X-FastCGI-Cache $upstream_cache_status;
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
              
              # FastCGI caching
              fastcgi_cache WORDPRESS;
              fastcgi_cache_valid 200 30m;
              fastcgi_cache_bypass $skip_cache;
              fastcgi_no_cache $skip_cache;
              add_header X-FastCGI-Cache $upstream_cache_status;
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
              
              # FastCGI caching
              fastcgi_cache WORDPRESS;
              fastcgi_cache_valid 200 30m;
              fastcgi_cache_bypass $skip_cache;
              fastcgi_no_cache $skip_cache;
              add_header X-FastCGI-Cache $upstream_cache_status;
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
    allowedTCPPorts = [ 80 443 3306 6379 ];
  };

  # System activation script to create directories and files
  system.activationScripts.websetup = ''
    # Create web directories
    mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}
    chown -R nginx /var/www
    chgrp -R nginx /var/www
    chmod -R 755 /var/www
    
    # Create cache directories
    mkdir -p /var/cache/nginx/fastcgi
    chown -R nginx /var/cache/nginx
    chgrp -R nginx /var/cache/nginx
    chmod -R 755 /var/cache/nginx
    
    # Create log directories
    mkdir -p /var/log/{php-fpm,redis}
    touch /var/log/php_errors.log
    touch /var/log/php-fpm-slow.log
    chown nginx /var/log/php_errors.log
    chgrp nginx /var/log/php_errors.log
    chown nginx /var/log/php-fpm-slow.log
    chgrp nginx /var/log/php-fpm-slow.log
    chmod 644 /var/log/php_errors.log
    chmod 644 /var/log/php-fpm-slow.log
    
    # Create Redis data directory
    mkdir -p /var/lib/redis
    chown redis /var/lib/redis
    chgrp redis /var/lib/redis
    chmod 750 /var/lib/redis
  '';

  # Ensure nginx user and group exist
  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
    home = "/var/lib/nginx";
    createHome = true;
  };

  users.groups.nginx = {};
}
EOF

    success "Web server module with PHP 8.4 and NixOS hosts management created at $NIXOS_CONFIG_DIR/webserver.nix"
}

# Update main configuration to properly handle single imports entry
update_main_configuration() {
    log "Updating main NixOS configuration to handle single imports entry..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    local temp_file=$(mktemp)
    
    # Check if webserver.nix is already imported
    if grep -q "webserver.nix" "$config_file"; then
        warning "Web server module already imported in configuration"
        return 0
    fi
    
    # Check if imports section exists
    if grep -q "imports = \[" "$config_file"; then
        log "Adding webserver.nix to existing imports section..."
        
        # Use awk to add webserver.nix to existing imports
        awk '
        /imports = \[/ {
            print $0
            getline
            # Print the next line and add our import
            print $0
            print "    ./webserver.nix"
            next
        }
        { print }
        ' "$config_file" > "$temp_file"
        
    else
        log "Creating new imports section with webserver.nix..."
        
        # Find the opening brace and add imports section
        awk '
        /^{/ && !found {
            print $0
            print ""
            print "  imports = ["
            print "    ./hardware-configuration.nix"
            print "    ./webserver.nix"
            print "  ];"
            print ""
            found = 1
            next
        }
        # Skip hardware-configuration.nix import if it exists outside imports
        /\.\/hardware-configuration\.nix/ && !found {
            next
        }
        { print }
        ' "$config_file" > "$temp_file"
    fi
    
    # Validate the generated configuration
    if ! grep -q "webserver.nix" "$temp_file"; then
        error "Failed to add webserver.nix to imports. Manual intervention required."
    fi
    
    # Apply the changes
    sudo cp "$temp_file" "$config_file"
    rm "$temp_file"
    
    success "Main configuration updated with webserver.nix import"
    
    # Show the imports section for verification
    log "Current imports section:"
    sed -n '/imports = \[/,/\];/p' "$config_file" | sed 's/^/  /'
}

# Create nginx user and group immediately
create_nginx_user_group() {
    log "Creating nginx user and group..."
    
    # Check if nginx group exists
    if ! getent group nginx >/dev/null 2>&1; then
        log "Creating nginx group..."
        sudo groupadd -r nginx
        success "nginx group created"
    else
        log "nginx group already exists"
    fi
    
    # Check if nginx user exists
    if ! getent passwd nginx >/dev/null 2>&1; then
        log "Creating nginx user..."
        sudo useradd -r -g nginx -d /var/lib/nginx -s /sbin/nologin -c "nginx web server" nginx
        success "nginx user created"
    else
        log "nginx user already exists"
    fi
    
    # Create nginx home directory
    sudo mkdir -p /var/lib/nginx
    sudo chown nginx /var/lib/nginx
    sudo chgrp nginx /var/lib/nginx
    sudo chmod 755 /var/lib/nginx
    
    success "nginx user and group setup complete"
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
    
    # Set proper permissions using separate chown and chgrp commands
    sudo chown -R nginx "$WEB_ROOT"
    sudo chgrp -R nginx "$WEB_ROOT"
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
    
    # Set proper permissions for phpMyAdmin using separate commands
    sudo chown -R nginx "$phpmyadmin_dir"
    sudo chgrp -R nginx "$phpmyadmin_dir"
    sudo chmod -R 755 "$phpmyadmin_dir"
    
    # Clean up
    cd "$SCRIPT_DIR"
    rm -rf "$temp_dir"
    
    success "phpMyAdmin set up successfully with PHP 8.4 compatibility"
}

# Create helper scripts with PHP 8.4 support and NixOS hosts management
create_helper_scripts() {
    log "Creating helper scripts with PHP 8.4 support and NixOS hosts management..."
    
    # Rebuild script
    sudo tee /usr/local/bin/rebuild-webserver > /dev/null << 'EOF'
#!/usr/bin/env bash
echo "🔄 Rebuilding NixOS configuration with PHP 8.4..."
sudo nixos-rebuild switch
if [ $? -eq 0 ]; then
    echo "✅ NixOS rebuild successful!"
    echo "🌐 Restarting web services..."
    sudo systemctl restart nginx
    sudo systemctl restart phpfpm
    echo "✅ Web services restarted!"
    echo "🚀 PHP Version: $(php --version | head -1)"
    echo "📍 Hosts file updated via NixOS configuration"
else
    echo "❌ NixOS rebuild failed!"
    exit 1
fi
EOF

    sudo chmod +x /usr/local/bin/rebuild-webserver

    # Database creation script
    sudo tee /usr/local/bin/create-site-db > /dev/null << 'EOF'
#!/usr/bin/env bash
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

    # Site directory creation script with PHP 8.4 template and NixOS hosts management
    sudo tee /usr/local/bin/create-site-dir > /dev/null << 'EOF'
#!/usr/bin/env bash
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

# Set proper ownership using separate commands
chown -R nginx "$SITE_DIR"
chgrp -R nginx "$SITE_DIR"
chmod -R 755 "$SITE_DIR"

echo "✅ Site directory created successfully with PHP 8.4 template!"
echo "📝 PHP 8.4 optimized index.php file created"
echo "🔐 Permissions set correctly"
echo ""
echo "⚠️  To add $DOMAIN to hosts file:"
echo "   1. Edit /etc/nixos/webserver.nix"
echo "   2. Add \"$DOMAIN\" to networking.hosts.\"127.0.0.1\" array"
echo "   3. Run: sudo nixos-rebuild switch"
EOF

    sudo chmod +x /usr/local/bin/create-site-dir

    # NixOS hosts management script
    sudo tee /usr/local/bin/manage-nixos-hosts > /dev/null << 'EOF'
#!/usr/bin/env bash

WEBSERVER_CONFIG="/etc/nixos/webserver.nix"

show_help() {
    echo "NixOS Hosts Management Script"
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  list                    - Show current local domains"
    echo "  add <domain>           - Add domain to NixOS hosts configuration"
    echo "  remove <domain>        - Remove domain from NixOS hosts configuration"
    echo "  rebuild                - Rebuild NixOS configuration to apply changes"
    echo "  show-current           - Show current active hosts file location"
    echo ""
    echo "Examples:"
    echo "  $0 add mysite.local"
    echo "  $0 remove oldsite.local"
    echo "  $0 list"
}

find_current_hosts() {
    find /nix/store -maxdepth 1 -name "*-hosts" -type f 2>/dev/null | head -1
}

list_domains() {
    echo "Current local domains in NixOS configuration:"
    if [[ -f "$WEBSERVER_CONFIG" ]]; then
        grep -A 10 'networking.hosts' "$WEBSERVER_CONFIG" | grep -E '^\s*".*\.local"' | sed 's/[",]//g' | sed 's/^[[:space:]]*/  /'
    else
        echo "  webserver.nix not found"
    fi
    
    echo ""
    echo "Active hosts file location:"
    local current_hosts=$(find_current_hosts)
    if [[ -n "$current_hosts" ]]; then
        echo "  $current_hosts"
        echo ""
        echo "Active hosts entries:"
        grep "127.0.0.1.*\.local" "$current_hosts" 2>/dev/null | sed 's/^/  /' || echo "  No .local entries found"
    else
        echo "  No hosts file found in /nix/store"
    fi
}

add_domain() {
    local domain=$1
    if [[ -z "$domain" ]]; then
        echo "Error: Domain name required"
        exit 1
    fi
    
    if [[ ! -f "$WEBSERVER_CONFIG" ]]; then
        echo "Error: webserver.nix not found at $WEBSERVER_CONFIG"
        exit 1
    fi
    
    # Check if domain already exists
    if grep -q "\"$domain\"" "$WEBSERVER_CONFIG"; then
        echo "Domain $domain already exists in configuration"
        exit 0
    fi
    
    # Create backup
    sudo cp "$WEBSERVER_CONFIG" "$WEBSERVER_CONFIG.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Add domain to the hosts configuration
    sudo sed -i "/\"127.0.0.1\" = \[/a\\      \"$domain\"" "$WEBSERVER_CONFIG"
    
    echo "✅ Added $domain to NixOS hosts configuration"
    echo "🔄 Run 'sudo nixos-rebuild switch' or '$0 rebuild' to apply changes"
}

remove_domain() {
    local domain=$1
    if [[ -z "$domain" ]]; then
        echo "Error: Domain name required"
        exit 1
    fi
    
    if [[ ! -f "$WEBSERVER_CONFIG" ]]; then
        echo "Error: webserver.nix not found at $WEBSERVER_CONFIG"
        exit 1
    fi
    
    # Check if domain exists
    if ! grep -q "\"$domain\"" "$WEBSERVER_CONFIG"; then
        echo "Domain $domain not found in configuration"
        exit 0
    fi
    
    # Create backup
    sudo cp "$WEBSERVER_CONFIG" "$WEBSERVER_CONFIG.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Remove domain from configuration
    sudo sed -i "/\"$domain\"/d" "$WEBSERVER_CONFIG"
    
    echo "✅ Removed $domain from NixOS hosts configuration"
    echo "🔄 Run 'sudo nixos-rebuild switch' or '$0 rebuild' to apply changes"
}

rebuild_config() {
    echo "🔄 Rebuilding NixOS configuration..."
    sudo nixos-rebuild switch
    if [ $? -eq 0 ]; then
        echo "✅ NixOS rebuild successful!"
        echo "📍 Hosts file updated"
    else
        echo "❌ NixOS rebuild failed!"
        exit 1
    fi
}

case "$1" in
    list)
        list_domains
        ;;
    add)
        add_domain "$2"
        ;;
    remove)
        remove_domain "$2"
        ;;
    rebuild)
        rebuild_config
        ;;
    show-current)
        find_current_hosts
        ;;
    *)
        show_help
        exit 1
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/manage-nixos-hosts

    success "Helper scripts created successfully with NixOS hosts management"
}

# Setup PHP error logging
setup_php_logging() {
    log "Setting up PHP 8.4 error logging..."
    
    sudo mkdir -p /var/log
    sudo touch /var/log/php_errors.log
    sudo chown nginx /var/log/php_errors.log
    sudo chgrp nginx /var/log/php_errors.log
    sudo chmod 644 /var/log/php_errors.log
    
    success "PHP error logging configured"
}

# Validate configuration syntax before proceeding
validate_configuration() {
    log "Validating NixOS configuration syntax..."
    
    if sudo nixos-rebuild dry-build >/dev/null 2>&1; then
        success "Configuration syntax is valid"
    else
        error "Configuration syntax validation failed. Please check the configuration manually."
    fi
}

# Main installation function
main() {
    echo "🚀 NixOS Web Server Installation Script (PHP 8.4)"
    echo "Handles NixOS hosts file management in /nix/store"
    echo "=================================================="
    echo
    
    # Pre-flight checks
    check_root
    check_nixos
    check_nixos_channel
    
    # Show current hosts file location
    local current_hosts=$(find_nixos_hosts_file)
    log "Current NixOS hosts file: $current_hosts"
    
    # Backup and analysis
    backup_configuration
    analyze_existing_config
    
    # Generate configuration with proper hosts management
    generate_webserver_module
    update_main_configuration
    
    # Validate configuration before proceeding
    validate_configuration
    
    # Create nginx user/group before any file operations
    create_nginx_user_group
    
    # Setup web content and services
    setup_web_content
    setup_phpmyadmin
    setup_php_logging
    
    # Create helper scripts with NixOS hosts management
    create_helper_scripts
    
    echo
    echo "✅ Installation complete!"
    echo
    echo "🎯 Next steps:"
    echo "1. Run: sudo nixos-rebuild switch"
    echo "2. Wait for the system to rebuild and restart services"
    echo "3. Access your sites:"
    echo "   • Dashboard: http://dashboard.local"
    echo "   • phpMyAdmin: http://phpmyadmin.local"
    echo "   • Sample 1: http://sample1.local"
    echo "   • Sample 2: http://sample2.local"
    echo "   • Sample 3: http://sample3.local"
    echo
    echo "🚀 PHP 8.4 Features Available:"
    echo "   • Property hooks for cleaner object-oriented code"
    echo "   • Asymmetric visibility modifiers"
    echo "   • Enhanced performance with JIT improvements"
    echo "   • New array functions and string manipulation"
    echo "   • Improved type system and error handling"
    echo
    echo "🔧 Helper commands:"
    echo "   • rebuild-webserver - Rebuild NixOS and restart services"
    echo "   • create-site-db <db_name> - Create new database"
    echo "   • create-site-dir <domain> <site_name> - Create new site"
    echo "   • manage-nixos-hosts <command> - Manage local domains in NixOS"
    echo
    echo "📍 NixOS Hosts Management:"
    echo "   • manage-nixos-hosts list - Show current domains"
    echo "   • manage-nixos-hosts add <domain> - Add domain"
    echo "   • manage-nixos-hosts remove <domain> - Remove domain"
    echo "   • manage-nixos-hosts rebuild - Apply changes"
    echo
    echo "📦 Backup location: $BACKUP_DIR"
    echo "🔄 To restore: bash $BACKUP_DIR/restore.sh"
    echo
    echo "⚠️  Important: Hosts file management is now handled via NixOS configuration"
    echo "   Local domains are managed through networking.hosts in webserver.nix"
    echo "   Changes require 'sudo nixos-rebuild switch' to take effect"
}

# Run main function
main "$@"
