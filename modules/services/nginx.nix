# Enhanced Nginx Service Module
# This module provides nginx configuration that works with existing setups
# Uses lib.mkDefault extensively to avoid conflicts

{ config, pkgs, lib, ... }:

{
  # Nginx service configuration with conflict resolution
  services.nginx = {
    enable = lib.mkDefault true;
    user = lib.mkDefault "nginx";
    group = lib.mkDefault "nginx";
    
    # Global nginx configuration
    appendConfig = lib.mkDefault ''
      worker_processes auto;
      worker_connections 1024;
      worker_rlimit_nofile 65535;
      
      events {
        use epoll;
        multi_accept on;
      }
    '';

    # Common HTTP configuration
    commonHttpConfig = lib.mkDefault ''
      # Basic optimization
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
      keepalive_timeout 65;
      types_hash_max_size 2048;
      
      # Buffer optimization
      client_body_buffer_size 128k;
      client_header_buffer_size 1k;
      large_client_header_buffers 4 4k;
      
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
      
      # Security headers (basic)
      server_tokens off;
      add_header X-Frame-Options SAMEORIGIN always;
      add_header X-Content-Type-Options nosniff always;
      add_header X-XSS-Protection "1; mode=block" always;
      
      # Rate limiting zones
      limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
      limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
      
      # File caching
      open_file_cache max=200000 inactive=20s;
      open_file_cache_valid 30s;
      open_file_cache_min_uses 2;
      open_file_cache_errors on;
    '';
  };

  # Ensure nginx user and group exist
  users.users.nginx = lib.mkIf (!config.users.users ? nginx) {
    isSystemUser = true;
    group = "nginx";
    description = "Nginx web server user";
    home = "/var/lib/nginx";
    createHome = true;
  };

  users.groups.nginx = lib.mkIf (!config.users.groups ? nginx) {};

  # Systemd service optimization
  systemd.services.nginx.serviceConfig = lib.mkMerge [
    {
      LimitNOFILE = lib.mkDefault 65535;
      LimitNPROC = lib.mkDefault 4096;
    }
  ];

  # Open HTTP and HTTPS ports
  networking.firewall.allowedTCPPorts = lib.mkAfter [ 80 443 ];

  # Create nginx directories
  system.activationScripts.nginx-dirs = ''
    mkdir -p /var/lib/nginx
    mkdir -p /var/log/nginx
    chown -R nginx:nginx /var/lib/nginx
    chown -R nginx:nginx /var/log/nginx
  '';
}