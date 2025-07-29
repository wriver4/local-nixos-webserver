{
  description = "NixOS Web Server with Virtual Host Management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixos-rebuild
            git
          ];
        };

        # Package the web content
        packages.webserver-content = pkgs.stdenv.mkDerivation {
          pname = "nixos-webserver-content";
          version = "1.0.0";
          
          src = ./web-content;
          
          installPhase = ''
            mkdir -p $out/share/webserver
            cp -r * $out/share/webserver/
          '';
          
          meta = with pkgs.lib; {
            description = "Web content for NixOS web server";
            license = licenses.mit;
          };
        };

        # Package the installation script
        packages.webserver-installer = pkgs.writeShellScriptBin "install-nixos-webserver" ''
          set -e
          
          SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
          NIXOS_CONFIG_DIR="/etc/nixos"
          BACKUP_DIR="/etc/nixos/webserver-backups/$(date +%Y%m%d-%H%M%S)"
          WEB_ROOT="/var/www"
          
          echo "🚀 Installing NixOS Web Server..."
          
          # Check if running as root
          if [[ $EUID -eq 0 ]]; then
            echo "❌ This script should not be run as root. Please run as a regular user with sudo access."
            exit 1
          fi
          
          # Check if this is a NixOS system
          if [[ ! -f /etc/NIXOS ]]; then
            echo "❌ This script is designed for NixOS systems only."
            exit 1
          fi
          
          # Create backup
          echo "📦 Creating backup..."
          sudo mkdir -p "$BACKUP_DIR"
          sudo cp -r "$NIXOS_CONFIG_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
          
          # Copy modules
          echo "📁 Installing service modules..."
          sudo mkdir -p "$NIXOS_CONFIG_DIR/modules/services"
          sudo cp -r ${./modules/services}/* "$NIXOS_CONFIG_DIR/modules/services/"
          
          # Install web content
          echo "🌐 Installing web content..."
          sudo mkdir -p "$WEB_ROOT"
          sudo cp -r ${self.packages.${system}.webserver-content}/share/webserver/* "$WEB_ROOT/"
          
          # Set permissions
          sudo chown -R nginx:nginx "$WEB_ROOT" 2>/dev/null || true
          sudo chmod -R 755 "$WEB_ROOT"
          
          # Install helper scripts
          echo "🔧 Installing helper scripts..."
          sudo cp ${./install-on-existing-nixos.sh} /usr/local/bin/nixos-webserver-install
          sudo chmod +x /usr/local/bin/nixos-webserver-install
          
          echo "✅ Installation complete!"
          echo ""
          echo "Next steps:"
          echo "1. Add the following to your /etc/nixos/configuration.nix imports:"
          echo "   ./modules/services/nginx.nix"
          echo "   ./modules/services/php-fpm.nix"
          echo "   ./modules/services/mysql.nix"
          echo "   ./modules/services/redis.nix"
          echo "   ./modules/services/networking.nix"
          echo "   ./modules/services/users.nix"
          echo "   ./modules/services/system.nix"
          echo ""
          echo "2. Run: sudo nixos-rebuild switch"
          echo "3. Access your sites at the configured domains"
        '';

        # Complete system configuration as a module
        packages.webserver-module = pkgs.writeText "webserver-module.nix" ''
          # NixOS Web Server Module
          # Import this in your configuration.nix
          
          { config, pkgs, ... }:
          
          {
            imports = [
              ./modules/services/nginx.nix
              ./modules/services/php-fpm.nix
              ./modules/services/mysql.nix
              ./modules/services/redis.nix
              ./modules/services/networking.nix
              ./modules/services/users.nix
              ./modules/services/system.nix
            ];
          }
        '';
      }
    ) // {
      # NixOS module for direct integration
      nixosModules.webserver = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.nixos-webserver;
        in {
          options.services.nixos-webserver = {
            enable = mkEnableOption "NixOS Web Server with Virtual Host Management";
            
            webRoot = mkOption {
              type = types.str;
              default = "/var/www";
              description = "Root directory for web content";
            };
            
            domains = mkOption {
              type = types.listOf types.str;
              default = [ "dashboard.local" "phpmyadmin.local" "sample1.local" "sample2.local" "sample3.local" ];
              description = "List of local domains to configure";
            };
            
            phpVersion = mkOption {
              type = types.package;
              default = pkgs.php84;
              description = "PHP version to use";
            };
          };
          
          config = mkIf cfg.enable {
            imports = [
              ./modules/services/nginx.nix
              ./modules/services/php-fpm.nix
              ./modules/services/mysql.nix
              ./modules/services/redis.nix
              ./modules/services/networking.nix
              ./modules/services/users.nix
              ./modules/services/system.nix
            ];
            
            # Override default values with user configuration
            services.phpfpm.pools.www.phpPackage = cfg.phpVersion;
            networking.hosts."127.0.0.1" = cfg.domains;
            
            # Install web content
            system.activationScripts.webserver-content = ''
              mkdir -p ${cfg.webRoot}
              cp -r ${self.packages.${pkgs.system}.webserver-content}/share/webserver/* ${cfg.webRoot}/
              chown -R nginx:nginx ${cfg.webRoot}
              chmod -R 755 ${cfg.webRoot}
            '';
          };
        };
    };
}
