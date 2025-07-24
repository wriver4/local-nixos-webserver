#!/usr/bin/env bash

# Fix Module Conflicts
# This script identifies and resolves conflicting option definitions

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

# Get detailed error trace
get_detailed_error() {
    log "Getting detailed error trace..."
    echo ""
    echo "=== Full error trace ==="
    sudo nixos-rebuild dry-build --show-trace 2>&1 | head -50
    echo "========================="
    echo ""
}

# Check for duplicate service definitions
check_duplicate_services() {
    log "Checking for duplicate service definitions..."
    echo ""
    
    # Check nginx definitions
    echo "🔍 Nginx service definitions:"
    find "$NIXOS_CONFIG_DIR" -name "*.nix" -exec grep -l "services\.nginx.*=" {} \; 2>/dev/null | while read file; do
        echo "  📄 $file"
        grep -n "services\.nginx" "$file" | head -3 | sed 's/^/    /'
    done
    echo ""
    
    # Check PHP-FPM definitions
    echo "🔍 PHP-FPM service definitions:"
    find "$NIXOS_CONFIG_DIR" -name "*.nix" -exec grep -l "services\.phpfpm.*=" {} \; 2>/dev/null | while read file; do
        echo "  📄 $file"
        grep -n "services\.phpfpm" "$file" | head -3 | sed 's/^/    /'
    done
    echo ""
    
    # Check MySQL definitions
    echo "🔍 MySQL service definitions:"
    find "$NIXOS_CONFIG_DIR" -name "*.nix" -exec grep -l "services\.mysql.*=" {} \; 2>/dev/null | while read file; do
        echo "  📄 $file"
        grep -n "services\.mysql" "$file" | head -3 | sed 's/^/    /'
    done
    echo ""
}

# Check for conflicting imports
check_conflicting_imports() {
    log "Checking for conflicting imports..."
    echo ""
    
    # Show all imports in configuration.nix
    echo "📄 configuration.nix imports:"
    grep -A 20 "imports.*=.*\[" "$NIXOS_CONFIG_DIR/configuration.nix" | head -25 | sed 's/^/  /'
    echo ""
    
    # Check for duplicate imports
    local imports=$(grep -o '\./[^"]*\.nix\|modules/[^"]*\.nix' "$NIXOS_CONFIG_DIR/configuration.nix" 2>/dev/null | sort)
    local duplicates=$(echo "$imports" | uniq -d)
    
    if [[ -n "$duplicates" ]]; then
        warning "Duplicate imports found:"
        echo "$duplicates" | sed 's/^/  /'
    else
        success "No duplicate imports found"
    fi
    echo ""
}

# Test individual modules
test_individual_modules() {
    log "Testing individual modules..."
    echo ""
    
    find "$NIXOS_CONFIG_DIR/modules" -name "*.nix" -type f | while read module; do
        local module_name=$(basename "$module")
        echo "Testing $module_name:"
        
        if nix-instantiate --parse "$module" &>/dev/null; then
            success "  Syntax OK"
        else
            error "  Syntax ERROR"
            nix-instantiate --parse "$module" 2>&1 | head -3 | sed 's/^/    /'
        fi
    done
    echo ""
}

# Create minimal test configuration
create_minimal_test() {
    log "Creating minimal test configuration..."
    
    # Create minimal config that imports modules one by one
    sudo tee "$NIXOS_CONFIG_DIR/test-minimal.nix" > /dev/null << 'EOF'
# Minimal test configuration
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    # Add modules one by one to test
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "23.11";
}
EOF

    # Test minimal config
    if sudo nixos-rebuild dry-build -I nixos-config="$NIXOS_CONFIG_DIR/test-minimal.nix" &>/dev/null; then
        success "Minimal configuration works"
        return 0
    else
        error "Even minimal configuration fails"
        return 1
    fi
}

