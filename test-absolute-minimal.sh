#!/usr/bin/env bash

# Test Absolute Minimal Configuration
# This script tests with the most basic possible configuration

set -e  # Exit on any error

NIXOS_CONFIG_DIR="/etc/nixos"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test 1: Absolute minimal (just hardware)
test_absolute_minimal() {
    log "Test 1: Absolute minimal configuration..."
    
    sudo tee "$NIXOS_CONFIG_DIR/test-absolute-minimal.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "25.05";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-absolute-minimal.nix" &>/dev/null; then
        success "✅ Absolute minimal works"
        return 0
    else
        error "❌ Even absolute minimal fails"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-absolute-minimal.nix" 2>&1 | head -10
        return 1
    fi
}

# Test 2: Add networking.nix
test_with_networking() {
    log "Test 2: Adding networking.nix..."
    
    sudo tee "$NIXOS_CONFIG_DIR/test-with-networking.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/networking.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "25.05";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-with-networking.nix" &>/dev/null; then
        success "✅ With networking.nix works"
        return 0
    else
        error "❌ networking.nix causes issues"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-with-networking.nix" 2>&1 | head -10
        return 1
    fi
}

# Test 3: Inline networking instead of module
test_inline_networking() {
    log "Test 3: Inline networking configuration..."
    
    sudo tee "$NIXOS_CONFIG_DIR/test-inline-networking.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Inline networking instead of module
  networking = {
    hostName = "nixos-webserver";
    networkmanager.enable = true;
    hosts = {
      "127.0.0.1" = [ 
        "localhost" 
        "dashboard.local" 
        "sample1.local" 
        "sample2.local" 
        "sample3.local" 
      ];
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };
  };
  
  system.stateVersion = "25.05";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-inline-networking.nix" &>/dev/null; then
        success "✅ Inline networking works"
        return 0
    else
        error "❌ Inline networking fails"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-inline-networking.nix" 2>&1 | head -10
        return 1
    fi
}

# Test 4: Add basic nginx inline
test_inline_nginx() {
    log "Test 4: Adding basic nginx inline..."
    
    sudo tee "$NIXOS_CONFIG_DIR/test-inline-nginx.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Inline networking
  networking = {
    hostName = "nixos-webserver";
    networkmanager.enable = true;
    hosts = {
      "127.0.0.1" = [ "localhost" "dashboard.local" ];
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };
  };
  
  # Basic nginx
  services.nginx = {
    enable = true;
    package = pkgs.nginxMainline;
  };
  
  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
  };
  users.groups.nginx = {};
  
  system.stateVersion = "25.05";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-inline-nginx.nix" &>/dev/null; then
        success "✅ Inline nginx works"
        return 0
    else
        error "❌ Inline nginx fails"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-inline-nginx.nix" 2>&1 | head -10
        return 1
    fi
}

# Test 5: Check if it's a specific module causing issues
test_problematic_modules() {
    log "Test 5: Testing each module individually..."
    
    local modules=(
        "./modules/networking.nix"
        "./modules/services/nginx.nix"
        "./modules/services/php.nix"
        "./modules/services/mysql.nix"
    )
    
    for module in "${modules[@]}"; do
        local module_name=$(basename "$module")
        echo "Testing: $module_name"
        
        sudo tee "$NIXOS_CONFIG_DIR/test-single-module.nix" > /dev/null << EOF
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    $module
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "25.05";
}
EOF

        if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-single-module.nix" &>/dev/null; then
            success "  ✅ $module_name works alone"
        else
            error "  ❌ $module_name causes recursion"
            echo "    Error preview:"
            sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-single-module.nix" 2>&1 | head -3 | sed 's/^/      /'
        fi
    done
}

