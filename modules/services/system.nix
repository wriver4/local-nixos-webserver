# System Configuration Module
# NixOS 25.05 Compatible
# System activation scripts, directories, and optimization

{ config, pkgs, ... }:

{
  # System activation scripts for web server setup
  system.activationScripts.webserver-setup = {
    text = ''
      echo "Setting up web server directories and permissions..."
      
      # Create web directories with proper structure
      mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3,caching-scripts}
      mkdir -p /var/www/caching-scripts/{api,scripts}
      
      # Create cache directories
      mkdir -p /var/cache/nginx/{fastcgi,proxy,client_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp}
      
      # Create log directories
      mkdir -p /var/log/{nginx,php-fpm,mysql,redis,webserver}
      
      # Create backup directories
      mkdir -p /var/backups/{mysql,redis,web,config}
      
      # Create session and temporary directories
      mkdir -p /var/lib/php/sessions
      mkdir -p /tmp/{nginx,php}
      
      # Set ownership for web directories
      chown -R nginx:www-data /var/www
      chown -R nginx:nginx /var/cache/nginx
      chown -R nginx:nginx /var/log/php-fpm
      chown -R mysql:mysql /var/log/mysql
      chown -R redis:redis /var/log/redis
      chown -R nginx:nginx /var/lib/php/sessions
      chown -R nginx:nginx /tmp/nginx
      chown -R nginx:nginx /tmp/php
      chown -R backup:backup /var/backups
      
      # Set permissions
      chmod -R 755 /var/www
      chmod -R 755 /var/cache/nginx
      chmod -R 755 /var/log/nginx
      chmod -R 755 /var/log/php-fpm
      chmod -R 755 /var/log/mysql
      chmod -R 755 /var/log/redis
      chmod -R 755 /var/lib/php/sessions
      chmod -R 755 /tmp/nginx
      chmod -R 755 /tmp/php
      chmod -R 755 /var/backups
      
      # Create log files with proper permissions
      touch /var/log/php_errors.log
      touch /var/log/webserver/access.log
      touch /var/log/webserver/error.log
      touch /var/log/webserver/performance.log
      
      chown nginx:nginx /var/log/php_errors.log
      chown nginx:nginx /var/log/webserver/*.log
      chmod 644 /var/log/php_errors.log
      chmod 644 /var/log/webserver/*.log
      
      # Create configuration backup directory
      mkdir -p /etc/nixos/webserver-backups
      chmod 755 /etc/nixos/webserver-backups
      
      # Create helper script directories
      mkdir -p /usr/local/bin
      chmod 755 /usr/local/bin
      
      echo "Web server setup completed successfully"
    '';
    deps = [ ];
  };

  # System optimization and tuning
  boot.kernel.sysctl = {
    # File system optimization
    "fs.file-max" = 2097152;
    "fs.nr_open" = 1048576;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 256;
    
    # Memory management optimization
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_expire_centisecs" = 3000;
    "vm.dirty_writeback_centisecs" = 500;
    "vm.vfs_cache_pressure" = 50;
    "vm.min_free_kbytes" = 65536;
    
    # Process and thread limits
    "kernel.pid_max" = 4194304;
    "kernel.threads-max" = 2097152;
    
    # Shared memory optimization
    "kernel.shmmax" = 268435456;
    "kernel.shmall" = 268435456;
    "kernel.shmmni" = 4096;
    
    # Semaphore limits
    "kernel.sem" = "250 32000 100 128";
    
    # Message queue limits
    "kernel.msgmnb" = 65536;
    "kernel.msgmax" = 65536;
    "kernel.msgmni" = 2048;
    
    # Core dump handling
    "kernel.core_uses_pid" = 1;
    "kernel.core_pattern" = "/var/crash/core.%e.%p.%h.%t";
    
    # Security enhancements
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = 1;
    
    # Performance monitoring
    "kernel.perf_event_paranoid" = 2;
    "kernel.perf_event_max_sample_rate" = 100000;
  };

  # System-wide environment variables
  environment.variables = {
    # PHP configuration
    PHP_INI_SCAN_DIR = "/etc/php.d";
    
    # Web server paths
    WEBROOT = "/var/www";
    NGINX_CONF = "/etc/nginx";
    
    # Cache directories
    NGINX_CACHE_DIR = "/var/cache/nginx";
    PHP_SESSION_DIR = "/var/lib/php/sessions";
    
    # Log directories
    WEB_LOG_DIR = "/var/log/webserver";
    
    # Backup directory
    BACKUP_DIR = "/var/backups";
    
    # Temporary directories
    TMPDIR = "/tmp";
    TMP = "/tmp";
    TEMP = "/tmp";
  };

  # System-wide shell aliases for administration
  environment.shellAliases = {
    # Service management
    "nginx-restart" = "sudo systemctl restart nginx";
    "nginx-reload" = "sudo systemctl reload nginx";
    "nginx-status" = "sudo systemctl status nginx";
    "nginx-logs" = "sudo tail -f /var/log/nginx/error.log";
    
    "php-restart" = "sudo systemctl restart phpfpm-www";
    "php-status" = "sudo systemctl status phpfpm-www";
    "php-logs" = "sudo tail -f /var/log/php-fpm/www.log";
    
    "mysql-restart" = "sudo systemctl restart mysql";
    "mysql-status" = "sudo systemctl status mysql";
    "mysql-logs" = "sudo tail -f /var/log/mysql/error.log";
    
    "redis-restart" = "sudo systemctl restart redis-main";
    "redis-status" = "sudo systemctl status redis-main";
    "redis-logs" = "sudo tail -f /var/log/redis/redis.log";
    
    # System management
    "rebuild-web" = "sudo nixos-rebuild switch";
    "web-status" = "sudo systemctl status nginx phpfpm-www mysql redis-main";
    
    # Log viewing
    "web-logs" = "sudo tail -f /var/log/nginx/access.log";
    "error-logs" = "sudo tail -f /var/log/nginx/error.log /var/log/php_errors.log";
    
    # Directory shortcuts
    "cdweb" = "cd /var/www";
    "cdlogs" = "cd /var/log";
    "cdnginx" = "cd /etc/nginx";
    
    # Performance monitoring
    "web-performance" = "sudo htop -p $(pgrep -d, 'nginx|php-fpm|mysql|redis')";
    "web-connections" = "sudo netstat -tulpn | grep -E ':(80|443|3306|6379)'";
  };

  # System monitoring and maintenance services
  systemd.services.system-monitor = {
    description = "System Performance Monitor for Web Server";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = pkgs.writeShellScript "system-monitor" ''
        #!/usr/bin/env bash
        LOG_FILE="/var/log/webserver/system-performance.log"
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        
        # System load
        LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//')
        
        # Memory usage
        MEMORY_INFO=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
        
        # Disk usage
        DISK_USAGE=$(df -h / | awk 'NR==2{print $5}')
        
        # CPU usage
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
        
        # Network connections
        CONNECTIONS=$(netstat -an | grep -E ':(80|443|3306|6379)' | wc -l)
        
        # Process counts
        NGINX_PROCS=$(pgrep nginx | wc -l)
        PHP_PROCS=$(pgrep php-fpm | wc -l)
        MYSQL_PROCS=$(pgrep mysql | wc -l)
        REDIS_PROCS=$(pgrep redis | wc -l)
        
        # Log the information
        echo "[$TIMESTAMP] Load: $LOAD_AVG, Memory: $MEMORY_INFO, Disk: $DISK_USAGE, CPU: $CPU_USAGE%, Connections: $CONNECTIONS, Processes: nginx=$NGINX_PROCS php=$PHP_PROCS mysql=$MYSQL_PROCS redis=$REDIS_PROCS" >> "$LOG_FILE"
        
        # Check for issues
        LOAD_1MIN=$(echo "$LOAD_AVG" | awk -F',' '{print $1}' | sed 's/^[ \t]*//')
        if (( $(echo "$LOAD_1MIN > 4.0" | bc -l) )); then
          echo "[$TIMESTAMP] WARNING: High system load: $LOAD_1MIN" >> "$LOG_FILE"
        fi
        
        MEMORY_PERCENT=$(echo "$MEMORY_INFO" | sed 's/%//')
        if (( $(echo "$MEMORY_PERCENT > 90" | bc -l) )); then
          echo "[$TIMESTAMP] WARNING: High memory usage: $MEMORY_INFO" >> "$LOG_FILE"
        fi
        
        # Cleanup old logs (keep last 2000 lines)
        tail -n 2000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
      '';
    };
  };

  # Schedule system monitoring every 5 minutes
  systemd.timers.system-monitor = {
    description = "System Performance Monitoring";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
  };

  # System cleanup service
  systemd.services.system-cleanup = {
    description = "System Cleanup and Maintenance";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = pkgs.writeShellScript "system-cleanup" ''
        #!/usr/bin/env bash
        
        echo "Starting system cleanup..."
        
        # Clean temporary files
        find /tmp -type f -atime +7 -delete 2>/dev/null || true
        find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
        
        # Clean old log files
        find /var/log -name "*.log.*" -mtime +30 -delete 2>/dev/null || true
        find /var/log -name "*.gz" -mtime +30 -delete 2>/dev/null || true
        
        # Clean nginx cache (old files)
        find /var/cache/nginx -type f -atime +7 -delete 2>/dev/null || true
        
        # Clean PHP sessions
        find /var/lib/php/sessions -type f -mtime +7 -delete 2>/dev/null || true
        
        # Clean old backups (keep last 30 days)
        find /var/backups -name "*.gz" -mtime +30 -delete 2>/dev/null || true
        find /var/backups -name "*.sql" -mtime +7 -delete 2>/dev/null || true
        
        # Clean package cache
        nix-collect-garbage -d > /dev/null 2>&1 || true
        
        # Update locate database
        updatedb 2>/dev/null || true
        
        echo "System cleanup completed at $(date)"
      '';
    };
  };

  # Schedule daily system cleanup
  systemd.timers.system-cleanup = {
    description = "Daily System Cleanup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
  };

  # System health check service
  systemd.services.health-check = {
    description = "Web Server Health Check";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = pkgs.writeShellScript "health-check" ''
        #!/usr/bin/env bash
        LOG_FILE="/var/log/webserver/health-check.log"
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Check service status
        NGINX_STATUS=$(systemctl is-active nginx)
        PHP_STATUS=$(systemctl is-active phpfpm-www)
        MYSQL_STATUS=$(systemctl is-active mysql)
        REDIS_STATUS=$(systemctl is-active redis-main)
        
        # Check port availability
        NGINX_PORT=$(netstat -tlnp | grep :80 | wc -l)
        MYSQL_PORT=$(netstat -tlnp | grep :3306 | wc -l)
        REDIS_PORT=$(netstat -tlnp | grep :6379 | wc -l)
        
        # Log health status
        echo "[$TIMESTAMP] Services: nginx=$NGINX_STATUS php=$PHP_STATUS mysql=$MYSQL_STATUS redis=$REDIS_STATUS" >> "$LOG_FILE"
        echo "[$TIMESTAMP] Ports: nginx=$NGINX_PORT mysql=$MYSQL_PORT redis=$REDIS_PORT" >> "$LOG_FILE"
        
        # Check for issues and restart if needed
        if [ "$NGINX_STATUS" != "active" ]; then
          echo "[$TIMESTAMP] ERROR: Nginx is not active, attempting restart..." >> "$LOG_FILE"
          systemctl restart nginx
        fi
        
        if [ "$PHP_STATUS" != "active" ]; then
          echo "[$TIMESTAMP] ERROR: PHP-FPM is not active, attempting restart..." >> "$LOG_FILE"
          systemctl restart phpfpm-www
        fi
        
        if [ "$MYSQL_STATUS" != "active" ]; then
          echo "[$TIMESTAMP] ERROR: MySQL is not active, attempting restart..." >> "$LOG_FILE"
          systemctl restart mysql
        fi
        
        if [ "$REDIS_STATUS" != "active" ]; then
          echo "[$TIMESTAMP] ERROR: Redis is not active, attempting restart..." >> "$LOG_FILE"
          systemctl restart redis-main
        fi
        
        # Cleanup old logs (keep last 1000 lines)
        tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
      '';
    };
  };

  # Schedule health checks every 10 minutes
  systemd.timers.health-check = {
    description = "Web Server Health Check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/10";
      Persistent = true;
    };
  };

  # Create crash dump directory
  systemd.tmpfiles.rules = [
    "d /var/crash 0755 root root -"
    "d /var/log/webserver 0755 root root -"
  ];
}
