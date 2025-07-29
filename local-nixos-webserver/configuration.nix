# NixOS Configuration - Main Entry Point
# System State Version: 25.05
# Modular architecture with separate service modules

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/services/nginx.nix
    ./modules/services/php-fpm.nix
    ./modules/services/mysql.nix
    ./modules/services/redis.nix
    ./modules/services/networking.nix
    ./modules/services/users.nix
    ./modules/services/system.nix
  ];

  # System state version - NixOS 25.05
  system.stateVersion = "25.05";

  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable SSH (kept in main config as it's essential)
  services.openssh.enable = true;

  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Allow unfree packages if needed
  nixpkgs.config.allowUnfree = true;

  # System packages for web development and administration
  environment.systemPackages = with pkgs; [
    # Web development tools
    tree
    htop
    curl
    wget
    git
    vim
    nano
    
    # PHP 8.4 CLI tools
    php84
    php84Packages.composer
    
    # Database tools
    mysql80
    
    # System monitoring
    iotop
    nethogs
    
    # File management
    rsync
    unzip
    zip
  ];
}
