#!/usr/bin/env bash

# Isolate Problem Module (with --impure)
# This script tests each module individually to find the exact cause

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

# Test minimal configuration
test_minimal() {
    log "Testing minimal configuration..."
    
    sudo tee "$NIXOS_CONFIG_DIR/test-minimal.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "23.11";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-minimal.nix" &>/dev/null; then
        success "Minimal configuration works"
        return 0
    else
        error "Even minimal configuration fails"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-minimal.nix" 2>&1 | head -10
        return 1
    fi
}

# Test each module individually
test_modules_individually() {
    log "Testing each module individually..."
    echo ""
    
    local modules=(
        "modules/networking.nix"
        "modules/services/nginx.nix"
        "modules/services/php.nix"
        "modules/services/mysql.nix"
        "modules/webserver/nginx-vhosts.nix"
        "modules/webserver/php-optimization.nix"
    )
    
    for module in "${modules[@]}"; do
        local module_path="$NIXOS_CONFIG_DIR/$module"
        
        if [[ -f "$module_path" ]]; then
            echo "Testing: $module"
            
            # Create test config with just this module
            sudo tee "$NIXOS_CONFIG_DIR/test-single.nix" > /dev/null << EOF
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./$module
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "23.11";
}
EOF

            if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-single.nix" &>/dev/null; then
                success "  ✅ $module works alone"
            else
                error "  ❌ $module fails alone"
                echo "    Error details:"
                sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-single.nix" 2>&1 | head -3 | sed 's/^/      /'
            fi
        else
            warning "  Module not found: $module"
        fi
        echo ""
    done
    
    # Clean up
    sudo rm -f "$NIXOS_CONFIG_DIR/test-single.nix"
}

# Test combinations of modules
test_module_combinations() {
    log "Testing module combinations..."
    echo ""
    
    # Test services together
    echo "Testing services together:"
    sudo tee "$NIXOS_CONFIG_DIR/test-services.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    ./modules/services/mysql.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "23.11";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-services.nix" &>/dev/null; then
        success "  ✅ Services work together"
    else
        error "  ❌ Services conflict with each other"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-services.nix" 2>&1 | head -5 | sed 's/^/    /'
    fi
    echo ""
    
    # Test webserver modules together
    echo "Testing webserver modules together:"
    sudo tee "$NIXOS_CONFIG_DIR/test-webserver.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/webserver/nginx-vhosts.nix
    ./modules/webserver/php-optimization.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "23.11";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-webserver.nix" &>/dev/null; then
        success "  ✅ Webserver modules work together"
    else
        error "  ❌ Webserver modules conflict"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-webserver.nix" 2>&1 | head -5 | sed 's/^/    /'
    fi
    echo ""
    
    # Test services + webserver (without mysql to isolate)
    echo "Testing nginx service + webserver modules:"
    sudo tee "$NIXOS_CONFIG_DIR/test-nginx-combo.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/services/nginx.nix
    ./modules/webserver/nginx-vhosts.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "23.11";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-nginx-combo.nix" &>/dev/null; then
        success "  ✅ Nginx service + vhosts work together"
    else
        error "  ❌ Nginx service + vhosts conflict"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-nginx-combo.nix" 2>&1 | head -5 | sed 's/^/    /'
    fi
    echo ""
    
    # Test PHP service + optimization
    echo "Testing PHP service + optimization:"
    sudo tee "$NIXOS_CONFIG_DIR/test-php-combo.nix" > /dev/null << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/services/php.nix
    ./modules/webserver/php-optimization.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "23.11";
}
EOF

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-php-combo.nix" &>/dev/null; then
        success "  ✅ PHP service + optimization work together"
    else
        error "  ❌ PHP service + optimization conflict"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-php-combo.nix" 2>&1 | head -5 | sed 's/^/    /'
    fi
    echo ""
    
    # Clean up
    sudo rm -f "$NIXOS_CONFIG_DIR/test-services.nix" "$NIXOS_CONFIG_DIR/test-webserver.nix" "$NIXOS_CONFIG_DIR/test-nginx-combo.nix" "$NIXOS_CONFIG_DIR/test-php-combo.nix"
}

# Create working configuration based on test results
create_working_config() {
    log "Creating working configuration based on test results..."
    
    # Backup current config
    sudo cp "$NIXOS_CONFIG_DIR/configuration.nix" "$NIXOS_CONFIG_DIR/configuration.nix.isolation-backup-$(date +%Y%m%d-%H%M%S)"
    
    # Start with minimal working config
    sudo tee "$NIXOS_CONFIG_DIR/configuration.nix" > /dev/null << 'EOF'
# Working NixOS Configuration
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    # Add working modules here based on test results
  ];

  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # User configuration
  users.users.webadmin = {
    isNormalUser = true;
    description = "Web Administrator";
    extraGroups = [ "wheel" ];
  };

  # Basic system packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    tree
    htop
  ];

  # Enable SSH
  services.openssh.enable = true;

  # Basic firewall
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "23.11";
}
EOF

    success "Created minimal working configuration"
    
    # Test the minimal config
    if sudo nixos-rebuild dry-build --impure &>/dev/null; then
        success "Minimal configuration works - you can now add modules incrementally"
    else
        error "Even minimal configuration fails"
        sudo nixos-rebuild dry-build --impure 2>&1 | head -10
    fi
}

# Quick test current config
test_current_config() {
    log "Testing current configuration..."
    
    if sudo nixos-rebuild dry-build --impure &>/dev/null; then
        success "Current configuration works!"
        return 0
    else
        error "Current configuration fails"
        echo "Error details:"
        sudo nixos-rebuild dry-build --impure 2>&1 | head -10
        return 1
    fi
}

# Main function
main() {
    echo "🔍 Isolate Problem Module (with --impure)"
    echo "========================================="
    echo ""
    
    # First test current config
    if test_current_config; then
        echo ""
        echo "🎉 Your current configuration already works!"
        echo "You can run: sudo nixos-rebuild switch --impure"
        return 0
    fi
    
    echo ""
    if test_minimal; then
        test_modules_individually
        test_module_combinations
        
        echo ""
        echo "🎯 Based on the test results above:"
        echo "- Modules that work alone can be used"
        echo "- Modules that fail alone need to be fixed"
        echo "- Combinations that fail indicate conflicts"
        echo ""
        
        read -p "Create a minimal working configuration? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            create_working_config
        fi
    else
        error "Even minimal configuration fails - there may be a hardware-configuration.nix issue"
    fi
    
    # Clean up
    sudo rm -f "$NIXOS_CONFIG_DIR/test-minimal.nix"
    
    echo ""
    echo "🎯 Next steps:"
    echo "1. Review the test results above"
    echo "2. Fix any modules that fail individually"
    echo "3. Add working modules to configuration.nix one by one"
    echo "4. Test after each addition with: sudo nixos-rebuild dry-build --impure"
    echo "5. When ready: sudo nixos-rebuild switch --impure"
}

# Run main function
main "$@"