# MySQL/MariaDB Configuration Module
# NixOS 25.05 Compatible
# High-performance database server with optimizations

{ config, pkgs, ... }:

{
  # MariaDB service configuration
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    
    # Database initialization
    initialDatabases = [
      { name = "dashboard_db"; }
      { name = "sample1_db"; }
      { name = "sample2_db"; }
      { name = "sample3_db"; }
      { name = "caching_scripts_db"; }
    ];
    
    # User initialization script
    initialScript = pkgs.writeText "mysql-init.sql" ''
      -- Create web application user
      CREATE USER IF NOT EXISTS 'webuser'@'localhost' IDENTIFIED BY 'webpass123';
      GRANT ALL PRIVILEGES ON dashboard_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample1_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample2_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample3_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON caching_scripts_db.* TO 'webuser'@'localhost';
      
      -- Create phpMyAdmin user with full privileges
      CREATE USER IF NOT EXISTS 'phpmyadmin'@'localhost' IDENTIFIED BY 'pmapass123';
      GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost' WITH GRANT OPTION;
      
      -- Create backup user with read-only access
      CREATE USER IF NOT EXISTS 'backup'@'localhost' IDENTIFIED BY 'backuppass123';
      GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON *.* TO 'backup'@'localhost';
      
      -- Create monitoring user
      CREATE USER IF NOT EXISTS 'monitor'@'localhost' IDENTIFIED BY 'monitorpass123';
      GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'monitor'@'localhost';
      
      FLUSH PRIVILEGES;
      
      -- Create sample tables for demonstration
      USE dashboard_db;
      CREATE TABLE IF NOT EXISTS sites (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        domain VARCHAR(255) NOT NULL UNIQUE,
        status ENUM('active', 'inactive') DEFAULT 'active',
        document_root VARCHAR(500) DEFAULT '/var/www',
        database_name VARCHAR(100),
        ssl_enabled BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_domain (domain),
        INDEX idx_status (status),
        INDEX idx_created (created_at)
      );
      
      CREATE TABLE IF NOT EXISTS logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        site_id INT,
        action VARCHAR(255) NOT NULL,
        details TEXT,
        ip_address VARCHAR(45),
        user_agent TEXT,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE SET NULL,
        INDEX idx_timestamp (timestamp),
        INDEX idx_site_id (site_id),
        INDEX idx_action (action)
      );
      
      CREATE TABLE IF NOT EXISTS cache_stats (
        id INT AUTO_INCREMENT PRIMARY KEY,
        cache_type ENUM('opcache', 'redis', 'nginx') NOT NULL,
        hit_rate DECIMAL(5,2),
        memory_usage BIGINT,
        keys_count INT,
        recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_type_time (cache_type, recorded_at)
      );
      
      -- Insert initial site data
      INSERT IGNORE INTO sites (name, domain, status, database_name) VALUES 
        ('Dashboard', 'dashboard.local', 'active', 'dashboard_db'),
        ('phpMyAdmin', 'phpmyadmin.local', 'active', NULL),
        ('Sample Site 1', 'sample1.local', 'active', 'sample1_db'),
        ('Sample Site 2', 'sample2.local', 'active', 'sample2_db'),
        ('Sample Site 3', 'sample3.local', 'active', 'sample3_db'),
        ('Caching Scripts', 'caching-scripts.local', 'active', 'caching_scripts_db');
    '';
    
    # MariaDB configuration settings
    settings = {
      mysqld = {
        # Basic settings
        bind-address = "127.0.0.1";
        port = 3306;
        socket = "/run/mysqld/mysqld.sock";
        pid-file = "/run/mysqld/mysqld.pid";
        
        # Character set and collation
        character-set-server = "utf8mb4";
        collation-server = "utf8mb4_unicode_ci";
        init-connect = "SET NAMES utf8mb4";
        
        # Storage engine
        default-storage-engine = "InnoDB";
        
        # Connection settings
        max_connections = 200;
        max_user_connections = 100;
        max_connect_errors = 1000;
        connect_timeout = 10;
        wait_timeout = 600;
        interactive_timeout = 600;
        
        # Buffer settings for performance
        innodb_buffer_pool_size = "256M";
        innodb_buffer_pool_instances = 1;
        innodb_log_file_size = "64M";
        innodb_log_buffer_size = "16M";
        innodb_flush_log_at_trx_commit = 2;
        innodb_flush_method = "O_DIRECT";
        
        # Query cache (disabled in MariaDB 10.6+, using other optimizations)
        query_cache_type = 0;
        query_cache_size = 0;
        
        # Thread settings
        thread_cache_size = 16;
        thread_stack = "256K";
        
        # Table settings
        table_open_cache = 2000;
        table_definition_cache = 1400;
        
        # MyISAM settings
        key_buffer_size = "32M";
        myisam_sort_buffer_size = "8M";
        
        # Temporary table settings
        tmp_table_size = "64M";
        max_heap_table_size = "64M";
        
        # Sort and group settings
        sort_buffer_size = "2M";
        read_buffer_size = "128K";
        read_rnd_buffer_size = "256K";
        join_buffer_size = "256K";
        
        # Binary logging (disabled for local development)
        log-bin = "";
        binlog_format = "ROW";
        expire_logs_days = 7;
        max_binlog_size = "100M";
        
        # Error logging
        log-error = "/var/log/mysql/error.log";
        
        # Slow query log
        slow_query_log = 1;
        slow_query_log_file = "/var/log/mysql/slow.log";
        long_query_time = 2;
        log_queries_not_using_indexes = 1;
        
        # General query log (disabled by default for performance)
        general_log = 0;
        general_log_file = "/var/log/mysql/general.log";
        
        # Security settings
        local-infile = 0;
        skip-show-database = "";
        
        # Performance schema
        performance_schema = "ON";
        performance_schema_max_table_instances = 400;
        performance_schema_max_table_handles = 4000;
        
        # InnoDB specific optimizations
        innodb_file_per_table = 1;
        innodb_open_files = 300;
        innodb_io_capacity = 400;
        innodb_read_io_threads = 4;
        innodb_write_io_threads = 4;
        innodb_thread_concurrency = 0;
        innodb_lock_wait_timeout = 120;
        innodb_deadlock_detect = "ON";
        
        # SQL mode for strict data handling
        sql_mode = "STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION";
        
        # Timezone
        default-time-zone = "+00:00";
        
        # Max allowed packet
        max_allowed_packet = "64M";
        
        # Group concat max length
        group_concat_max_len = 4096;
      };
      
      mysql = {
        default-character-set = "utf8mb4";
      };
      
      mysqldump = {
        quick = true;
        quote-names = true;
        max_allowed_packet = "64M";
        default-character-set = "utf8mb4";
      };
    };
  };

  # Create MySQL log directory
  systemd.tmpfiles.rules = [
    "d /var/log/mysql 0755 mysql mysql -"
  ];

  # MySQL service optimization
  systemd.services.mysql = {
    serviceConfig = {
      # Process management
      TimeoutStartSec = "300s";
      TimeoutStopSec = "300s";
      
      # Security
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/mysql" "/var/log/mysql" "/run/mysqld" ];
      
      # Resource limits
      LimitNOFILE = "65536";
      LimitNPROC = "4096";
      LimitMEMLOCK = "infinity";
    };
    
    # Restart on failure
    unitConfig = {
      StartLimitBurst = "3";
      StartLimitIntervalSec = "60s";
    };
  };

  # Log rotation for MySQL
  services.logrotate.settings.mysql = {
    files = [ "/var/log/mysql/*.log" ];
    frequency = "daily";
    rotate = 30;
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    sharedscripts = true;
    postrotate = "systemctl reload mysql";
  };

  # MySQL backup script
  systemd.services.mysql-backup = {
    description = "MySQL Database Backup";
    serviceConfig = {
      Type = "oneshot";
      User = "mysql";
      ExecStart = pkgs.writeShellScript "mysql-backup" ''
        #!/usr/bin/env bash
        BACKUP_DIR="/var/backups/mysql"
        DATE=$(date +%Y%m%d_%H%M%S)
        
        mkdir -p "$BACKUP_DIR"
        
        # Backup all databases
        ${pkgs.mariadb}/bin/mysqldump \
          --user=backup \
          --password=backuppass123 \
          --single-transaction \
          --routines \
          --triggers \
          --all-databases \
          --compress \
          > "$BACKUP_DIR/all_databases_$DATE.sql"
        
        # Compress the backup
        gzip "$BACKUP_DIR/all_databases_$DATE.sql"
        
        # Remove backups older than 7 days
        find "$BACKUP_DIR" -name "*.sql.gz" -mtime +7 -delete
        
        echo "MySQL backup completed: all_databases_$DATE.sql.gz"
      '';
    };
  };

  # Schedule daily backups
  systemd.timers.mysql-backup = {
    description = "Daily MySQL Backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  # Create backup directory
  systemd.tmpfiles.rules = [
    "d /var/backups/mysql 0755 mysql mysql -"
  ];
}
