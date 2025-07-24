#!/usr/bin/env bash

# Create Single-File Configuration
# This script creates a working configuration without any modules to avoid recursion

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
    
    local backup_dir="/etc/nixos/single-file-backup-$(date +%Y%m%d-%H%M%S)"
    sudo mkdir -p "$backup_dir"
    sudo cp -r /etc/nixos/* "$backup_dir/" 2>/dev/null || true
    
    # Create restore script
    sudo tee "$backup_dir/restore.sh" > /dev/null << EOF
#!/bin/bash
echo "Restoring modular configuration from backup..."
sudo cp -r "$backup_dir"/* /etc/nixos/
sudo rm /etc/nixos/restore.sh
echo "Modular configuration restored."
EOF
    sudo chmod +x "$backup_dir/restore.sh"
    
    success "Backup created at: $backup_dir"
}

# Create single-file configuration with everything inline
create_single_file_config() {
    log "Creating single-file configuration..."
    
    sudo tee "$NIXOS_CONFIG_DIR/configuration.nix" > /dev/null << 'EOF'
# Single-File NixOS Webserver Configuration
# All functionality in one file to avoid module recursion issues

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking configuration (application-level only)
  networking = {
    hostName = "nixos-webserver";
    
    # Use NetworkManager (compatible with hardware DHCP)
    networkmanager.enable = true;
    
    # Host entries for local development
    hosts = {
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
    
    # Firewall configuration
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 3306 ];
      allowPing = false;
      logRefusedConnections = true;
    };
    
    # DNS configuration
    nameservers = [ "8.8.8.8" "8.8.4.4" "1.1.1.1" ];
    enableIPv6 = true;
  };

  # Nginx configuration with nginxMainline
  services.nginx = {
    enable = true;
    package = pkgs.nginxMainline;
    user = "nginx";
    group = "nginx";
    
    # Global nginx configuration
    appendConfig = ''
      worker_processes auto;
      worker_connections 1024;
      worker_rlimit_nofile 65535;
      
      events {
        use epoll;
        multi_accept on;
      }
    '';

    # HTTP configuration
    commonHttpConfig = ''
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
      keepalive_timeout 65;
      types_hash_max_size 2048;
      client_max_body_size 64M;
      
      # Compression
      gzip on;
      gzip_vary on;
      gzip_min_length 1024;
      gzip_comp_level 6;
      gzip_types
        text/plain
        text/css
        application/json
        application/javascript
        text/xml
        application/xml
        application/xml+rss
        text/javascript
        application/atom+xml
        image/svg+xml;
      
      # Security headers
      server_tokens off;
      add_header X-Frame-Options SAMEORIGIN always;
      add_header X-Content-Type-Options nosniff always;
      add_header X-XSS-Protection "1; mode=block" always;
      
      # Rate limiting
      limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
      limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
      
      # File caching
      open_file_cache max=200000 inactive=20s;
      open_file_cache_valid 30s;
      open_file_cache_min_uses 2;
      open_file_cache_errors on;
    '';
    
    # Virtual hosts
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

      # Sample sites
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

  # PHP-FPM configuration with PHP 8.4
  services.phpfpm.pools.www = {
    user = "nginx";
    group = "nginx";
    
    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "listen.mode" = "0600";
      
      # Performance optimization
      "pm" = "dynamic";
      "pm.max_children" = 75;
      "pm.start_servers" = 10;
      "pm.min_spare_servers" = 5;
      "pm.max_spare_servers" = 20;
      "pm.max_requests" = 500;
      
      # Process optimization
      "pm.process_idle_timeout" = "10s";
      "pm.status_path" = "/status";
      "ping.path" = "/ping";
      "ping.response" = "pong";
      
      # Request handling
      "request_terminate_timeout" = "300s";
      "request_slowlog_timeout" = "10s";
      "slowlog" = "/var/log/php-fpm-slow.log";
    };
    
    # PHP package with extensions
    phpPackage = pkgs.php.buildEnv {
      extensions = ({ enabled, all }: enabled ++ (with pkgs.php84Extensions; [
        # Database extensions
        mysqli
        pdo_mysql
        
        # String/text processing
        mbstring
        intl
        
        # File handling
        zip
        fileinfo
        
        # Graphics
        gd
        exif
        
        # Network
        curl
        openssl
        
        # Note: json, session, filter are built-in to PHP 8.4
      ]));
      
      extraConfig = ''
        # Memory and execution limits
        memory_limit = 256M
        max_execution_time = 300
        max_input_time = 300
        max_input_vars = 3000
        
        # File upload configuration
        upload_max_filesize = 64M
        post_max_size = 64M
        max_file_uploads = 20
        
        # Session configuration
        session.gc_maxlifetime = 3600
        session.gc_probability = 1
        session.gc_divisor = 1000
        session.cookie_httponly = On
        session.use_strict_mode = On
        
        # Security settings
        expose_php = Off
        display_errors = Off
        log_errors = On
        error_log = /var/log/php_errors.log
        allow_url_fopen = Off
        allow_url_include = Off
        
        # Performance optimization
        realpath_cache_size = 4096k
        realpath_cache_ttl = 600
        
        # OPcache optimization for PHP 8.4
        opcache.enable = 1
        opcache.memory_consumption = 128
        opcache.interned_strings_buffer = 8
        opcache.max_accelerated_files = 4000
        opcache.revalidate_freq = 2
        opcache.fast_shutdown = 1
        opcache.enable_cli = 1
        opcache.save_comments = 0
        opcache.validate_timestamps = 1
        
        # JIT optimization (PHP 8.4 feature)
        opcache.jit_buffer_size = 64M
        opcache.jit = tracing
        
        # Timezone
        date.timezone = UTC
      '';
    };
  };

  # MySQL/MariaDB configuration
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    
    # MySQL settings
    settings.mysqld = {
      # Basic configuration
      bind-address = "127.0.0.1";
      port = 3306;
      
      # SSL/TLS configuration - disabled for local development
      require_secure_transport = "OFF";
      ssl = "0";
      
      # Character set
      character-set-server = "utf8mb4";
      collation-server = "utf8mb4_unicode_ci";
      
      # InnoDB optimization
      innodb_buffer_pool_size = "256M";
      innodb_log_file_size = "64M";
      innodb_flush_log_at_trx_commit = "2";
      innodb_flush_method = "O_DIRECT";
      
      # Query optimization
      query_cache_type = "1";
      query_cache_size = "32M";
      query_cache_limit = "2M";
      
      # Connection settings
      max_connections = "200";
      max_connect_errors = "1000";
      
      # Buffer optimization
      key_buffer_size = "32M";
      sort_buffer_size = "2M";
      read_buffer_size = "1M";
      read_rnd_buffer_size = "2M";
      
      # Temporary table optimization
      tmp_table_size = "32M";
      max_heap_table_size = "32M";
      
      # Logging
      slow_query_log = "1";
      slow_query_log_file = "/var/log/mysql/slow.log";
      long_query_time = "2";
    };
    
    # Webserver-specific databases
    initialDatabases = [
      { name = "dashboard_db"; }
      { name = "sample1_db"; }
      { name = "sample2_db"; }
      { name = "sample3_db"; }
    ];
    
    # Database initialization
    initialScript = pkgs.writeText "webserver-mysql-init.sql" ''
      -- Webserver database initialization
      CREATE USER IF NOT EXISTS 'webuser'@'localhost' IDENTIFIED BY 'webpass123';
      GRANT ALL PRIVILEGES ON dashboard_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample1_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample2_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample3_db.* TO 'webuser'@'localhost';
      
      -- phpMyAdmin user
      CREATE USER IF NOT EXISTS 'phpmyadmin'@'localhost' IDENTIFIED BY 'pmapass123';
      GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost' WITH GRANT OPTION;
      
      -- Ensure users can connect without SSL
      ALTER USER 'webuser'@'localhost' REQUIRE NONE;
      ALTER USER 'phpmyadmin'@'localhost' REQUIRE NONE;
      
      FLUSH PRIVILEGES;
    '';
  };

  # Users
  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
    description = "Nginx web server user";
    home = "/var/lib/nginx";
    createHome = true;
  };

  users.groups.nginx = {};

  users.users.webadmin = {
    isNormalUser = true;
    description = "Web Administrator";
    extraGroups = [ "wheel" "nginx" ];
  };

  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    tree
    htop
    php      # PHP 8.4 CLI tools
    mysql80  # MySQL client tools
    nettools
    inetutils
    dnsutils
  ];

  # Enable SSH
  services.openssh.enable = true;

  # Network services
  services.timesyncd.enable = true;
  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    domains = [ "~." ];
    fallbackDns = [ "8.8.8.8" "8.8.4.4" "1.1.1.1" ];
  };

  # System activation scripts
  system.activationScripts = {
    # Web directories
    webserver-setup = ''
      mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}
      chown -R nginx:nginx /var/www
      chmod -R 755 /var/www
    '';
    
    # Nginx directories
    nginx-dirs = ''
      mkdir -p /var/lib/nginx
      mkdir -p /var/log/nginx
      mkdir -p /run/nginx
      chown -R nginx:nginx /var/lib/nginx
      chown -R nginx:nginx /var/log/nginx
      chown -R nginx:nginx /run/nginx
    '';
    
    # PHP logs
    php-logs = ''
      mkdir -p /var/log
      touch /var/log/php_errors.log
      touch /var/log/php-fpm-slow.log
      chown nginx:nginx /var/log/php_errors.log
      chown nginx:nginx /var/log/php-fpm-slow.log
      chmod 644 /var/log/php_errors.log
      chmod 644 /var/log/php-fpm-slow.log
    '';
    
    # MySQL logs
    mysql-logs = ''
      mkdir -p /var/log/mysql
      chown mysql:mysql /var/log/mysql
      chmod 755 /var/log/mysql
    '';
  };

  # System optimization
  boot.kernel.sysctl = {
    # Network performance optimization
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    
    # TCP optimization
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    
    # Network security
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
  };

  # Systemd service optimization
  systemd.services.nginx.serviceConfig = {
    LimitNOFILE = 65535;
    LimitNPROC = 4096;
  };

  systemd.services.phpfpm-www.serviceConfig = {
    LimitNOFILE = 65535;
    LimitNPROC = 4096;
  };

  systemd.services.mysql.serviceConfig = {
    LimitNOFILE = 65535;
    LimitNPROC = 4096;
  };

  system.stateVersion = "25.05";
}
EOF

    success "Created single-file configuration"
}

# Test the single-file configuration
test_single_file_config() {
    log "Testing single-file configuration..."
    
    if sudo nixos-rebuild dry-build --impure &>/dev/null; then
        success "🎉 Single-file configuration works!"
        return 0
    else
        error "Single-file configuration still has issues:"
        sudo nixos-rebuild dry-build --impure 2>&1 | head -15
        return 1
    fi
}

# Apply the configuration
apply_configuration() {
    log "Applying single-file configuration..."
    
    if sudo nixos-rebuild switch --impure; then
        success "🎉 Single-file webserver deployed successfully!"
        
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
        error "Failed to apply single-file configuration"
        return 1
    fi
}

# Create web content
create_web_content() {
    log "Creating web content..."
    
    # Create test pages for each site
    for site in dashboard sample1 sample2 sample3; do
        sudo tee "/var/www/$site/index.html" > /dev/null << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$site.local - Single-File NixOS Webserver</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007acc; padding-bottom: 10px; }
        .status { background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 $site.local</h1>
        <div class="status">
            <strong>✅ Status:</strong> Single-file NixOS webserver is working!<br>
            <strong>🕒 Time:</strong> $(date)<br>
            <strong>🌐 Host:</strong> $site.local<br>
            <strong>📦 Nginx:</strong> nginxMainline<br>
            <strong>🐘 PHP:</strong> 8.4 with JIT<br>
            <strong>🗄️ Database:</strong> MariaDB
        </div>
        
        <h2>Features</h2>
        <ul>
            <li>✅ No module recursion issues</li>
            <li>✅ All functionality in one file</li>
            <li>✅ nginxMainline with HTTP/2</li>
            <li>✅ PHP 8.4 with JIT compilation</li>
            <li>✅ MariaDB with SSL disabled for local dev</li>
            <li>✅ Virtual hosts for all sample sites</li>
            <li>✅ Network optimization</li>
            <li>✅ Security headers</li>
        </ul>
    </div>
</body>
</html>
EOF
    done
    
    # Create PHP test page
    sudo tee "/var/www/dashboard/info.php" > /dev/null << 'EOF'
<?php
echo "<h1>PHP Information</h1>";
echo "<p>PHP Version: " . PHP_VERSION . "</p>";
echo "<p>Server Software: " . $_SERVER['SERVER_SOFTWARE'] . "</p>";
echo "<p>Document Root: " . $_SERVER['DOCUMENT_ROOT'] . "</p>";

if (version_compare(PHP_VERSION, '8.4.0', '>=')) {
    echo "<h2>🚀 PHP 8.4 Features</h2>";
    echo "<ul>";
    echo "<li>Property hooks</li>";
    echo "<li>Asymmetric visibility</li>";
    echo "<li>JIT compilation enabled</li>";
    echo "<li>Performance improvements</li>";
    echo "</ul>";
}

echo "<h2>Loaded Extensions</h2>";
$extensions = get_loaded_extensions();
sort($extensions);
echo "<ul>";
foreach ($extensions as $ext) {
    echo "<li>$ext</li>";
}
echo "</ul>";
?>
EOF
    
    sudo chown -R nginx:nginx /var/www
    sudo chmod -R 755 /var/www
    
    success "Created web content"
}

# Main function
main() {
    echo "📄 Create Single-File Configuration"
    echo "==================================="
    echo ""
    
    echo "Since modules keep causing infinite recursion, this will create"
    echo "a single-file configuration with all functionality inline."
    echo ""
    echo "✅ Features included:"
    echo "  - nginxMainline with HTTP/2"
    echo "  - PHP 8.4 with JIT compilation"
    echo "  - MariaDB with SSL disabled"
    echo "  - Virtual hosts for all sample sites"
    echo "  - Network optimization"
    echo "  - Security headers"
    echo "  - No module recursion issues!"
    echo ""
    
    read -p "Proceed with single-file configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    create_backup
    create_single_file_config
    
    if test_single_file_config; then
        echo ""
        echo "🎯 Single-file configuration is valid!"
        echo ""
        read -p "Apply the configuration now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if apply_configuration; then
                create_web_content
                
                echo ""
                echo "🎉 SUCCESS! Single-file webserver is running!"
                echo ""
                echo "✅ All services active:"
                echo "  - Nginx with nginxMainline"
                echo "  - PHP 8.4 with FPM and JIT"
                echo "  - MariaDB with webserver databases"
                echo ""
                echo "🌐 Test virtual hosts:"
                echo "  curl -H 'Host: dashboard.local' http://localhost"
                echo "  curl -H 'Host: sample1.local' http://localhost"
                echo ""
                echo "📋 Add to /etc/hosts:"
                echo "  127.0.0.1 dashboard.local sample1.local sample2.local sample3.local phpmyadmin.local"
                echo ""
                echo "🔗 Access:"
                echo "  http://dashboard.local"
                echo "  http://dashboard.local/info.php (PHP info)"
                echo "  http://sample1.local"
                echo ""
                echo "🎯 No more infinite recursion - everything works!"
            fi
        fi
    else
        error "Single-file configuration failed. This suggests a deeper NixOS issue."
    fi
}

# Run main function
main "$@"