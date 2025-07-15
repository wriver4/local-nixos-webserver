# NixOS Configuration for Nginx with Virtual Domains and PHP-FPM
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

  # PHP-FPM configuration
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
      phpPackage = pkgs.php82.buildEnv {
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
        ]));
        extraConfig = ''
          memory_limit = 256M
          upload_max_filesize = 64M
          post_max_size = 64M
          max_execution_time = 300
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
      
      gzip on;
      gzip_vary on;
      gzip_min_length 1024;
      gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
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
              include ${pkgs.nginx}/conf/fastcgi_params;
            '';
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
              include ${pkgs.nginx}/conf/fastcgi_params;
            '';
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
              include ${pkgs.nginx}/conf/fastcgi_params;
            '';
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
              include ${pkgs.nginx}/conf/fastcgi_params;
            '';
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
              include ${pkgs.nginx}/conf/fastcgi_params;
            '';
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
  '';

  system.stateVersion = "23.11";
}
