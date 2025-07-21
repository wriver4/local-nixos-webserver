# NixOS Configuration for Nginx with Virtual Domains and PHP-FPM (PHP 8.4)
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
  networking.extraHosts = ''
  127.0.0.1 dashboard.local
  127.0.0.1 phpmyadmin.local
  127.0.0.1 sample1.local
  127.0.0.1 sample2.local
  127.0.0.1 sample3.local
  '';

  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # User configuration
  users.users.webadmin = {
    isNormalUser = true;
    description = "Web Administrator";
    extraGroups = [ "wheel" "nginx" "wwwrun" ];
    packages = with pkgs; [
      firefox
      tree
      htop
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

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 3306 ];
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

  system.stateVersion = "23.11";
}
