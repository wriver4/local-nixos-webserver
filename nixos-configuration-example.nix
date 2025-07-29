# Example NixOS configuration.nix showing how to use the web server
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    # Option 1: Import individual modules
    ./modules/services/nginx.nix
    ./modules/services/php-fpm.nix
    ./modules/services/mysql.nix
    ./modules/services/redis.nix
    ./modules/services/networking.nix
    ./modules/services/users.nix
    ./modules/services/system.nix
    
    # Option 2: Or use the flake module (if using flakes)
    # inputs.nixos-webserver.nixosModules.webserver
  ];

  # If using the flake module, enable it:
  # services.nixos-webserver = {
  #   enable = true;
  #   webRoot = "/var/www";
  #   domains = [ "dashboard.local" "phpmyadmin.local" "mysite.local" ];
  # };

  # System configuration
  system.stateVersion = "25.05";
  
  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Enable SSH
  services.openssh.enable = true;
  
  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  
  # Allow unfree packages if needed
  nixpkgs.config.allowUnfree = true;
}
