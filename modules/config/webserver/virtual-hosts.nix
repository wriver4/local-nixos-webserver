# Webserver Virtual Hosts Configuration
# This module defines all virtual hosts for the webserver

{ config, pkgs, lib, ... }:

{
  # Virtual hosts configuration - merge with any existing virtual hosts
  services.nginx.virtualHosts = lib.mkMerge [
    {
      # Dashboard
      "dashboard.local" = {
        root = "/var/www/dashboard";
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
            index = "index.php index.html";
          };
          "~ \\.php$" = {
            extraConfig = ''
              fastcgi_pass unix:${config.services.phpfpm.pools.webserver.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include ${pkgs.nginx}/conf/fastcgi_params;
            '';
          };
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
        };
      };

      # phpMyAdmin
      "phpmyadmin.local" = {
        root = "/var/www/phpmyadmin";
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
            index = "index.php";
          };
          "~ \\.php$" = {
            extraConfig = ''
              fastcgi_pass unix:${config.services.phpfpm.pools.webserver.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include ${pkgs.nginx}/conf/fastcgi_params;
            '';
          };
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
        };
      };

      # Sample Domain 1 - E-commerce Demo
      "sample1.local" = {
        root = "/var/www/sample1";
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
            index = "index.php index.html";
          };
          "~ \\.php$" = {
            extraConfig = ''
              fastcgi_pass unix:${config.services.phpfpm.pools.webserver.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include ${pkgs.nginx}/conf/fastcgi_params;
            '';
          };
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
        };
      };

      # Sample Domain 2 - Blog/News Demo
      "sample2.local" = {
        root = "/var/www/sample2";
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
            index = "index.php index.html";
          };
          "~ \\.php$" = {
            extraConfig = ''
              fastcgi_pass unix:${config.services.phpfpm.pools.webserver.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include ${pkgs.nginx}/conf/fastcgi_params;
            '';
          };
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
        };
      };

      # Sample Domain 3 - Portfolio/Agency Demo
      "sample3.local" = {
        root = "/var/www/sample3";
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
            index = "index.php index.html";
          };
          "~ \\.php$" = {
            extraConfig = ''
              fastcgi_pass unix:${config.services.phpfpm.pools.webserver.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include ${pkgs.nginx}/conf/fastcgi_params;
            '';
          };
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
        };
      };
    }
  ];
}