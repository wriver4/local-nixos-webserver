# Webserver Nginx Service Module
# This module provides nginx configuration for the webserver
# Uses lib.mkDefault to avoid conflicts with existing nginx configurations

{ config, pkgs, lib, ... }:

{
  # Nginx configuration with conflict resolution
  services.nginx = {
    enable = lib.mkDefault true;
    user = lib.mkDefault "nginx";
    group = lib.mkDefault "nginx";
    
    # Global configuration - use mkDefault to allow overrides
    appendConfig = lib.mkDefault ''
      worker_processes auto;
      worker_connections 1024;
    '';

    # Common HTTP configuration for PHP
    commonHttpConfig = lib.mkDefault ''
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
  };

  # Ensure nginx user and group exist
  users.users.nginx = lib.mkIf (!config.users.users ? nginx) {
    isSystemUser = true;
    group = "nginx";
    description = "Nginx web server user";
  };

  users.groups.nginx = lib.mkIf (!config.users.groups ? nginx) {};

  # Open HTTP and HTTPS ports
  networking.firewall.allowedTCPPorts = lib.mkAfter [ 80 443 ];
}