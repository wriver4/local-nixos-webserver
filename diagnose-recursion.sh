#!/usr/bin/env bash

# Diagnose Infinite Recursion in NixOS Configuration
# This script helps identify circular imports and conflicting definitions

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

# Check current structure
check_structure() {
    log "Checking current NixOS configuration structure..."
    echo ""
    echo "📁 /etc/nixos structure:"
    find /etc/nixos -name "*.nix" -type f | head -20
    echo ""
}

# Check for circular imports
check_imports() {
    log "Checking for potential circular imports..."
    echo ""
    
    # Find all .nix files and check their imports
    find /etc/nixos -name "*.nix" -type f | while read -r file; do
        if [[ -f "$file" ]]; then
            local imports=$(grep -n "imports.*=.*\[" "$file" 2>/dev/null || true)
            if [[ -n "$imports" ]]; then
                echo "📄 $file:"
                grep -A 10 "imports.*=.*\[" "$file" | head -15 | sed 's/^/  /'
                echo ""
            fi
        fi
    done
}

# Check for duplicate service definitions
check_duplicates() {
    log "Checking for duplicate service definitions..."
    echo ""
    
    # Check for multiple nginx definitions
    local nginx_count=$(find /etc/nixos -name "*.nix" -type f -exec grep -l "services\.nginx.*=" {} \; | wc -l)
    if [[ $nginx_count -gt 1 ]]; then
        warning "Found nginx defined in $nginx_count files:"
        find /etc/nixos -name "*.nix" -type f -exec grep -l "services\.nginx.*=" {} \;
        echo ""
    fi
    
    # Check for multiple mysql definitions
    local mysql_count=$(find /etc/nixos -name "*.nix" -type f -exec grep -l "services\.mysql.*=" {} \; | wc -l)
    if [[ $mysql_count -gt 1 ]]; then
        warning "Found mysql defined in $mysql_count files:"
        find /etc/nixos -name "*.nix" -type f -exec grep -l "services\.mysql.*=" {} \;
        echo ""
    fi
    
    # Check for multiple phpfpm definitions
    local php_count=$(find /etc/nixos -name "*.nix" -type f -exec grep -l "services\.phpfpm.*=" {} \; | wc -l)
    if [[ $php_count -gt 1 ]]; then
        warning "Found phpfpm defined in $php_count files:"
        find /etc/nixos -name "*.nix" -type f -exec grep -l "services\.phpfpm.*=" {} \;
        echo ""
    fi
}

# Test individual modules
test_modules() {
    log "Testing individual modules for syntax errors..."
    echo ""
    
    find /etc/nixos -name "*.nix" -type f | while read -r file; do
        if [[ -f "$file" ]]; then
            if nix-instantiate --parse "$file" &>/dev/null; then
                success "$(basename "$file") - syntax OK"
            else
                error "$(basename "$file") - syntax ERROR"
                echo "  File: $file"
                nix-instantiate --parse "$file" 2>&1 | head -5 | sed 's/^/  /'
                echo ""
            fi
        fi
    done
}

# Check for webserver.nix import issues
check_webserver_imports() {
    log "Checking webserver.nix imports..."
    echo ""
    
    if [[ -f "/etc/nixos/webserver.nix" ]]; then
        echo "📄 webserver.nix imports:"
        grep -A 20 "imports.*=.*\[" /etc/nixos/webserver.nix | sed 's/^/  /'
        echo ""
        
        # Check if all imported files exist
        grep -o '\./[^"]*\.nix' /etc/nixos/webserver.nix | while read -r import_path; do
            local full_path="/etc/nixos/${import_path#./}"
            if [[ -f "$full_path" ]]; then
                success "Import exists: $import_path"
            else
                error "Missing import: $import_path (looking for $full_path)"
            fi
        done
    else
        warning "webserver.nix not found"
    fi
}

# Check configuration.nix
check_main_config() {
    log "Checking main configuration.nix..."
    echo ""
    
    if [[ -f "/etc/nixos/configuration.nix" ]]; then
        echo "📄 configuration.nix imports:"
        grep -A 10 "imports.*=.*\[" /etc/nixos/configuration.nix | sed 's/^/  /'
        echo ""
    else
        error "configuration.nix not found"
    fi
}

# Suggest fixes
suggest_fixes() {
    log "Suggested fixes for infinite recursion:"
    echo ""
    echo "🔧 Common causes and fixes:"
    echo ""
    echo "1. **Circular imports**: Module A imports B, B imports A"
    echo "   Fix: Remove one of the imports or restructure"
    echo ""
    echo "2. **Duplicate service definitions**: Same service defined in multiple modules"
    echo "   Fix: Use lib.mkDefault in one and lib.mkForce in the other, or consolidate"
    echo ""
    echo "3. **Missing imported files**: Importing files that don't exist"
    echo "   Fix: Create missing files or remove imports"
    echo ""
    echo "4. **Self-referencing modules**: Module imports itself indirectly"
    echo "   Fix: Break the circular reference"
    echo ""
    echo "🚀 Quick fixes to try:"
    echo ""
    echo "1. Temporarily comment out webserver.nix import in configuration.nix"
    echo "2. Test with: sudo nixos-rebuild dry-build"
    echo "3. If that works, the issue is in webserver.nix or its imports"
    echo "4. Add imports back one by one to identify the problematic module"
}

# Main function
main() {
    echo "🔍 NixOS Infinite Recursion Diagnostic"
    echo "====================================="
    echo ""
    
    check_structure
    check_main_config
    check_webserver_imports
    check_imports
    check_duplicates
    test_modules
    suggest_fixes
    
    echo ""
    echo "🎯 Next steps:"
    echo "1. Review the output above for errors"
    echo "2. Fix any missing imports or circular references"
    echo "3. Remove duplicate service definitions"
    echo "4. Test with: sudo nixos-rebuild dry-build"
}

# Run main function
main "$@"