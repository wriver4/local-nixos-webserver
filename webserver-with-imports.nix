# Web Server Module with Imports
# This demonstrates how modules can import other modules

{ config, pkgs, lib, ... }:

{
  # Import other modules into this webserver module
  imports = [
    # Import specific service modules
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    ./modules/services/mysql.nix
    
    # Import feature modules
    ./modules/features/web-directories.nix
    ./modules/features/security.nix
    
    # Import configuration modules
    ./modules/config/php-optimization.nix
    ./modules/config/nginx-vhosts.nix
    
    # Conditional imports based on system
    (lib.mkIf (config.networking.hostName == "king") ./modules/hosts/king-specific.nix)
    
    # Import from different paths
    ../shared-modules/common-web.nix
    /etc/nixos/modules/custom/monitoring.nix
  ];

  # Module-specific configuration
  # This configuration will be merged with imported modules
  
  # System packages for web development
  environment.systemPackages = with pkgs; [
    tree
    htop
    php  # In NixOS 25.05, 'php' = PHP 8.4
  ];

  # Enable services (can be overridden by imported modules)
  services.openssh.enable = lib.mkDefault true;
  
  # Firewall configuration - merge with existing
  networking.firewall.allowedTCPPorts = lib.mkAfter [ 80 443 ];

  # System activation script
  system.activationScripts.websetup = ''
    # Create web directories
    mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}
    chown -R nginx:nginx /var/www
    chmod -R 755 /var/www
  '';
}