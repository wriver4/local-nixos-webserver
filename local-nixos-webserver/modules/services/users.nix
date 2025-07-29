# Users and Groups Configuration Module
# NixOS 25.05 Compatible
# Web server users, groups, and permissions

{ config, pkgs, ... }:

{
  # Nginx user and group configuration
  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
    home = "/var/lib/nginx";
    createHome = true;
    description = "Nginx web server user";
    shell = pkgs.shadow;
    
    # Additional groups for file access
    extraGroups = [ "www-data" ];
  };

  users.groups.nginx = {
    gid = 33; # Standard nginx GID
  };

  # Web data group for shared file access
  users.groups.www-data = {
    gid = 1000;
    members = [ "nginx" ];
  };

  # Redis user configuration (if not automatically created)
  users.users.redis = {
    isSystemUser = true;
    group = "redis";
    home = "/var/lib/redis";
    createHome = true;
    description = "Redis server user";
    shell = pkgs.shadow;
  };

  users.groups.redis = {
    gid = 999;
  };

  # MySQL user configuration (if not automatically created)
  users.users.mysql = {
    isSystemUser = true;
    group = "mysql";
    home = "/var/lib/mysql";
    createHome = true;
    description = "MySQL server user";
    shell = pkgs.shadow;
  };

  users.groups.mysql = {
    gid = 998;
  };

  # Web administrator user (optional - for manual management)
  users.users.webadmin = {
    isNormalUser = true;
    description = "Web Server Administrator";
    home = "/home/webadmin";
    createHome = true;
    shell = pkgs.bash;
    
    # Groups for web server management
    extraGroups = [ 
      "wheel"      # sudo access
      "nginx"      # nginx access
      "www-data"   # web data access
      "mysql"      # database access
      "redis"      # redis access
      "systemd-journal" # log access
    ];
    
    # SSH keys (add your public key here)
    openssh.authorizedKeys.keys = [
      # "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... your-public-key-here"
    ];
    
    # Initial password (change after first login)
    initialPassword = "webadmin123";
    
    # Force password change on first login
    hashedPasswordFile = null;
  };

  # Backup user for automated backups
  users.users.backup = {
    isSystemUser = true;
    group = "backup";
    home = "/var/lib/backup";
    createHome = true;
    description = "Backup service user";
    shell = pkgs.bash;
    
    # Groups for backup access
    extraGroups = [ 
      "mysql"
      "redis"
      "nginx"
      "www-data"
    ];
  };

  users.groups.backup = {
    gid = 997;
  };

  # Log user for log management
  users.users.loguser = {
    isSystemUser = true;
    group = "log";
    home = "/var/lib/loguser";
    createHome = true;
    description = "Log management user";
    shell = pkgs.shadow;
    
    extraGroups = [ "systemd-journal" ];
  };

  users.groups.log = {
    gid = 996;
  };

  # Security configuration
  security.sudo = {
    enable = true;
    
    # Sudo rules for web administration
    extraRules = [
      {
        users = [ "webadmin" ];
        commands = [
          {
            command = "${pkgs.systemd}/bin/systemctl restart nginx";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.systemd}/bin/systemctl restart phpfpm-www";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.systemd}/bin/systemctl restart mysql";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.systemd}/bin/systemctl restart redis-main";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/nixos-rebuild switch";
            options = [ "NOPASSWD" ];
          }
        ];
      }
      {
        users = [ "backup" ];
        commands = [
          {
            command = "${pkgs.mariadb}/bin/mysqldump";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.redis}/bin/redis-cli";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };

  # PAM configuration for enhanced security
  security.pam.services = {
    # Nginx PAM configuration (if needed for auth modules)
    nginx = {
      text = ''
        auth required pam_unix.so
        account required pam_unix.so
        session required pam_unix.so
      '';
    };
    
    # Enhanced SSH security
    sshd = {
      failDelay = {
        enable = true;
        delay = 3000000; # 3 seconds
      };
    };
  };

  # User limits configuration
  security.pam.loginLimits = [
    # Nginx user limits
    {
      domain = "nginx";
      type = "soft";
      item = "nofile";
      value = "65536";
    }
    {
      domain = "nginx";
      type = "hard";
      item = "nofile";
      value = "65536";
    }
    {
      domain = "nginx";
      type = "soft";
      item = "nproc";
      value = "4096";
    }
    {
      domain = "nginx";
      type = "hard";
      item = "nproc";
      value = "4096";
    }
    
    # MySQL user limits
    {
      domain = "mysql";
      type = "soft";
      item = "nofile";
      value = "65536";
    }
    {
      domain = "mysql";
      type = "hard";
      item = "nofile";
      value = "65536";
    }
    
    # Redis user limits
    {
      domain = "redis";
      type = "soft";
      item = "nofile";
      value = "65536";
    }
    {
      domain = "redis";
      type = "hard";
      item = "nofile";
      value = "65536";
    }
    
    # Web admin user limits
    {
      domain = "webadmin";
      type = "soft";
      item = "nofile";
      value = "32768";
    }
    {
      domain = "webadmin";
      type = "hard";
      item = "nofile";
      value = "32768";
    }
  ];

  # Home directory permissions
  systemd.tmpfiles.rules = [
    # Nginx directories
    "d /var/lib/nginx 0755 nginx nginx -"
    "d /var/cache/nginx 0755 nginx nginx -"
    "d /var/log/nginx 0755 nginx nginx -"
    
    # Web content directories
    "d /var/www 0755 nginx www-data -"
    "d /var/www/dashboard 0755 nginx www-data -"
    "d /var/www/phpmyadmin 0755 nginx www-data -"
    "d /var/www/sample1 0755 nginx www-data -"
    "d /var/www/sample2 0755 nginx www-data -"
    "d /var/www/sample3 0755 nginx www-data -"
    "d /var/www/caching-scripts 0755 nginx www-data -"
    
    # Log directories
    "d /var/log/php-fpm 0755 nginx nginx -"
    "d /var/log/mysql 0755 mysql mysql -"
    "d /var/log/redis 0755 redis redis -"
    
    # Backup directories
    "d /var/backups 0755 backup backup -"
    "d /var/backups/mysql 0755 backup backup -"
    "d /var/backups/redis 0755 backup backup -"
    "d /var/backups/web 0755 backup backup -"
    
    # Session directories
    "d /var/lib/php/sessions 0755 nginx nginx -"
    
    # Cache directories
    "d /var/cache/nginx/fastcgi 0755 nginx nginx -"
    "d /var/cache/php 0755 nginx nginx -"
    
    # Temporary directories
    "d /tmp/nginx 0755 nginx nginx -"
    "d /tmp/php 0755 nginx nginx -"
  ];

  # User management scripts
  environment.systemPackages = with pkgs; [
    # User management utilities
    shadow
    pwgen
    
    # File permission utilities
    acl
    attr
  ];

  # Automatic user cleanup service
  systemd.services.user-cleanup = {
    description = "Clean up temporary user files";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = pkgs.writeShellScript "user-cleanup" ''
        #!/usr/bin/env bash
        
        # Clean up old session files
        find /var/lib/php/sessions -type f -mtime +7 -delete 2>/dev/null || true
        
        # Clean up old temporary files
        find /tmp/nginx -type f -mtime +1 -delete 2>/dev/null || true
        find /tmp/php -type f -mtime +1 -delete 2>/dev/null || true
        
        # Clean up old log files (keep last 30 days)
        find /var/log -name "*.log.*" -mtime +30 -delete 2>/dev/null || true
        
        # Clean up old backup files (keep last 30 days)
        find /var/backups -name "*.gz" -mtime +30 -delete 2>/dev/null || true
        
        echo "User cleanup completed at $(date)"
      '';
    };
  };

  # Schedule daily user cleanup
  systemd.timers.user-cleanup = {
    description = "Daily User Cleanup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
