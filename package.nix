# Traditional Nix package for the web server
{ lib
, stdenv
, writeShellScriptBin
, php84
, nginx
, mariadb
, redis
}:

stdenv.mkDerivation rec {
  pname = "nixos-webserver";
  version = "1.0.0";
  
  src = ./.;
  
  buildInputs = [ php84 nginx mariadb redis ];
  
  installPhase = ''
    mkdir -p $out/{share,bin,etc}
    
    # Install configuration modules
    cp -r modules $out/share/
    
    # Install web content
    cp -r web-content $out/share/
    
    # Install scripts
    cp *.sh $out/bin/
    chmod +x $out/bin/*.sh
    
    # Install documentation
    cp README.md $out/share/
    
    # Create wrapper script
    cat > $out/bin/nixos-webserver-setup << 'EOF'
#!/usr/bin/env bash
set -e

INSTALL_DIR="$out/share"
NIXOS_CONFIG="/etc/nixos"

echo "🚀 Setting up NixOS Web Server..."

# Copy modules
sudo mkdir -p "$NIXOS_CONFIG/modules"
sudo cp -r "$INSTALL_DIR/modules"/* "$NIXOS_CONFIG/modules/"

# Copy web content
sudo mkdir -p /var/www
sudo cp -r "$INSTALL_DIR/web-content"/* /var/www/

# Set permissions
sudo chown -R nginx:nginx /var/www 2>/dev/null || true

echo "✅ Setup complete! Add modules to your configuration.nix imports."
EOF
    chmod +x $out/bin/nixos-webserver-setup
  '';
  
  meta = with lib; {
    description = "Complete NixOS web server with PHP 8.4, nginx, MySQL, and Redis";
    longDescription = ''
      A comprehensive NixOS web server configuration featuring:
      - nginx with FastCGI caching
      - PHP 8.4 with FPM, OPcache, and JIT
      - MariaDB/MySQL database server
      - Redis caching server
      - Virtual host management dashboard
      - Modular configuration structure
    '';
    homepage = "https://github.com/your-username/nixos-webserver";
    license = licenses.mit;
    maintainers = [ maintainers.yourname ];
    platforms = platforms.linux;
  };
}
