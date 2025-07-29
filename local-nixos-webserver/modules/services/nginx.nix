# Nginx Web Server Configuration Module
# NixOS 25.05 Compatible
# High-performance web server with FastCGI caching

{ config, pkgs, ... }:

{
  # Nginx web server configuration
  services.nginx = {
    enable = true;
    user = "nginx";
    group = "nginx";
    
    # Performance optimization
    appendConfig = ''
      worker_processes auto;
      worker_connections 1024;
      worker_rlimit_nofile 2048;
      
      # Event handling optimization
      events {
        use epoll;
        multi_accept on;
      }
    '';

    # Global HTTP configuration with caching and security
    commonHttpConfig = ''
      # Basic performance settings
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
      keepalive_timeout 65;
      keepalive_requests 100;
      types_hash_max_size 2048;
      client_max_body_size 64M;
      client_body_timeout 12;
      client_header_timeout 12;
      send_timeout 10;
      
      # Buffer settings
      client_body_buffer_size 10K;
      client_header_buffer_size 1k;
      large_client_header_buffers 2 1k;
      
      # Gzip compression
      gzip on;
      gzip_vary on;
      gzip_min_length 1024;
      gzip_comp_level 6;
      gzip_proxied any;
      gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
      
      # FastCGI caching configuration
      fastcgi_cache_path /var/cache/nginx/fastcgi 
        levels=1:2 
        keys_zone=PHPFPM:100m 
        inactive=60m 
        max_size=1g;
      fastcgi_cache_key "$scheme$request_method$host$request_uri";
      fastcgi_cache_use_stale error timeout invalid_header http_500 http_503;
      fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
      fastcgi_cache_valid 200 301 302 30m;
      fastcgi_cache_valid 404 1m;
      
      # Security headers
      add_header X-Frame-Options DENY always;
      add_header X-Content-Type-Options nosniff always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
      
      # Hide nginx version
      server_tokens off;
      
      # Rate limiting
      limit_req_zone $binary_remote_addr zone=login:10m rate=10r/m;
      limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
      
      # Cache bypass conditions
      set $skip_cache 0;
      
      # Skip cache for POST requests
      if ($request_method = POST) {
        set $skip_cache 1;
      }
      
      # Skip cache for URLs with query parameters
      if ($query_string != "") {
        set $skip_cache 1;
      }
      
      # Skip cache for admin areas
      if ($request_uri ~* "/admin|/dashboard|/wp-admin|/phpmyadmin") {
        set $skip_cache 1;
      }
      
      # Skip cache for logged in users (if using cookies)
      if ($http_cookie ~* "logged_in|wordpress_logged_in") {
        set $skip_cache 1;
      }
    '';

    # Virtual hosts configuration
    virtualHosts = {
      # Dashboard - Web Server Management Interface
      "dashboard.local" = {
        root = "/var/www/dashboard";
        index = "index.php index.html";
        
        extraConfig = ''
          # Rate limiting for admin interface
          limit_req zone=login burst=5 nodelay;
        '';
        
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
          };
          
          "~ \\.php$" = {
            extraConfig = ''
              fastcgi_pass unix:${config.services.phpfpm.pools.www.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include ${pkgs.nginx}/conf/fastcgi_params;
              
              # Selective caching for dashboard
              fastcgi_cache PHPFPM;
              fastcgi_cache_valid 200 10m;
              fastcgi_cache_bypass $skip_cache;
              fastcgi_no_cache $skip_cache;
              add_header X-FastCGI-Cache $upstream_cache_status always;
            '';
          };
          
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
          
          "~ /\\.(git|svn)" = {
            extraConfig = "deny all;";
          };
        };
      };

      # phpMyAdmin - Database Administration
      "phpmyadmin.local" = {
        root = "/var/www/phpmyadmin";
        index = "index.php";
        
        extraConfig = ''
          # Enhanced security for phpMyAdmin
          limit_req zone=login burst=3 nodelay;
          
          # Additional security headers
          add_header X-Robots-Tag "noindex, nofollow" always;
        '';
        
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
          };
          
          "~ \\.php$" = {
            extraConfig = ''
              fastcgi_pass unix:${config.services.phpfpm.pools.www.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include ${pkgs.nginx}/conf/fastcgi_params;
              
              # No caching for phpMyAdmin
              fastcgi_cache_bypass 1;
              fastcgi_no_cache 1;
            '';
          };
          
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
          
          # Block access to sensitive phpMyAdmin files
          "~ /(libraries|setup/frames|setup/libs)" = {
            extraConfig = "deny all;";
          };
        };
      };

      # Sample Site 1 - E-commerce Demo
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
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include ${pkgs.nginx}/conf/fastcgi_params;
              
              # Aggressive caching for sample sites
              fastcgi_cache PHPFPM;
              fastcgi_cache_valid 200 30m;
              fastcgi_cache_valid 404 1m;
              fastcgi_cache_bypass $skip_cache;
              fastcgi_no_cache $skip_cache;
              add_header X-FastCGI-Cache $upstream_cache_status always;
            '';
          };
          
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
          
          # Static file caching
          "~* \\.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$" = {
            extraConfig = ''
              expires 1y;
              add_header Cache-Control "public, immutable";
              access_log off;
            '';
          };
        };
      };

      # Sample Site 2 - Blog Demo
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
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include ${pkgs.nginx}/conf/fastcgi_params;
              
              # Blog-optimized caching
              fastcgi_cache PHPFPM;
              fastcgi_cache_valid 200 15m;
              fastcgi_cache_bypass $skip_cache;
              fastcgi_no_cache $skip_cache;
              add_header X-FastCGI-Cache $upstream_cache_status always;
            '';
          };
          
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
          
          # Static file caching
          "~* \\.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$" = {
            extraConfig = ''
              expires 6M;
              add_header Cache-Control "public";
              access_log off;
            '';
          };
        };
      };

      # Sample Site 3 - Portfolio Demo
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
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include ${pkgs.nginx}/conf/fastcgi_params;
              
              # Portfolio caching
              fastcgi_cache PHPFPM;
              fastcgi_cache_valid 200 1h;
              fastcgi_cache_bypass $skip_cache;
              fastcgi_no_cache $skip_cache;
              add_header X-FastCGI-Cache $upstream_cache_status always;
            '';
          };
          
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
          
          # Static file caching with longer expiry for portfolio
          "~* \\.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$" = {
            extraConfig = ''
              expires 1y;
              add_header Cache-Control "public, immutable";
              access_log off;
            '';
          };
        };
      };

      # Caching Scripts - Standalone Cache Management System
      "caching-scripts.local" = {
        root = "/var/www/caching-scripts";
        index = "index.php";
        
        extraConfig = ''
          # Security for cache management interface
          limit_req zone=login burst=5 nodelay;
        '';
        
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
          };
          
          "~ \\.php$" = {
            extraConfig = ''
              fastcgi_pass unix:${config.services.phpfpm.pools.www.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include ${pkgs.nginx}/conf/fastcgi_params;
              
              # No caching for cache management interface
              fastcgi_cache_bypass 1;
              fastcgi_no_cache 1;
            '';
          };
          
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
          
          # Protect API endpoints
          "~ ^/api/" = {
            extraConfig = ''
              limit_req zone=api burst=10 nodelay;
            '';
          };
        };
      };
    };
  };

  # Log rotation for nginx
  services.logrotate.settings.nginx = {
    files = [ "/var/log/nginx/*.log" ];
    frequency = "daily";
    rotate = 30;
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    sharedscripts = true;
    postrotate = "systemctl reload nginx";
  };
}