# Create working configuration based on tests
create_working_from_tests() {
    log "Creating working configuration based on test results..."
    
    # Backup current config
    sudo cp "$NIXOS_CONFIG_DIR/configuration.nix" "$NIXOS_CONFIG_DIR/configuration.nix.test-backup-$(date +%Y%m%d-%H%M%S)"
    
    # Start with what works and build up
    if test_absolute_minimal; then
        if test_inline_networking; then
            if test_inline_nginx; then
                log "Creating inline configuration that works..."
                
                sudo tee "$NIXOS_CONFIG_DIR/configuration.nix" > /dev/null << 'EOF'
# Working Inline Configuration
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];
  
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Networking configuration
  networking = {
    hostName = "nixos-webserver";
    networkmanager.enable = true;
    hosts = {
      "127.0.0.1" = [ 
        "localhost" 
        "dashboard.local" 
        "phpmyadmin.local"
        "sample1.local" 
        "sample2.local" 
        "sample3.local" 
      ];
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 3306 ];
    };
  };
  
  # Nginx configuration
  services.nginx = {
    enable = true;
    package = pkgs.nginxMainline;
    
    commonHttpConfig = ''
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
      keepalive_timeout 65;
      types_hash_max_size 2048;
      client_max_body_size 64M;
      
      gzip on;
      gzip_vary on;
      gzip_min_length 1024;
      gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
      
      server_tokens off;
    '';
    
    virtualHosts = {
      "dashboard.local" = {
        root = "/var/www/dashboard";
        locations."/" = {
          tryFiles = "$uri $uri/ /index.php?$query_string";
          index = "index.php index.html";
        };
        locations."~ \\.php$" = {
          extraConfig = ''
            fastcgi_pass unix:/run/phpfpm/www.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include ${pkgs.nginx}/conf/fastcgi_params;
          '';
        };
      };
      
      "sample1.local" = {
        root = "/var/www/sample1";
        locations."/" = {
          tryFiles = "$uri $uri/ /index.php?$query_string";
          index = "index.php index.html";
        };
        locations."~ \\.php$" = {
          extraConfig = ''
            fastcgi_pass unix:/run/phpfpm/www.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include ${pkgs.nginx}/conf/fastcgi_params;
          '';
        };
      };
    };
  };
  
  # PHP configuration
  services.phpfpm.pools.www = {
    user = "nginx";
    group = "nginx";
    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "listen.mode" = "0600";
      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 4;
      "pm.max_requests" = 500;
    };
    
    phpPackage = pkgs.php.buildEnv {
      extensions = ({ enabled, all }: enabled ++ (with pkgs.php84Extensions; [
        mysqli pdo_mysql mbstring gd curl zip fileinfo intl exif openssl
      ]));
      
      extraConfig = ''
        memory_limit = 256M
        upload_max_filesize = 64M
        post_max_size = 64M
        max_execution_time = 300
        date.timezone = UTC
        opcache.enable = 1
        opcache.memory_consumption = 128
        opcache.jit_buffer_size = 64M
        opcache.jit = tracing
        expose_php = Off
        display_errors = Off
        log_errors = On
        error_log = /var/log/php_errors.log
      '';
    };
  };
  
  # MySQL configuration
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld = {
      bind-address = "127.0.0.1";
      port = 3306;
      require_secure_transport = "OFF";
      ssl = "0";
    };
    initialDatabases = [
      { name = "dashboard_db"; }
      { name = "sample1_db"; }
    ];
    initialScript = pkgs.writeText "mysql-init.sql" ''
      CREATE USER IF NOT EXISTS 'webuser'@'localhost' IDENTIFIED BY 'webpass123';
      GRANT ALL PRIVILEGES ON dashboard_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample1_db.* TO 'webuser'@'localhost';
      ALTER USER 'webuser'@'localhost' REQUIRE NONE;
      FLUSH PRIVILEGES;
    '';
  };
  
  # Users
  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
    description = "Nginx web server user";
  };
  users.groups.nginx = {};
  
  users.users.webadmin = {
    isNormalUser = true;
    description = "Web Administrator";
    extraGroups = [ "wheel" "nginx" ];
  };
  
  # Basic packages
  environment.systemPackages = with pkgs; [
    vim wget curl git tree htop php mysql80
  ];
  
  # SSH
  services.openssh.enable = true;
  
  # Web directories
  system.activationScripts.webserver-setup = ''
    mkdir -p /var/www/{dashboard,sample1,sample2,sample3}
    chown -R nginx:nginx /var/www
    chmod -R 755 /var/www
  '';
  
  system.stateVersion = "25.05";
}
EOF

                success "Created working inline configuration"
                return 0
            fi
        fi
    fi
    
    error "Could not create working configuration"
    return 1
}

# Clean up test files
cleanup() {
    log "Cleaning up test files..."
    sudo rm -f "$NIXOS_CONFIG_DIR"/test-*.nix
    success "Cleanup complete"
}

# Main function
main() {
    echo "🔬 Test Absolute Minimal Configuration"
    echo "======================================"
    echo ""
    
    echo "This will test progressively to find exactly what's causing the recursion."
    echo ""
    
    # Run tests
    if test_absolute_minimal; then
        test_with_networking
        test_inline_networking
        test_inline_nginx
        test_problematic_modules
        
        echo ""
        echo "🎯 Based on test results, creating working configuration..."
        if create_working_from_tests; then
            echo ""
            echo "Testing final configuration..."
            if sudo nixos-rebuild dry-build --impure &>/dev/null; then
                success "🎉 Working configuration created!"
                echo ""
                echo "Ready to apply with: sudo nixos-rebuild switch --impure"
            else
                error "Final configuration still has issues"
            fi
        fi
    else
        error "Even absolute minimal fails - there may be an issue with hardware-configuration.nix"
    fi
    
    cleanup
    
    echo ""
    echo "🎯 Summary:"
    echo "- If absolute minimal works: Issue is in our modules"
    echo "- If absolute minimal fails: Issue is in hardware config or base system"
    echo "- Working configuration created based on successful tests"
}

# Run main function
main "$@"