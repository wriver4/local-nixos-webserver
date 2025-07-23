#!/usr/bin/env bash

# Diagnose Modules-Only NixOS Configuration
# This script helps identify issues in a pure modules setup (no webserver.nix)

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

# Check current modules structure
check_modules_structure() {
    log "Checking modules-only structure..."
    echo ""
    echo "📁 /etc/nixos structure:"
    tree /etc/nixos 2>/dev/null || find /etc/nixos -type f -name "*.nix" | sort
    echo ""
}

# Check configuration.nix imports
check_main_imports() {
    log "Checking configuration.nix imports..."
    echo ""
    
    if [[ -f "/etc/nixos/configuration.nix" ]]; then
        echo "📄 configuration.nix imports:"
        grep -A 20 "imports.*=.*\[" /etc/nixos/configuration.nix | sed 's/^/  /' || echo "  No imports section found"
        echo ""
        
        # Check if all imported modules exist
        if grep -q "imports.*=.*\[" /etc/nixos/configuration.nix; then
            grep -o '\./[^"]*\.nix\|[^"]*\.nix' /etc/nixos/configuration.nix | while read -r import_path; do
                # Handle relative paths
                if [[ "$import_path" == ./* ]]; then
                    local full_path="/etc/nixos/${import_path#./}"
                else
                    local full_path="/etc/nixos/$import_path"
                fi
                
                if [[ -f "$full_path" ]]; then
                    success "Import exists: $import_path"
                else
                    error "Missing import: $import_path (looking for $full_path)"
                fi
            done
        fi
    else
        error "configuration.nix not found"
    fi
}

# Check each module's imports
check_module_imports() {
    log "Checking individual module imports..."
    echo ""
    
    find /etc/nixos/modules -name "*.nix" -type f 2>/dev/null | while read -r file; do
        if [[ -f "$file" ]]; then
            local module_name=$(basename "$file")
            echo "📄 $module_name:"
            
            if grep -q "imports.*=.*\[" "$file"; then
                grep -A 10 "imports.*=.*\[" "$file" | head -15 | sed 's/^/  /'
                
                # Check if imports exist
                grep -o '\./[^"]*\.nix\|[^"]*\.nix' "$file" 2>/dev/null | while read -r import_path; do
                    local base_dir=$(dirname "$file")
                    if [[ "$import_path" == ./* ]]; then
                        local full_path="$base_dir/${import_path#./}"
                    else
                        local full_path="$base_dir/$import_path"
                    fi
                    
                    if [[ -f "$full_path" ]]; then
                        success "  Import exists: $import_path"
                    else
                        error "  Missing import: $import_path (looking for $full_path)"
                    fi
                done
            else
                echo "  No imports"
            fi
            echo ""
        fi
    done
}

# Check for service conflicts
check_service_conflicts() {
    log "Checking for service conflicts..."
    echo ""
    
    # Check nginx
    local nginx_files=$(find /etc/nixos -name "*.nix" -type f -exec grep -l "services\.nginx.*=" {} \; 2>/dev/null)
    if [[ -n "$nginx_files" ]]; then
        local nginx_count=$(echo "$nginx_files" | wc -l)
        if [[ $nginx_count -gt 1 ]]; then
            warning "Nginx defined in $nginx_count files:"
            echo "$nginx_files" | sed 's/^/  /'
        else
            success "Nginx defined in 1 file: $(echo "$nginx_files" | head -1)"
        fi
    fi
    echo ""
    
    # Check MySQL
    local mysql_files=$(find /etc/nixos -name "*.nix" -type f -exec grep -l "services\.mysql.*=" {} \; 2>/dev/null)
    if [[ -n "$mysql_files" ]]; then
        local mysql_count=$(echo "$mysql_files" | wc -l)
        if [[ $mysql_count -gt 1 ]]; then
            warning "MySQL defined in $mysql_count files:"
            echo "$mysql_files" | sed 's/^/  /'
        else
            success "MySQL defined in 1 file: $(echo "$mysql_files" | head -1)"
        fi
    fi
    echo ""
    
    # Check PHP-FPM
    local php_files=$(find /etc/nixos -name "*.nix" -type f -exec grep -l "services\.phpfpm.*=" {} \; 2>/dev/null)
    if [[ -n "$php_files" ]]; then
        local php_count=$(echo "$php_files" | wc -l)
        if [[ $php_count -gt 1 ]]; then
            warning "PHP-FPM defined in $php_count files:"
            echo "$php_files" | sed 's/^/  /'
        else
            success "PHP-FPM defined in 1 file: $(echo "$php_files" | head -1)"
        fi
    fi
    echo ""
}

# Test individual modules
test_individual_modules() {
    log "Testing individual module syntax..."
    echo ""
    
    find /etc/nixos -name "*.nix" -type f | while read -r file; do
        if [[ -f "$file" ]]; then
            local module_name=$(basename "$file")
            if nix-instantiate --parse "$file" &>/dev/null; then
                success "$module_name - syntax OK"
            else
                error "$module_name - syntax ERROR"
                echo "  File: $file"
                nix-instantiate --parse "$file" 2>&1 | head -3 | sed 's/^/  /'
                echo ""
            fi
        fi
    done
}

# Check for problematic patterns
check_problematic_patterns() {
    log "Checking for problematic patterns..."
    echo ""
    
    # Check for services.phpfpm.enable
    local phpfpm_enable=$(find /etc/nixos -name "*.nix" -type f -exec grep -l "services\.phpfpm\.enable" {} \; 2>/dev/null)
    if [[ -n "$phpfpm_enable" ]]; then
        error "Found services.phpfpm.enable (this doesn't exist in NixOS):"
        echo "$phpfpm_enable" | sed 's/^/  /'
        echo ""
    fi
    
    # Check for circular references in imports
    find /etc/nixos -name "*.nix" -type f | while read -r file; do
        local file_name=$(basename "$file")
        if grep -q "$file_name" "$file" 2>/dev/null; then
            warning "Potential self-reference in $file"
        fi
    done
}

# Suggest minimal test
suggest_minimal_test() {
    log "Suggested minimal test approach..."
    echo ""
    echo "🔧 To isolate the recursion issue:"
    echo ""
    echo "1. **Create a minimal configuration.nix**:"
    echo "   - Comment out all module imports"
    echo "   - Test with: sudo nixos-rebuild dry-build"
    echo ""
    echo "2. **Add modules one by one**:"
    echo "   - Add one import at a time"
    echo "   - Test after each addition"
    echo "   - Identify which module causes the recursion"
    echo ""
    echo "3. **Common fixes**:"
    echo "   - Remove services.phpfpm.enable (doesn't exist)"
    echo "   - Use lib.mkDefault for conflicting services"
    echo "   - Check for circular imports between modules"
    echo ""
    echo "4. **Quick test commands**:"
    echo "   sudo nixos-rebuild dry-build --show-trace"
    echo "   (shows full error trace)"
}

# Show current imports tree
show_imports_tree() {
    log "Current imports tree..."
    echo ""
    
    if [[ -f "/etc/nixos/configuration.nix" ]]; then
        echo "📄 configuration.nix"
        grep -o '\./[^"]*\.nix\|modules/[^"]*\.nix' /etc/nixos/configuration.nix 2>/dev/null | while read -r import; do
            echo "  ├── $import"
            local full_path="/etc/nixos/${import#./}"
            if [[ -f "$full_path" ]]; then
                grep -o '\./[^"]*\.nix\|modules/[^"]*\.nix' "$full_path" 2>/dev/null | while read -r subimport; do
                    echo "  │   ├── $subimport"
                done
            fi
        done
    fi
}

# Main function
main() {
    echo "🔍 NixOS Modules-Only Configuration Diagnostic"
    echo "============================================="
    echo ""
    
    check_modules_structure
    check_main_imports
    check_module_imports
    check_service_conflicts
    check_problematic_patterns
    test_individual_modules
    show_imports_tree
    suggest_minimal_test
    
    echo ""
    echo "🎯 Next steps:"
    echo "1. Fix any syntax errors shown above"
    echo "2. Remove services.phpfpm.enable if found"
    echo "3. Test with minimal config first"
    echo "4. Add modules back one by one"
}

# Run main function
main "$@"