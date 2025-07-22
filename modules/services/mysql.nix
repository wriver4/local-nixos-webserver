# Enhanced MySQL/MariaDB Service Module
# This module provides MySQL configuration that works with existing setups
# Uses lib.mkDefault extensively to avoid conflicts with existing MySQL configurations

{ config, pkgs, lib, ... }:

{
  # MySQL/MariaDB configuration with extensive conflict resolution
  services.mysql = {
    enable = lib.mkDefault true;
    package = lib.mkDefault pkgs.mariadb;  # Use mkDefault to allow override by existing configs
    
    # Basic MySQL settings with mkDefault
    settings = lib.mkDefault {
      mysqld = {
        # Basic configuration
        bind-address = lib.mkDefault "127.0.0.1";
        port = lib.mkDefault 3306;
        
        # InnoDB optimization
        innodb_buffer_pool_size = lib.mkDefault "256M";
        innodb_log_file_size = lib.mkDefault "64M";
        innodb_flush_log_at_trx_commit = lib.mkDefault "2";
        innodb_flush_method = lib.mkDefault "O_DIRECT";
        
        # Query optimization
        query_cache_type = lib.mkDefault "1";
        query_cache_size = lib.mkDefault "32M";
        query_cache_limit = lib.mkDefault "2M";
        
        # Connection settings
        max_connections = lib.mkDefault "200";
        max_connect_errors = lib.mkDefault "1000";
        
        # Buffer optimization
        key_buffer_size = lib.mkDefault "32M";
        sort_buffer_size = lib.mkDefault "2M";
        read_buffer_size = lib.mkDefault "1M";
        read_rnd_buffer_size = lib.mkDefault "2M";
        
        # Temporary table optimization
        tmp_table_size = lib.mkDefault "32M";
        max_heap_table_size = lib.mkDefault "32M";
        
        # Logging
        slow_query_log = lib.mkDefault "1";
        slow_query_log_file = lib.mkDefault "/var/log/mysql/slow.log";
        long_query_time = lib.mkDefault "2";
        
        # Character set
        character-set-server = lib.mkDefault "utf8mb4";
        collation-server = lib.mkDefault "utf8mb4_unicode_ci";
      };
    };
    
    # Webserver-specific databases - only add if not already defined
    initialDatabases = lib.mkDefault [
      { name = "dashboard_db"; }
      { name = "sample1_db"; }
      { name = "sample2_db"; }
      { name = "sample3_db"; }
    ];
    
    # Webserver-specific database initialization
    initialScript = lib.mkDefault (pkgs.writeText "webserver-mysql-init.sql" ''
      -- Webserver database initialization
      CREATE USER IF NOT EXISTS 'webuser'@'localhost' IDENTIFIED BY 'webpass123';
      GRANT ALL PRIVILEGES ON dashboard_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample1_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample2_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample3_db.* TO 'webuser'@'localhost';
      
      -- phpMyAdmin user
      CREATE USER IF NOT EXISTS 'phpmyadmin'@'localhost' IDENTIFIED BY 'pmapass123';
      GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost' WITH GRANT OPTION;
      
      FLUSH PRIVILEGES;
    '');
  };

  # Add MySQL client tools to system packages
  environment.systemPackages = with pkgs; [
    mysql80  # MySQL client tools
  ];

  # Open MySQL port in firewall (append to existing ports)
  networking.firewall.allowedTCPPorts = lib.mkAfter [ 3306 ];

  # Create MySQL log directory
  system.activationScripts.mysql-logs = ''
    mkdir -p /var/log/mysql
    chown mysql:mysql /var/log/mysql
    chmod 755 /var/log/mysql
  '';

  # Systemd service optimization
  systemd.services.mysql.serviceConfig = lib.mkMerge [
    {
      LimitNOFILE = lib.mkDefault 65535;
      LimitNPROC = lib.mkDefault 4096;
    }
  ];
}