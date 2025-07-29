# Development shell
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # NixOS tools
    nixos-rebuild
    nix-prefetch-git
    
    # Development tools
    git
    curl
    wget
    
    # Web server components (for testing)
    php84
    nginx
    mariadb
    redis
    
    # Utilities
    tree
    htop
  ];
  
  shellHook = ''
    echo "🚀 NixOS Web Server Development Environment"
    echo "Available commands:"
    echo "  - nixos-rebuild: Rebuild NixOS configuration"
    echo "  - nix-build: Build the package"
    echo "  - nix-shell: Enter development shell"
    echo ""
    echo "To install: nix-env -i -f default.nix"
    echo "Or with flakes: nix profile install ."
  '';
}
