# NixOS Configuration for Nginx with Virtual Domains, PHP-FPM (PHP 8.4), OPcache, and Redis
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network configuration
  networking.hostName = "nixos-webserver";
  networking.networkmanager.enable = true;

  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # User configuration
  users.users.webadmin = {
    isNormalUser = true;
    description = "Web Administrator";
    extraGroups = [ "wheel" "nginx" "wwwrun" "redis" ];
    packages = with pkgs; [
      firefox
      tree
      htop
      redis
    ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    tree
    htop
    mysql80
    redis
    php84Packages.composer
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

  # Redis configuration
  services.redis.servers.main = {
    enable = true;
    bind = "127.0.0.1";
    port = 6379;
    databases = 16;
    maxmemory = "256mb";
    maxmemoryPolicy = "allkeys-lru";
    save = [
      [900 1]   # Save after 900 sec if at least 1 key changed
      [300 10]  # Save after 300 sec if at least 10 keys changed
      [60 10000] # Save after 60 sec if at least 10000 keys changed
    ];
    settings = {
      # Performance settings
      tcp-keepalive = 300;
      timeout = 0;
      
      # Memory optimization
      hash-max-ziplist-entries = 512;
      hash-max-ziplist-value = 64;
      list-max-ziplist-size = -2;
      list-compress-depth = 0;
      set-max-intset-entries = 512;
      zset-max-ziplist-entries = 128;
      zset-max-ziplist-value = 64;
      
      # Logging
      loglevel = "notice";
      logfile = "/var/log/redis/redis.log";
      
      # Security
      protected-mode = "yes";
      
      # Persistence
      rdbcompression = "yes";
      rdbchecksum = "yes";
      
      # Append only file
      appendonly = "yes";
      appendfsync = "everysec";
      no-appendfsync-on-rewrite = "no";
      auto-aof-rewrite-percentage = 100;
      auto-aof-rewrite-min-size = "64mb";
    };
  };

  # PHP-FPM configuration with PHP 8.4, OPcache, and Redis
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
        
        # Performance monitoring
        "pm.status_path" = "/fpm-status";
        "ping.path" = "/fpm-ping";
        "ping.response" = "pong";
        
        # Process management
        "request_terminate_timeout" = "300s";
        "request_slowlog_timeout" = "10s";
        "slowlog" = "/var/log/php-fpm-slow.log";
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
          opcache.inherited_hack = 1
          opcache.dups_fix = 0
          opcache.blacklist_filename = /etc/php/opcache-blacklist.txt
          
          ; OPcache JIT (PHP 8.4)
          opcache.jit_buffer_size = 64M
          opcache.jit = 1255
          opcache.jit_hot_loop = 64
          opcache.jit_hot_func = 16
          opcache.jit_hot_return = 8
          opcache.jit_hot_side_exit = 8
          opcache.jit_blacklist_root_trace = 16
          opcache.jit_blacklist_side_trace = 8
          opcache.jit_max_root_traces = 1024
          opcache.jit_max_side_traces = 128
          opcache.jit_max_exit_counters = 8192
          opcache.jit_max_loop_unrolls = 8
          opcache.jit_max_recursive_calls = 2
          opcache.jit_max_recursive_returns = 2
          opcache.jit_max_try_catch_depth = 4
          
          ; APCu Configuration
          apc.enabled = 1
          apc.shm_size = 64M
          apc.ttl = 7200
          apc.user_ttl = 7200
          apc.gc_ttl = 3600
          apc.entries_hint = 4096
          apc.slam_defense = 1
          apc.use_request_time = 1
          
          ; Redis Configuration
          redis.session.locking_enabled = 1
          redis.session.lock_expire = 60
          redis.session.lock_wait_time = 50000
          redis.session.lock_retries = 100
          
          ; Session Configuration with Redis
          session.save_handler = redis
          session.save_path = "tcp://127.0.0.1:6379?database=1"
          session.gc_maxlifetime = 3600
          session.cookie_lifetime = 0
          session.cookie_secure = 0
          session.cookie_httponly = 1
          session.use_strict_mode = 1
          session.cookie_samesite = "Lax"
          
          ; Security settings
          expose_php = Off
          display_errors = Off
          log_errors = On
          error_log = /var/log/php_errors.log
          
          ; Performance settings
          realpath_cache_size = 4096K
          realpath_cache_ttl = 600
          
          ; File uploads
          file_uploads = On
          upload_tmp_dir = /tmp
          max_file_uploads = 20
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
      worker_rlimit_nofile 2048;
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
      gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript application/atom+xml image/svg+xml;
      
      # FastCGI caching
      fastcgi_cache_path /var/cache/nginx/fastcgi levels=1:2 keys_zone=WORDPRESS:100m inactive=60m;
      fastcgi_cache_key "$scheme$request_method$host$request_uri";
      fastcgi_cache_use_stale error timeout invalid_header http_500;
      fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
      
      # Security headers
      add_header X-Frame-Options DENY;
      add_header X-Content-Type-Options nosniff;
      add_header X-XSS-Protection "1; mode=block";
      add_header Referrer-Policy "strict-origin-when-cross-origin";
      
      # Cache control for static files
      location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
      }
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
          "/opcache-status" = {
            extraConfig = ''
              fastcgi_pass unix:${config.services.phpfpm.pools.www.socket};
              fastcgi_param SCRIPT_FILENAME $document_root/opcache-status.php;
              include ${pkgs.nginx}/conf/fastcgi_params;
            '';
          };
          "/fpm-status" = {
            extraConfig = ''
              fastcgi_pass unix:${config.services.phpfpm.pools.www.socket};
              include ${pkgs.nginx}/conf/fastcgi_params;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              allow 127.0.0.1;
              deny all;
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

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 3306 6379 ];
  };

  # System activation script to create directories and files
  system.activationScripts.websetup = ''
    # Create web directories
    mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}
    chown -R nginx:nginx /var/www
    chmod -R 755 /var/www
    
    # Create cache directories
    mkdir -p /var/cache/nginx/fastcgi
    chown -R nginx:nginx /var/cache/nginx
    chmod -R 755 /var/cache/nginx
    
    # Create log directories
    mkdir -p /var/log/{php-fpm,redis}
    touch /var/log/php_errors.log
    touch /var/log/php-fpm-slow.log
    chown nginx:nginx /var/log/php_errors.log
    chown nginx:nginx /var/log/php-fpm-slow.log
    chown redis:redis /var/log/redis
    chmod 644 /var/log/php_errors.log
    chmod 644 /var/log/php-fpm-slow.log
    
    # Create OPcache blacklist
    mkdir -p /etc/php
    touch /etc/php/opcache-blacklist.txt
    chown nginx:nginx /etc/php/opcache-blacklist.txt
    chmod 644 /etc/php/opcache-blacklist.txt
    
    # Create Redis data directory
    mkdir -p /var/lib/redis
    chown redis:redis /var/lib/redis
    chmod 750 /var/lib/redis
  '';

  system.stateVersion = "23.11";
}
