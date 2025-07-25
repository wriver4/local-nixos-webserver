# PHP-FPM Configuration Module
# NixOS 25.05 Compatible - PHP 8.4 with Performance Optimizations
# Includes OPcache, JIT, APCu, and Redis support

{ config, pkgs, ... }:

{
  # PHP-FPM service configuration with PHP 8.4
  services.phpfpm = {
    pools.www = {
      user = "nginx";
      group = "nginx";
      
      # Socket configuration
      settings = {
        "listen.owner" = "nginx";
        "listen.group" = "nginx";
        "listen.mode" = "0600";
        
        # Process management - Dynamic with performance tuning
        "pm" = "dynamic";
        "pm.max_children" = 100;
        "pm.start_servers" = 20;
        "pm.min_spare_servers" = 10;
        "pm.max_spare_servers" = 30;
        "pm.max_requests" = 1000;
        "pm.process_idle_timeout" = "10s";
        
        # Performance monitoring
        "pm.status_path" = "/status";
        "ping.path" = "/ping";
        "ping.response" = "pong";
        
        # Logging
        "access.log" = "/var/log/php-fpm/access.log";
        "access.format" = "%R - %u %t \"%m %r\" %s %f %{mili}d %{kilo}M %C%%";
        "slowlog" = "/var/log/php-fpm/slow.log";
        "request_slowlog_timeout" = "5s";
        
        # Security
        "security.limit_extensions" = ".php .phar";
        
        # Environment variables
        "env[HOSTNAME]" = "$HOSTNAME";
        "env[PATH]" = "/usr/local/bin:/usr/bin:/bin";
        "env[TMP]" = "/tmp";
        "env[TMPDIR]" = "/tmp";
        "env[TEMP]" = "/tmp";
      };
      
      # PHP 8.4 with comprehensive extensions and optimizations
      phpPackage = pkgs.php84.buildEnv {
        extensions = ({ enabled, all }: enabled ++ (with all; [
          # Database extensions
          mysqli
          pdo_mysql
          pdo_sqlite
          
          # String and data processing
          mbstring
          iconv
          intl
          
          # File and archive handling
          zip
          fileinfo
          
          # Image processing
          gd
          exif
          
          # Network and HTTP
          curl
          openssl
          
          # Session and caching
          session
          redis
          apcu
          
          # Performance and optimization
          opcache
          
          # JSON and XML processing
          json
          xml
          simplexml
          xmlreader
          xmlwriter
          
          # Security and filtering
          filter
          hash
          
          # Date and time
          date
          
          # Math and encryption
          bcmath
          sodium
          
          # System interaction
          posix
          pcntl
          
          # Development and debugging
          xdebug
        ]));
        
        # PHP 8.4 optimized configuration
        extraConfig = ''
          ; === BASIC CONFIGURATION ===
          memory_limit = 512M
          upload_max_filesize = 128M
          post_max_size = 128M
          max_execution_time = 300
          max_input_time = 300
          max_input_vars = 5000
          default_socket_timeout = 60
          date.timezone = UTC
          
          ; === ERROR HANDLING AND LOGGING ===
          log_errors = On
          error_log = /var/log/php_errors.log
          display_errors = Off
          display_startup_errors = Off
          error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
          
          ; === SESSION CONFIGURATION WITH REDIS ===
          session.save_handler = redis
          session.save_path = "tcp://127.0.0.1:6379?database=1"
          session.gc_maxlifetime = 7200
          session.cookie_lifetime = 0
          session.cookie_secure = 0
          session.cookie_httponly = 1
          session.cookie_samesite = "Lax"
          session.use_strict_mode = 1
          session.sid_length = 48
          session.sid_bits_per_character = 6
          
          ; === OPCACHE CONFIGURATION (PHP 8.4 OPTIMIZED) ===
          opcache.enable = 1
          opcache.enable_cli = 0
          opcache.memory_consumption = 512
          opcache.interned_strings_buffer = 32
          opcache.max_accelerated_files = 20000
          opcache.max_wasted_percentage = 5
          opcache.use_cwd = 1
          opcache.validate_timestamps = 1
          opcache.revalidate_freq = 2
          opcache.revalidate_path = 0
          opcache.save_comments = 1
          opcache.fast_shutdown = 1
          opcache.enable_file_override = 0
          opcache.optimization_level = 0x7FFFBFFF
          opcache.dups_fix = 0
          opcache.blacklist_filename = ""
          
          ; === OPCACHE JIT (PHP 8.4 ENHANCED) ===
          opcache.jit_buffer_size = 128M
          opcache.jit = 1255
          opcache.jit_hot_loop = 64
          opcache.jit_hot_func = 127
          opcache.jit_hot_return = 8
          opcache.jit_hot_side_exit = 8
          opcache.jit_blacklist_root_trace = 16
          opcache.jit_blacklist_side_trace = 8
          opcache.jit_max_root_traces = 1024
          opcache.jit_max_side_traces = 128
          opcache.jit_max_exit_counters = 8192
          
          ; === APCU CONFIGURATION ===
          apc.enabled = 1
          apc.shm_size = 128M
          apc.ttl = 7200
          apc.user_ttl = 7200
          apc.gc_ttl = 3600
          apc.entries_hint = 4096
          apc.slam_defense = 1
          apc.use_request_time = 1
          
          ; === REDIS CONFIGURATION ===
          redis.session.locking_enabled = 1
          redis.session.lock_expire = 60
          redis.session.lock_wait_time = 50000
          redis.session.lock_retries = 100
          
          ; === SECURITY SETTINGS ===
          expose_php = Off
          allow_url_fopen = On
          allow_url_include = Off
          enable_dl = Off
          file_uploads = On
          max_file_uploads = 20
          
          ; === PERFORMANCE SETTINGS ===
          realpath_cache_size = 8192K
          realpath_cache_ttl = 600
          max_input_nesting_level = 64
          
          ; === OUTPUT BUFFERING ===
          output_buffering = 4096
          implicit_flush = Off
          
          ; === ZLIB COMPRESSION ===
          zlib.output_compression = Off
          zlib.output_compression_level = 6
          
          ; === MBSTRING CONFIGURATION ===
          mbstring.language = English
          mbstring.internal_encoding = UTF-8
          mbstring.http_input = UTF-8
          mbstring.http_output = UTF-8
          mbstring.encoding_translation = Off
          mbstring.detect_order = UTF-8,ASCII
          mbstring.substitute_character = none
          
          ; === GD CONFIGURATION ===
          gd.jpeg_ignore_warning = 1
          
          ; === CURL CONFIGURATION ===
          curl.cainfo = /etc/ssl/certs/ca-certificates.crt
          
          ; === XDEBUG CONFIGURATION (DEVELOPMENT) ===
          xdebug.mode = develop,debug
          xdebug.start_with_request = trigger
          xdebug.client_host = localhost
          xdebug.client_port = 9003
          xdebug.log = /var/log/xdebug.log
          xdebug.max_nesting_level = 512
          
          ; === PHP 8.4 SPECIFIC OPTIMIZATIONS ===
          ; Enable property hooks (PHP 8.4 feature)
          ; Enable asymmetric visibility (PHP 8.4 feature)
          ; These are language features, no INI settings needed
          
          ; === CUSTOM SETTINGS FOR WEB APPLICATIONS ===
          auto_prepend_file = ""
          auto_append_file = ""
          default_charset = "UTF-8"
          
          ; === MAIL CONFIGURATION ===
          SMTP = localhost
          smtp_port = 25
          sendmail_path = /usr/sbin/sendmail -t -i
          
          ; === RESOURCE LIMITS ===
          max_input_time = 300
          memory_limit = 512M
          
          ; === MISCELLANEOUS ===
          ignore_repeated_errors = Off
          ignore_repeated_source = Off
          report_memleaks = On
          track_errors = Off
          html_errors = Off
          docref_root = ""
          docref_ext = .html
          error_prepend_string = ""
          error_append_string = ""
          
          ; === ASSERTION CONFIGURATION ===
          assert.active = 1
          assert.warning = 1
          assert.bail = 0
          assert.callback = 0
          assert.quiet_eval = 0
        '';
      };
    };
  };

  # Create PHP-FPM log directory
  systemd.tmpfiles.rules = [
    "d /var/log/php-fpm 0755 nginx nginx -"
  ];

  # PHP-FPM service optimization
  systemd.services.phpfpm-www = {
    serviceConfig = {
      # Process management
      KillMode = "mixed";
      KillSignal = "SIGINT";
      TimeoutStopSec = "5s";
      
      # Security
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/www" "/var/log" "/tmp" "/var/lib/php/sessions" ];
      
      # Resource limits
      LimitNOFILE = "65536";
      LimitNPROC = "4096";
    };
    
    # Restart on failure
    unitConfig = {
      StartLimitBurst = "3";
      StartLimitIntervalSec = "60s";
    };
  };

  # Log rotation for PHP-FPM
  services.logrotate.settings.php-fpm = {
    files = [ "/var/log/php-fpm/*.log" "/var/log/php_errors.log" ];
    frequency = "daily";
    rotate = 14;
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    sharedscripts = true;
    postrotate = "systemctl reload phpfpm-www";
  };
}
