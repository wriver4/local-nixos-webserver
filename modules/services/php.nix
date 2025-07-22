# Enhanced PHP-FPM Service Module
# This module provides PHP-FPM configuration that works with existing setups
# Uses lib.mkDefault extensively to avoid conflicts

{ config, pkgs, lib, ... }:

{
  # PHP-FPM service configuration with conflict resolution
  # Note: PHP-FPM is automatically enabled when pools are configured
  services.phpfpm = {
    # Default PHP pool configuration
    pools.www = {
      user = lib.mkDefault "nginx";
      group = lib.mkDefault "nginx";
      
      settings = {
        "listen.owner" = lib.mkDefault "nginx";
        "listen.group" = lib.mkDefault "nginx";
        "listen.mode" = lib.mkDefault "0600";
        
        # Process management
        "pm" = lib.mkDefault "dynamic";
        "pm.max_children" = lib.mkDefault 75;
        "pm.start_servers" = lib.mkDefault 10;
        "pm.min_spare_servers" = lib.mkDefault 5;
        "pm.max_spare_servers" = lib.mkDefault 20;
        "pm.max_requests" = lib.mkDefault 500;
        
        # Process optimization
        "pm.process_idle_timeout" = lib.mkDefault "10s";
        "pm.max_spawn_rate" = lib.mkDefault 32;
        
        # Monitoring
        "pm.status_path" = lib.mkDefault "/status";
        "ping.path" = lib.mkDefault "/ping";
        "ping.response" = lib.mkDefault "pong";
        
        # Request handling
        "request_terminate_timeout" = lib.mkDefault "300s";
        "request_slowlog_timeout" = lib.mkDefault "10s";
        "slowlog" = lib.mkDefault "/var/log/php-fpm-slow.log";
      };
      
      # PHP package with extensions (uses mkDefault to allow override)
      phpPackage = lib.mkDefault (pkgs.php.buildEnv {
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
          
          # Core functionality
          json
          session
          filter
        ]));
        
        extraConfig = ''
          # Basic PHP configuration
          memory_limit = 256M
          upload_max_filesize = 64M
          post_max_size = 64M
          max_execution_time = 300
          max_input_vars = 3000
          date.timezone = UTC
          
          # PHP 8.4 optimizations
          opcache.enable = 1
          opcache.memory_consumption = 128
          opcache.interned_strings_buffer = 8
          opcache.max_accelerated_files = 4000
          opcache.revalidate_freq = 2
          opcache.fast_shutdown = 1
          opcache.enable_cli = 1
          
          # JIT optimization (PHP 8.4)
          opcache.jit_buffer_size = 64M
          opcache.jit = tracing
          
          # Security settings
          expose_php = Off
          display_errors = Off
          log_errors = On
          error_log = /var/log/php_errors.log
          allow_url_fopen = Off
          allow_url_include = Off
          
          # Session security
          session.cookie_httponly = On
          session.use_strict_mode = On
          session.cookie_samesite = "Strict"
        '';
      });
    };
  };

  # Add PHP CLI to system packages
  environment.systemPackages = with pkgs; [
    php  # PHP 8.4 CLI tools
  ];

  # Systemd service optimization
  systemd.services.phpfpm-www.serviceConfig = lib.mkMerge [
    {
      LimitNOFILE = lib.mkDefault 65535;
      LimitNPROC = lib.mkDefault 4096;
    }
  ];

  # Create PHP log directories
  system.activationScripts.php-logs = ''
    mkdir -p /var/log
    touch /var/log/php_errors.log
    touch /var/log/php-fpm-slow.log
    chown nginx:nginx /var/log/php_errors.log
    chown nginx:nginx /var/log/php-fpm-slow.log
    chmod 644 /var/log/php_errors.log
    chmod 644 /var/log/php-fpm-slow.log
  '';
}