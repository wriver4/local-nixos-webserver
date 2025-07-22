# Main Web Server Module
# This module imports webserver-specific services and configurations
# Designed to work with existing module structure

{ config, pkgs, lib, ... }:

{
  imports = [
    # Import networking configuration
    ./modules/networking.nix
    
    # Import webserver-specific modules from the webserver directory
    ./modules/webserver/nginx-vhosts.nix
    ./modules/webserver/php-optimization.nix
    
    # Import or reference existing service modules
    # These will be enhanced/configured by the webserver modules above
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    ./modules/services/mysql.nix
  ];

  # High-level webserver coordination
  # This ensures all webserver components work together
  
  # System packages for web development
  environment.systemPackages = with pkgs; [
    tree
    htop
    php  # In NixOS 25.05, 'php' = PHP 8.4
  ];

  # Ensure web directories exist
  system.activationScripts.webserver-setup = ''
    # Create web directories
    mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}
    chown -R nginx:nginx /var/www
    chmod -R 755 /var/www
  '';
}