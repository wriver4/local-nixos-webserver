# Webserver PHP Optimization Configuration
# This module adds webserver-specific PHP optimizations to existing PHP configuration

{ config, pkgs, lib, ... }:

{
  # PHP-FPM webserver-specific configuration
  # This enhances the existing PHP configuration with webserver optimizations
  
  services.phpfpm = {
    # Ensure PHP-FPM is enabled (uses mkDefault to not conflict)
    enable = lib.mkDefault true;
    
    # Configure webserver-specific PHP pool
    pools.www = lib.mkMerge [
      {
        # Pool configuration optimized for webserver
        user = lib.mkDefault "nginx";
        group = lib.mkDefault "nginx";
        
        settings = {
          "listen.owner" = lib.mkDefault "nginx";
          "listen.group" = lib.mkDefault "nginx";
          "listen.mode" = lib.mkDefault "0600";
          
          # Performance optimization for webserver
          "pm" = lib.mkDefault "dynamic";
          "pm.max_children" = lib.mkDefault 75;
          "pm.start_servers" = lib.mkDefault 10;
          "pm.min_spare_servers" = lib.mkDefault 5;
          "pm.max_spare_servers" = lib.mkDefault 20;
          "pm.max_requests" = lib.mkDefault 500;
          
          # Webserver-specific settings
          "pm.process_idle_timeout" = lib.mkDefault "10s";
          "pm.status_path" = lib.mkDefault "/status";
          "ping.path" = lib.mkDefault "/ping";
          "ping.response" = lib.mkDefault "pong";
          
          # Request optimization
          "request_terminate_timeout" = lib.mkDefault "300s";
          "request_slowlog_timeout" = lib.mkDefault "10s";
          "slowlog" = lib.mkDefault "/var/log/php-fpm-slow.log";
        };
        
        # PHP package with webserver-specific extensions and configuration
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
            # Webserver-specific PHP configuration
            
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
        });
      }
    ];
  };

  # Create PHP error log directory
  system.activationScripts.webserver-php-logs = ''
    mkdir -p /var/log
    touch /var/log/php_errors.log
    touch /var/log/php-fpm-slow.log
    chown nginx:nginx /var/log/php_errors.log
    chown nginx:nginx /var/log/php-fpm-slow.log
    chmod 644 /var/log/php_errors.log
    chmod 644 /var/log/php-fpm-slow.log
  '';

  # Add PHP CLI to system packages
  environment.systemPackages = with pkgs; [
    php  # PHP 8.4 CLI tools
  ];

  # Log rotation for PHP logs
  services.logrotate.settings = {
    "/var/log/php_errors.log" = {
      frequency = "daily";
      rotate = 7;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      copytruncate = true;
    };
    
    "/var/log/php-fpm-slow.log" = {
      frequency = "daily";
      rotate = 7;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      postrotate = "systemctl reload phpfpm-www";
    };
  };
}