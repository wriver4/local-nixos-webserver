#!/usr/bin/env bash

# Fix PHP JSON Extension Error
# The 'json' extension is built-in to PHP 8.4 and doesn't need to be explicitly loaded

set -e  # Exit on any error

NIXOS_CONFIG_DIR="/etc/nixos"
PHP_MODULE="$NIXOS_CONFIG_DIR/modules/services/php.nix"

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
    exit 1
}

# Check if PHP module exists
check_php_module() {
    log "Checking PHP module..."
    
    if [[ ! -f "$PHP_MODULE" ]]; then
        error "PHP module not found at $PHP_MODULE"
    fi
    success "Found PHP module"
}

# Show the problematic line
show_problem() {
    log "Showing the problematic area in PHP module..."
    echo ""
    echo "Lines around the error (line 70):"
    sed -n '65,75p' "$PHP_MODULE" | nl -v65
    echo ""
}

# Fix the JSON extension issue
fix_json_extension() {
    log "Fixing JSON extension issue..."
    
    # Create backup
    sudo cp "$PHP_MODULE" "$PHP_MODULE.json-fix-backup-$(date +%Y%m%d-%H%M%S)"
    success "Created backup"
    
    # Remove the 'json' line since it's built-in to PHP 8.4
    sudo sed -i '/^[[:space:]]*json[[:space:]]*$/d' "$PHP_MODULE"
    
    success "Removed 'json' extension (built-in to PHP 8.4)"
}

# Also fix other potential built-in extensions
fix_builtin_extensions() {
    log "Checking for other built-in extensions that don't need explicit loading..."
    
    # List of extensions that are built-in to PHP 8.4 and don't need explicit loading
    local builtin_extensions=("json" "session" "filter")
    
    for ext in "${builtin_extensions[@]}"; do
        if grep -q "^[[:space:]]*$ext[[:space:]]*$" "$PHP_MODULE"; then
            warning "Removing built-in extension: $ext"
            sudo sed -i "/^[[:space:]]*$ext[[:space:]]*$/d" "$PHP_MODULE"
        fi
    done
    
    success "Cleaned up built-in extensions"
}

# Test the fix
test_php_module() {
    log "Testing PHP module syntax..."
    
    if nix-instantiate --parse "$PHP_MODULE" &>/dev/null; then
        success "PHP module syntax is valid"
    else
        error "PHP module still has syntax errors"
        nix-instantiate --parse "$PHP_MODULE" 2>&1 | head -10
        return 1
    fi
}

# Test full configuration
test_full_config() {
    log "Testing full configuration..."
    
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "🎉 Configuration is valid! JSON error fixed."
        echo ""
        echo "Ready to rebuild:"
        echo "  sudo nixos-rebuild switch --upgrade --impure"
    else
        warning "Configuration still has issues:"
        sudo nixos-rebuild dry-build 2>&1 | head -15
    fi
}

# Show what was fixed
show_fix_summary() {
    log "Fix summary..."
    echo ""
    echo "🔧 What was fixed:"
    echo "  - Removed 'json' extension (built-in to PHP 8.4)"
    echo "  - Removed other built-in extensions if present"
    echo ""
    echo "📋 PHP 8.4 built-in extensions (don't need explicit loading):"
    echo "  - json (JSON support)"
    echo "  - session (Session handling)"
    echo "  - filter (Input filtering)"
    echo "  - openssl (SSL/TLS support)"
    echo ""
    echo "✅ Extensions that still need explicit loading:"
    echo "  - mysqli (MySQL improved)"
    echo "  - pdo_mysql (PDO MySQL driver)"
    echo "  - mbstring (Multibyte string)"
    echo "  - gd (Image processing)"
    echo "  - curl (HTTP client)"
    echo "  - zip (ZIP archive)"
    echo "  - fileinfo (File information)"
    echo "  - intl (Internationalization)"
    echo "  - exif (EXIF data)"
}

# Main function
main() {
    echo "🔧 Fix PHP JSON Extension Error"
    echo "==============================="
    echo ""
    
    check_php_module
    show_problem
    
    echo "The 'json' extension is built-in to PHP 8.4 and doesn't need explicit loading."
    echo "This will remove it from the extensions list."
    echo ""
    
    read -p "Proceed with fix? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    fix_json_extension
    fix_builtin_extensions
    test_php_module
    test_full_config
    show_fix_summary
    
    echo ""
    echo "🎯 Next steps:"
    echo "1. Run: sudo nixos-rebuild switch --upgrade --impure"
    echo "2. Test PHP functionality"
    echo "3. Access your web services"
}

# Run main function
main "$@"