# Test modules incrementally
test_modules_incrementally() {
    log "Testing modules incrementally..."
    
    local modules=(
        "./modules/networking.nix"
        "./modules/services/nginx.nix"
        "./modules/services/php.nix"
        "./modules/services/mysql.nix"
        "./modules/webserver/nginx-vhosts.nix"
        "./modules/webserver/php-optimization.nix"
    )
    
    local working_modules=()
    local failing_modules=()
    
    for module in "${modules[@]}"; do
        if [[ -f "$NIXOS_CONFIG_DIR/${module#./}" ]]; then
            echo "Testing with module: $module"
            
            # Create test config with this module
            sudo tee "$NIXOS_CONFIG_DIR/test-incremental.nix" > /dev/null << EOF
# Incremental test configuration
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
$(printf '    %s\n' "${working_modules[@]}")
    $module
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "23.11";
}
EOF

            if sudo nixos-rebuild dry-build -I nixos-config="$NIXOS_CONFIG_DIR/test-incremental.nix" &>/dev/null; then
                success "✅ $module works"
                working_modules+=("$module")
            else
                error "❌ $module causes failure"
                failing_modules+=("$module")
                echo "Error details:"
                sudo nixos-rebuild dry-build -I nixos-config="$NIXOS_CONFIG_DIR/test-incremental.nix" 2>&1 | head -5 | sed 's/^/  /'
            fi
            echo ""
        else
            warning "Module not found: $module"
        fi
    done
    
    echo "📊 Results:"
    echo "Working modules: ${#working_modules[@]}"
    echo "Failing modules: ${#failing_modules[@]}"
    echo ""
    
    if [[ ${#failing_modules[@]} -gt 0 ]]; then
        echo "❌ Failing modules:"
        printf '  %s\n' "${failing_modules[@]}"
    fi
    
    # Clean up test files
    sudo rm -f "$NIXOS_CONFIG_DIR/test-minimal.nix" "$NIXOS_CONFIG_DIR/test-incremental.nix"
}

# Fix common conflicts
fix_common_conflicts() {
    log "Fixing common conflicts..."
    
    # Remove any duplicate imports from configuration.nix
    log "Removing duplicate imports..."
    sudo awk '!seen[$0]++' "$NIXOS_CONFIG_DIR/configuration.nix" > /tmp/config-dedup.nix
    sudo mv /tmp/config-dedup.nix "$NIXOS_CONFIG_DIR/configuration.nix"
    
    # Fix nginx service conflicts
    log "Fixing nginx service conflicts..."
    local nginx_files=$(find "$NIXOS_CONFIG_DIR" -name "*.nix" -exec grep -l "services\.nginx.*=" {} \; 2>/dev/null)
    local nginx_count=$(echo "$nginx_files" | wc -l)
    
    if [[ $nginx_count -gt 1 ]]; then
        warning "Multiple nginx service definitions found"
        echo "$nginx_files" | while read file; do
            if [[ "$file" != *"nginx-vhosts.nix"* && "$file" != *"services/nginx.nix"* ]]; then
                warning "Commenting out nginx service in: $file"
                sudo sed -i 's/^[[:space:]]*services\.nginx/# &/' "$file"
            fi
        done
    fi
    
    # Fix PHP-FPM conflicts
    log "Fixing PHP-FPM conflicts..."
    local php_files=$(find "$NIXOS_CONFIG_DIR" -name "*.nix" -exec grep -l "services\.phpfpm.*=" {} \; 2>/dev/null)
    local php_count=$(echo "$php_files" | wc -l)
    
    if [[ $php_count -gt 1 ]]; then
        warning "Multiple PHP-FPM service definitions found"
        echo "$php_files" | while read file; do
            if [[ "$file" != *"services/php.nix"* && "$file" != *"php-optimization.nix"* ]]; then
                warning "Commenting out PHP-FPM service in: $file"
                sudo sed -i 's/^[[:space:]]*services\.phpfpm/# &/' "$file"
            fi
        done
    fi
    
    # Fix MySQL conflicts
    log "Fixing MySQL conflicts..."
    local mysql_files=$(find "$NIXOS_CONFIG_DIR" -name "*.nix" -exec grep -l "services\.mysql.*=" {} \; 2>/dev/null)
    local mysql_count=$(echo "$mysql_files" | wc -l)
    
    if [[ $mysql_count -gt 1 ]]; then
        warning "Multiple MySQL service definitions found"
        echo "$mysql_files" | while read file; do
            if [[ "$file" != *"services/mysql.nix"* ]]; then
                warning "Commenting out MySQL service in: $file"
                sudo sed -i 's/^[[:space:]]*services\.mysql/# &/' "$file"
            fi
        done
    fi
    
    success "Fixed common conflicts"
}

# Create clean configuration
create_clean_configuration() {
    log "Creating clean configuration.nix..."
    
    # Backup current config
    sudo cp "$NIXOS_CONFIG_DIR/configuration.nix" "$NIXOS_CONFIG_DIR/configuration.nix.conflict-backup-$(date +%Y%m%d-%H%M%S)"
    
    # Create clean configuration
    sudo tee "$NIXOS_CONFIG_DIR/configuration.nix" > /dev/null << 'EOF'
# Clean NixOS Configuration
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/networking.nix
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    ./modules/services/mysql.nix
    ./modules/webserver/nginx-vhosts.nix
    ./modules/webserver/php-optimization.nix
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
    extraGroups = [ "wheel" "nginx" ];
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

  system.stateVersion = "23.11";
}
EOF

    success "Created clean configuration.nix"
}

# Main function
main() {
    echo "🔧 Fix Module Conflicts"
    echo "======================="
    echo ""
    
    get_detailed_error
    check_duplicate_services
    check_conflicting_imports
    test_individual_modules
    
    echo ""
    echo "Choose fix approach:"
    echo "1. Test modules incrementally to identify the problem"
    echo "2. Fix common conflicts automatically"
    echo "3. Create clean configuration.nix"
    echo "4. All of the above (recommended)"
    echo ""
    read -p "Enter choice (1-4): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            if create_minimal_test; then
                test_modules_incrementally
            fi
            ;;
        2)
            fix_common_conflicts
            ;;
        3)
            create_clean_configuration
            ;;
        4)
            if create_minimal_test; then
                test_modules_incrementally
            fi
            fix_common_conflicts
            create_clean_configuration
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    echo ""
    echo "🎯 Next steps:"
    echo "1. Test with: sudo nixos-rebuild dry-build"
    echo "2. If successful: sudo nixos-rebuild switch"
    echo "3. Check backup: $NIXOS_CONFIG_DIR/configuration.nix.conflict-backup-*"
}

# Run main function
main "$@"