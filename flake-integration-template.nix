# Flake Integration Template for NixOS Web Server with PHP 8.4
# Use this template if your system uses flakes

{
  description = "NixOS configuration with web server (PHP 8.4)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # Add other inputs as needed
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations = {
      # Replace 'your-hostname' with your actual hostname
      your-hostname = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";  # Adjust for your architecture
        modules = [
          ./configuration.nix
          ./webserver.nix  # Add the webserver module
          
          # Optional: Inline webserver configuration
          # ({ config, pkgs, ... }: {
          #   imports = [ ./webserver.nix ];
          # })
        ];
      };
    };
    
    # Optional: Development shell for web development
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
        php84
        mysql80
        nodejs
        git
      ];
      
      shellHook = ''
        echo "🚀 Web development environment with PHP 8.4"
        echo "Available commands:"
        echo "  • php --version"
        echo "  • mysql --version"
        echo "  • rebuild-webserver"
      '';
    };
  };
}
