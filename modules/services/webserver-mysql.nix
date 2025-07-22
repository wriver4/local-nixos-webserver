# Webserver MySQL/MariaDB Service Module
# This module provides MySQL configuration for the webserver
# Uses lib.mkDefault extensively to avoid conflicts with existing MySQL configurations

{ config, pkgs, lib, ... }:

{
  # MySQL/MariaDB configuration with extensive conflict resolution
  services.mysql = {
    enable = lib.mkDefault true;
    package = lib.mkDefault pkgs.mariadb;  # Use mkDefault to allow override by existing configs
    
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
}