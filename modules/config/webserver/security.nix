# Webserver Security Configuration
# This module provides security hardening for the webserver

{ config, pkgs, lib, ... }:

{
  # Additional nginx security configuration
  services.nginx = {
    # Security-focused nginx configuration
    appendHttpConfig = lib.mkAfter ''
      # Hide nginx version
      server_tokens off;
      
      # Prevent clickjacking
      add_header X-Frame-Options SAMEORIGIN always;
      
      # Prevent MIME type sniffing
      add_header X-Content-Type-Options nosniff always;
      
      # Enable XSS protection
      add_header X-XSS-Protection "1; mode=block" always;
      
      # Referrer policy
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      
      # Content Security Policy (basic)
      add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:;" always;
      
      # Rate limiting
      limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
      limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
      
      # Hide sensitive files
      location ~ /\.(ht|git|svn) {
        deny all;
        return 404;
      }
      
      location ~ /\.env {
        deny all;
        return 404;
      }
      
      location ~ /(config|logs|temp|vendor)/ {
        deny all;
        return 404;
      }
    '';
  };

  # PHP security configuration
  services.phpfpm.pools.webserver.phpPackage = pkgs.php.buildEnv {
    extraConfig = lib.mkAfter ''
      # Additional security settings
      allow_url_fopen = Off
      allow_url_include = Off
      
      # Disable dangerous functions
      disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source
      
      # Session security
      session.cookie_httponly = On
      session.cookie_secure = Off
      session.use_strict_mode = On
      session.cookie_samesite = "Strict"
      
      # File upload security
      file_uploads = On
      upload_tmp_dir = /tmp
      max_file_uploads = 20
    '';
  };

  # Firewall security - only allow necessary ports
  networking.firewall = {
    enable = lib.mkDefault true;
    allowPing = lib.mkDefault false;
    
    # Log dropped packets for security monitoring
    logRefusedConnections = lib.mkDefault true;
    logRefusedPackets = lib.mkDefault false;
  };

  # System security hardening
  security = {
    # Hide process information from other users
    hideProcessInformation = lib.mkDefault true;
    
    # Prevent core dumps
    allowUserNamespaces = lib.mkDefault false;
  };

  # Fail2ban configuration for additional protection
  services.fail2ban = lib.mkIf (config.services.fail2ban.enable or false) {
    jails = {
      nginx-http-auth = {
        enabled = true;
        filter = "nginx-http-auth";
        logpath = "/var/log/nginx/error.log";
        maxretry = 3;
        bantime = 3600;
      };
      
      nginx-limit-req = {
        enabled = true;
        filter = "nginx-limit-req";
        logpath = "/var/log/nginx/error.log";
        maxretry = 5;
        bantime = 1800;
      };
    };
  };
}