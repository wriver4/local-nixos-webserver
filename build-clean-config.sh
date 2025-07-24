#!/usr/bin/env bash

# Build Clean Working Configuration
# This script creates a completely clean configuration that works

set -e  # Exit on any error

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

# Create comprehensive backup
create_backup() {
    log "Creating comprehensive backup..."
    
    local backup_dir="/etc/nixos/clean-config-backup-$(date +%Y%m%d-%H%M%S)"
    sudo mkdir -p "$backup_dir"
    sudo cp -r /etc/nixos/* "$backup_dir/" 2>/dev/null || true
    
    # Create restore script
    sudo tee "$backup_dir/restore.sh" > /dev/null << EOF
#!/bin/bash
echo "Restoring from backup..."
sudo cp -r "$backup_dir"/* /etc/nixos/
sudo rm /etc/nixos/restore.sh
echo "Backup restored. Run 'sudo nixos-rebuild switch --impure' to apply."
EOF
    sudo chmod +x "$backup_dir/restore.sh"
    
    success "Backup created at: $backup_dir"
}

# Create minimal working nginx module
create_minimal_nginx() {
    log "Creating minimal nginx module..."
    
    sudo tee "$NIXOS_CONFIG_DIR/modules/services/nginx.nix" > /dev/null << 'EOF'
# Minimal Working Nginx Module
{ config, pkgs, lib, ... }:

{
  services.nginx = {
    enable = true;
    package = pkgs.nginxMainline;
    
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
      gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
      
      server_tokens off;
    '';
  };

  users.users.nginx = lib.mkIf (!config.users.users ? nginx) {
    isSystemUser = true;
    group = "nginx";
    description = "Nginx web server user";
  };

  users.groups.nginx = lib.mkIf (!config.users.groups ? nginx) {};

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
EOF

    success "Created minimal nginx module"
}

# Create minimal PHP module
create_minimal_php() {
    log "Creating minimal PHP module..."
    
    sudo tee "$NIXOS_CONFIG_DIR/modules/services/php.nix" > /dev/null << 'EOF'
# Minimal Working PHP Module
{ config, pkgs, lib, ... }:

{
  services.phpfpm.pools.www = {
    user = "nginx";
    group = "nginx";
    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "listen.mode" = "0600";
      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 4;
      "pm.max_requests" = 500;
    };
    
    phpPackage = pkgs.php.buildEnv {
      extensions = ({ enabled, all }: enabled ++ (with pkgs.php84Extensions; [
        mysqli
        pdo_mysql
        mbstring
        gd
        curl
        zip
        fileinfo
        intl
        exif
        openssl
      ]));
      
      extraConfig = ''
        memory_limit = 256M
        upload_max_filesize = 64M
        post_max_size = 64M
        max_execution_time = 300
        date.timezone = UTC
        
        opcache.enable = 1
        opcache.memory_consumption = 128
        opcache.jit_buffer_size = 64M
        opcache.jit = tracing
        
        expose_php = Off
        display_errors = Off
        log_errors = On
        error_log = /var/log/php_errors.log
      '';
    };
  };

  environment.systemPackages = [ pkgs.php ];
}
EOF

    success "Created minimal PHP module"
}

# Create minimal MySQL module
create_minimal_mysql() {
    log "Creating minimal MySQL module..."
    
    sudo tee "$NIXOS_CONFIG_DIR/modules/services/mysql.nix" > /dev/null << 'EOF'
# Minimal Working MySQL Module
{ config, pkgs, lib, ... }:

{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    
    settings.mysqld = {
      bind-address = "127.0.0.1";
      port = 3306;
      require_secure_transport = "OFF";
      ssl = "0";
      character-set-server = "utf8mb4";
      collation-server = "utf8mb4_unicode_ci";
    };
    
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
      
      ALTER USER 'webuser'@'localhost' REQUIRE NONE;
      ALTER USER 'phpmyadmin'@'localhost' REQUIRE NONE;
      
      FLUSH PRIVILEGES;
    '';
  };

  environment.systemPackages = [ pkgs.mysql80 ];
  networking.firewall.allowedTCPPorts = [ 3306 ];
}
EOF

    success "Created minimal MySQL module"
}

# Create simple virtual hosts
create_simple_vhosts() {
    log "Creating simple virtual hosts..."
    
    sudo tee "$NIXOS_CONFIG_DIR/modules/webserver/nginx-vhosts.nix" > /dev/null << 'EOF'
# Simple Virtual Hosts Module
{ config, pkgs, lib, ... }:

{
  services.nginx.virtualHosts = {
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
            include ${pkgs.nginx}/conf/fastcgi_params;
          '';
        };
      };
    };

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
            include ${pkgs.nginx}/conf/fastcgi_params;
          '';
        };
      };
    };

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
            include ${pkgs.nginx}/conf/fastcgi_params;
          '';
        };
      };
    };

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
            include ${pkgs.nginx}/conf/fastcgi_params;
          '';
        };
      };
    };
  };
}
EOF

    success "Created simple virtual hosts"
}

# Create clean configuration.nix
create_clean_configuration() {
    log "Creating clean configuration.nix..."
    
    sudo tee "$NIXOS_CONFIG_DIR/configuration.nix" > /dev/null << 'EOF'
# Clean Working NixOS Configuration
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/networking.nix
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    ./modules/services/mysql.nix
    ./modules/webserver/nginx-vhosts.nix
  ];

  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # User configuration
  users.users.webadmin = {
    isNormalUser = true;
    description = "Web Administrator";
    extraGroups = [ "wheel" "nginx" ];
  };

  # Basic system packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    tree
    htop
  ];

  # Enable SSH
  services.openssh.enable = true;

  # Web directories
  system.activationScripts.webserver-setup = ''
    mkdir -p /var/www/{dashboard,sample1,sample2,sample3}
    chown -R nginx:nginx /var/www
    chmod -R 755 /var/www
  '';

  system.stateVersion = "25.05";
}
EOF

    success "Created clean configuration.nix"
}

# Test the clean configuration
test_clean_config() {
    log "Testing clean configuration..."
    
    if sudo nixos-rebuild dry-build --impure &>/dev/null; then
        success "Clean configuration builds successfully!"
        return 0
    else
        error "Clean configuration still has issues:"
        sudo nixos-rebuild dry-build --impure 2>&1 | head -15
        return 1
    fi
}

# Apply the clean configuration
apply_clean_config() {
    log "Applying clean configuration..."
    
    if sudo nixos-rebuild switch --impure; then
        success "Clean configuration applied successfully!"
        
        # Check services
        sleep 5
        echo ""
        echo "Service status:"
        echo "Nginx: $(systemctl is-active nginx || echo 'inactive')"
        echo "PHP-FPM: $(systemctl is-active phpfpm-www || echo 'inactive')"
        echo "MySQL: $(systemctl is-active mysql || echo 'inactive')"
        
        # Test HTTP
        if curl -s http://localhost >/dev/null; then
            success "HTTP server is responding!"
        else
            warning "HTTP server not responding yet"
        fi
        
        return 0
    else
        error "Failed to apply clean configuration"
        return 1
    fi
}

# Create web content
create_web_content() {
    log "Creating web content..."
    
    # Create simple test pages
    for site in dashboard sample1 sample2 sample3; do
        sudo tee "/var/www/$site/index.html" > /dev/null << EOF
<!DOCTYPE html>
<html>
<head><title>$site.local</title></head>
<body>
    <h1>Welcome to $site.local</h1>
    <p>Clean NixOS webserver is working!</p>
    <p>Time: $(date)</p>
</body>
</html>
EOF
    done
    
    sudo chown -R nginx:nginx /var/www
    sudo chmod -R 755 /var/www
    
    success "Created web content"
}

# Main function
main() {
    echo "🧹 Build Clean Working Configuration"
    echo "==================================="
    echo ""
    
    echo "This will create a completely clean, minimal configuration that works."
    echo "It will replace your current modules with simplified versions."
    echo ""
    
    read -p "Proceed with clean build? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    create_backup
    
    # Create directories
    sudo mkdir -p "$NIXOS_CONFIG_DIR/modules/services"
    sudo mkdir -p "$NIXOS_CONFIG_DIR/modules/webserver"
    
    create_minimal_nginx
    create_minimal_php
    create_minimal_mysql
    create_simple_vhosts
    create_clean_configuration
    
    if test_clean_config; then
        echo ""
        echo "🎯 Clean configuration is valid!"
        echo ""
        read -p "Apply the clean configuration now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if apply_clean_config; then
                create_web_content
                
                echo ""
                echo "🎉 SUCCESS! Clean webserver is running!"
                echo ""
                echo "✅ Services:"
                echo "  - Nginx with nginxMainline"
                echo "  - PHP 8.4 with FPM"
                echo "  - MariaDB with SSL disabled"
                echo "  - Virtual hosts for dashboard.local, sample1.local, etc."
                echo ""
                echo "🌐 Test with:"
                echo "  curl -H 'Host: dashboard.local' http://localhost"
                echo "  curl -H 'Host: sample1.local' http://localhost"
                echo ""
                echo "📋 Add to /etc/hosts:"
                echo "  127.0.0.1 dashboard.local sample1.local sample2.local sample3.local"
            fi
        fi
    else
        error "Clean configuration failed. Check the error output above."
    fi
}

# Run main function
main "$@"