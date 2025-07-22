# Webserver PHP-FPM Service Module
# This module provides PHP-FPM configuration for the webserver
# Configured for PHP 8.4 with NixOS 25.05 compatibility

{ config, pkgs, lib, ... }:

{
  # PHP-FPM configuration with PHP 8.4
  services.phpfpm = {
    pools.webserver = {
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
      
      # PHP 8.4 package with extensions
      phpPackage = pkgs.php.buildEnv {
        extensions = ({ enabled, all }: enabled ++ (with pkgs.php84Extensions; [
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

  # Create PHP error log directory
  system.activationScripts.webserver-php-logs = ''
    mkdir -p /var/log
    touch /var/log/php_errors.log
    chown nginx:nginx /var/log/php_errors.log
    chmod 644 /var/log/php_errors.log
  '';

  # Add PHP CLI to system packages
  environment.systemPackages = with pkgs; [
    php  # PHP 8.4 CLI tools
  ];
}