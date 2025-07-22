# Webserver Performance Optimization Configuration
# This module provides performance tuning for the webserver stack

{ config, pkgs, lib, ... }:

{
  # Nginx performance optimization
  services.nginx = {
    # Performance-focused nginx configuration
    appendHttpConfig = lib.mkAfter ''
      # Worker process optimization
      worker_rlimit_nofile 65535;
      
      # Connection optimization
      keepalive_requests 1000;
      keepalive_timeout 65;
      
      # Buffer optimization
      client_body_buffer_size 128k;
      client_header_buffer_size 1k;
      large_client_header_buffers 4 4k;
      output_buffers 1 32k;
      postpone_output 1460;
      
      # Compression optimization
      gzip_comp_level 6;
      gzip_min_length 1000;
      gzip_proxied any;
      gzip_vary on;
      gzip_types
        application/atom+xml
        application/geo+json
        application/javascript
        application/x-javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rdf+xml
        application/rss+xml
        application/xhtml+xml
        application/xml
        font/eot
        font/otf
        font/ttf
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;
      
      # Caching optimization
      open_file_cache max=200000 inactive=20s;
      open_file_cache_valid 30s;
      open_file_cache_min_uses 2;
      open_file_cache_errors on;
      
      # TCP optimization
      tcp_nopush on;
      tcp_nodelay on;
      
      # Sendfile optimization
      sendfile on;
      sendfile_max_chunk 1m;
    '';

    # Per-worker configuration
    appendConfig = lib.mkAfter ''
      worker_processes auto;
      worker_connections 4096;
      worker_rlimit_nofile 65535;
      
      # Event handling optimization
      events {
        use epoll;
        multi_accept on;
      }
    '';
  };

  # PHP-FPM performance optimization
  services.phpfpm.pools.webserver = {
    settings = lib.mkMerge [
      {
        # Process management optimization
        "pm" = "dynamic";
        "pm.max_children" = 100;
        "pm.start_servers" = 20;
        "pm.min_spare_servers" = 10;
        "pm.max_spare_servers" = 30;
        "pm.max_requests" = 1000;
        
        # Process optimization
        "pm.process_idle_timeout" = "10s";
        "pm.max_spawn_rate" = 32;
        
        # Logging optimization
        "pm.status_path" = "/status";
        "ping.path" = "/ping";
        "ping.response" = "pong";
        
        # Request optimization
        "request_terminate_timeout" = "300s";
        "request_slowlog_timeout" = "10s";
        "slowlog" = "/var/log/php-fpm-slow.log";
      }
    ];

    phpPackage = pkgs.php.buildEnv {
      extraConfig = lib.mkAfter ''
        # Performance optimization
        realpath_cache_size = 4096k
        realpath_cache_ttl = 600
        
        # OPcache optimization
        opcache.enable = 1
        opcache.memory_consumption = 256
        opcache.interned_strings_buffer = 16
        opcache.max_accelerated_files = 10000
        opcache.revalidate_freq = 2
        opcache.fast_shutdown = 1
        opcache.enable_cli = 1
        opcache.save_comments = 0
        opcache.validate_timestamps = 1
        
        # JIT optimization (PHP 8.4)
        opcache.jit_buffer_size = 128M
        opcache.jit = tracing
        
        # Memory optimization
        memory_limit = 512M
        max_execution_time = 300
        max_input_time = 300
        max_input_vars = 5000
        
        # File handling optimization
        upload_max_filesize = 128M
        post_max_size = 128M
        max_file_uploads = 50
        
        # Session optimization
        session.gc_maxlifetime = 3600
        session.gc_probability = 1
        session.gc_divisor = 1000
      '';
    };
  };

  # MySQL performance optimization
  services.mysql = {
    settings = lib.mkMerge [
      {
        mysqld = {
          # InnoDB optimization
          innodb_buffer_pool_size = "256M";
          innodb_log_file_size = "64M";
          innodb_flush_log_at_trx_commit = "2";
          innodb_flush_method = "O_DIRECT";
          
          # Query cache optimization
          query_cache_type = "1";
          query_cache_size = "32M";
          query_cache_limit = "2M";
          
          # Connection optimization
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
          
          # Logging optimization
          slow_query_log = "1";
          slow_query_log_file = "/var/log/mysql/slow.log";
          long_query_time = "2";
        };
      }
    ];
  };

  # System-level optimizations
  boot.kernel.sysctl = {
    # Network optimization
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    "net.ipv4.tcp_congestion_control" = "bbr";
    
    # File system optimization
    "fs.file-max" = 2097152;
    "fs.nr_open" = 1048576;
    
    # Virtual memory optimization
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
  };

  # Systemd service optimization
  systemd.services.nginx.serviceConfig = {
    LimitNOFILE = 65535;
    LimitNPROC = 4096;
  };

  systemd.services.phpfpm-webserver.serviceConfig = {
    LimitNOFILE = 65535;
    LimitNPROC = 4096;
  };

  # Log rotation for performance logs
  services.logrotate.settings = {
    "/var/log/php-fpm-slow.log" = {
      frequency = "daily";
      rotate = 7;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      postrotate = "systemctl reload phpfpm-webserver";
    };
  };
}