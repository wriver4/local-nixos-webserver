#!/usr/bin/env bash


# Enhanced NixOS Configuration Structure Analyzer
# Recursively analyzes both flake.nix and configuration.nix import patterns

set -e

NIXOS_DIR="/etc/nixos"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Global tracking arrays
declare -a PROCESSED_FILES=()
declare -a FOUND_IMPORTS=()
declare -a FLAKE_MODULES=()
declare -a CONFIG_CONFLICTS=()
declare -a IMPORT_CHAIN=()

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
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

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

highlight() {
    echo -e "${MAGENTA}🔍 $1${NC}"
}

# Check if NixOS directory exists and is accessible
check_nixos_access() {
    if [[ ! -d "$NIXOS_DIR" ]]; then
        error "NixOS configuration directory not found at $NIXOS_DIR"
        return 1
    fi
    
    if [[ ! -r "$NIXOS_DIR" ]]; then
        error "Cannot read NixOS configuration directory. Run with sudo if needed."
        return 1
    fi
    
    success "NixOS configuration directory accessible"
    return 0
}

# Recursive flake.nix analysis with enhanced tracking
analyze_flake_recursive() {
    local flake_file="$1"
    local depth="${2:-0}"
    local parent="${3:-root}"
    local indent=""
    
    # Create indentation for nested analysis
    for ((i=0; i<depth; i++)); do
        indent+="  "
    done
    
    if [[ ! -f "$flake_file" ]]; then
        warning "${indent}📦 $(basename "$flake_file") - File not found"
        return 1
    fi
    
    # Check if already processed to prevent infinite loops
    local abs_file=$(realpath "$flake_file" 2>/dev/null || echo "$flake_file")
    for processed in "${PROCESSED_FILES[@]}"; do
        if [[ "$processed" == "$abs_file" ]]; then
            info "${indent}↻ $(basename "$flake_file") (already analyzed)"
            return 0
        fi
    done
    PROCESSED_FILES+=("$abs_file")
    IMPORT_CHAIN+=("$abs_file")
    
    highlight "${indent}📦 Analyzing flake: $(basename "$flake_file") (from: $parent)"
    
    # Extract flake inputs and analyze local paths
    local inputs_section=$(sed -n '/inputs = {/,/};/p' "$flake_file" 2>/dev/null)
    if [[ -n "$inputs_section" ]]; then
        echo "${indent}  📥 Flake Inputs:"
        echo "$inputs_section" | grep -E '^\s*[a-zA-Z][a-zA-Z0-9_-]*\s*=' | while IFS= read -r input_line; do
            local input_name=$(echo "$input_line" | sed 's/^\s*//' | cut -d'=' -f1 | tr -d ' ')
            local input_value=$(echo "$input_line" | cut -d'=' -f2- | tr -d ' ";')
            
            echo "${indent}    • $input_name = $input_value"
            
            # Check for local path inputs
            if echo "$input_line" | grep -q "path:"; then
                local local_path=$(echo "$input_line" | sed 's/.*path:\s*"\([^"]*\)".*/\1/')
                local full_path="$(dirname "$flake_file")/$local_path"
                if [[ -f "$full_path/flake.nix" ]]; then
                    echo "${indent}      🔗 Local flake dependency found"
                    analyze_flake_recursive "$full_path/flake.nix" $((depth + 2)) "$(basename "$flake_file")"
                fi
            fi
        done
        echo
    fi
    
    # Extract nixosConfigurations and their modules
    local nixos_configs=$(sed -n '/nixosConfigurations/,/};/p' "$flake_file" 2>/dev/null)
    if [[ -n "$nixos_configs" ]]; then
        echo "${indent}  🖥️  NixOS Configurations:"
        
        # Find configuration names
        echo "$nixos_configs" | grep -E '^\s*[a-zA-Z][a-zA-Z0-9_-]*\s*=' | while IFS= read -r config_line; do
            local config_name=$(echo "$config_line" | sed 's/^\s*//' | cut -d'=' -f1 | tr -d ' ')
            echo "${indent}    📋 Configuration: $config_name"
        done
        
        # Find modules in nixosConfigurations
        echo "${indent}    📦 Modules:"
        echo "$nixos_configs" | grep -E 'modules\s*=\s*\[' -A 50 | grep -E '\./|\.nix|/' | while IFS= read -r module_line; do
            local clean_module=$(echo "$module_line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/[";,]//g')
            
            if [[ "$clean_module" =~ ^\./.*\.nix$ ]]; then
                # Relative path import
                local module_file="$(dirname "$flake_file")/$clean_module"
                echo "${indent}      ├─ $clean_module"
                FLAKE_MODULES+=("$module_file")
                
                # Recursively analyze configuration modules
                if [[ -f "$module_file" ]]; then
                    analyze_configuration_recursive "$module_file" $((depth + 3)) "flake:$(basename "$flake_file")"
                fi
            elif [[ "$clean_module" =~ ^/.*\.nix$ ]]; then
                # Absolute path import
                echo "${indent}      ├─ $clean_module (absolute)"
                FLAKE_MODULES+=("$clean_module")
                if [[ -f "$clean_module" ]]; then
                    analyze_configuration_recursive "$clean_module" $((depth + 3)) "flake:$(basename "$flake_file")"
                fi
            elif [[ -n "$clean_module" && "$clean_module" != "modules = [" && "$clean_module" != "];" ]]; then
                echo "${indent}      ├─ $clean_module"
            fi
        done
        echo
    fi
    
    # Check for other flake references
    local other_flakes=$(grep -n "flake:" "$flake_file" 2>/dev/null || true)
    if [[ -n "$other_flakes" ]]; then
        echo "${indent}  🔗 Other flake references:"
        echo "$other_flakes" | while IFS= read -r flake_ref; do
            echo "${indent}    • $flake_ref"
        done
        echo
    fi
    
    return 0
}

# Enhanced recursive configuration.nix analysis
analyze_configuration_recursive() {
    local config_file="$1"
    local depth="${2:-0}"
    local parent="${3:-root}"
    local indent=""
    
    # Create indentation for nested analysis
    for ((i=0; i<depth; i++)); do
        indent+="  "
    done
    
    if [[ ! -f "$config_file" ]]; then
        warning "${indent}📄 $(basename "$config_file") - File not found"
        return 1
    fi
    
    # Check if already processed to prevent infinite loops
    local abs_file=$(realpath "$config_file" 2>/dev/null || echo "$config_file")
    for processed in "${PROCESSED_FILES[@]}"; do
        if [[ "$processed" == "$abs_file" ]]; then
            info "${indent}↻ $(basename "$config_file") (already analyzed)"
            return 0
        fi
    done
    PROCESSED_FILES+=("$abs_file")
    IMPORT_CHAIN+=("$abs_file")
    
    highlight "${indent}📄 Analyzing config: $(basename "$config_file") (from: $parent)"
    
    # Extract imports section with enhanced parsing
    local imports_section=$(sed -n '/imports = \[/,/\];/p' "$config_file" 2>/dev/null)
    
    if [[ -z "$imports_section" ]]; then
        info "${indent}  ℹ️  No imports section found"
    else
        echo "${indent}  📋 Imports found:"
        
        # Parse individual imports recursively with better detection
        echo "$imports_section" | grep -E '\./|\.nix|<|/' | while IFS= read -r import_line; do
            local clean_import=$(echo "$import_line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/[";,]//g')
            
            # Skip empty lines and structural elements
            if [[ -z "$clean_import" || "$clean_import" == "imports = [" || "$clean_import" == "];" ]]; then
                continue
            fi
            
            if [[ "$clean_import" =~ ^\./.*\.nix$ ]]; then
                # Relative path import
                local import_file="$(dirname "$config_file")/$clean_import"
                echo "${indent}    ├─ $clean_import"
                FOUND_IMPORTS+=("$import_file")
                analyze_configuration_recursive "$import_file" $((depth + 2)) "$(basename "$config_file")"
                
            elif [[ "$clean_import" =~ ^/.*\.nix$ ]]; then
                # Absolute path import
                echo "${indent}    ├─ $clean_import (absolute)"
                FOUND_IMPORTS+=("$clean_import")
                analyze_configuration_recursive "$clean_import" $((depth + 2)) "$(basename "$config_file")"
                
            elif [[ "$clean_import" =~ ^\<.*\>$ ]]; then
                # Channel import
                echo "${indent}    ├─ $clean_import (channel import)"
                
            elif [[ "$clean_import" =~ ^[a-zA-Z] ]]; then
                # Other import types (functions, etc.)
                echo "${indent}    ├─ $clean_import (function/expression)"
            fi
        done
    fi
    
    # Enhanced web server configuration detection
    check_webserver_conflicts "$config_file" "$indent"
    
    # Check for other interesting configurations
    check_system_configurations "$config_file" "$indent"
    
    echo
    return 0
}

# Enhanced web server conflict detection
check_webserver_conflicts() {
    local file="$1"
    local indent="$2"
    
    local conflicts_found=false
    
    if grep -q "services\.nginx" "$file"; then
        warning "${indent}  🌐 nginx configuration detected"
        CONFIG_CONFLICTS+=("nginx in $(basename "$file")")
        conflicts_found=true
        
        # Show nginx virtualHosts if present
        local vhosts=$(grep -A 5 "virtualHosts" "$file" 2>/dev/null || true)
        if [[ -n "$vhosts" ]]; then
            echo "${indent}    📋 Virtual hosts found"
        fi
    fi
    
    if grep -q "services\.apache" "$file"; then
        warning "${indent}  🌐 apache configuration detected"
        CONFIG_CONFLICTS+=("apache in $(basename "$file")")
        conflicts_found=true
    fi
    
    if grep -q "services\.phpfpm" "$file"; then
        warning "${indent}  🐘 PHP-FPM configuration detected"
        CONFIG_CONFLICTS+=("phpfpm in $(basename "$file")")
        conflicts_found=true
        
        # Check PHP version
        local php_version=$(grep -o "php[0-9][0-9]" "$file" 2>/dev/null | head -1 || true)
        if [[ -n "$php_version" ]]; then
            echo "${indent}    📋 PHP version: $php_version"
        fi
    fi
    
    if grep -q "services\.mysql\|services\.mariadb\|services\.postgresql" "$file"; then
        warning "${indent}  🗄️  Database configuration detected"
        CONFIG_CONFLICTS+=("database in $(basename "$file")")
        conflicts_found=true
    fi
    
    if [[ "$conflicts_found" == false ]]; then
        info "${indent}  ✅ No web server conflicts in this file"
    fi
}

# Check for other system configurations
check_system_configurations() {
    local file="$1"
    local indent="$2"
    
    # Check for firewall configuration
    if grep -q "networking\.firewall" "$file"; then
        info "${indent}  🔥 Firewall configuration found"
    fi
    
    # Check for user configurations
    if grep -q "users\.users" "$file"; then
        info "${indent}  👤 User configurations found"
    fi
    
    # Check for system packages
    if grep -q "environment\.systemPackages" "$file"; then
        info "${indent}  📦 System packages defined"
    fi
}

# Generate comprehensive import chain visualization
visualize_import_chain() {
    echo
    log "🗺️  Import Chain Visualization:"
    echo "=============================="
    
    local chain_file="/tmp/nixos-import-chain.txt"
    
    echo "# NixOS Configuration Import Chain" > "$chain_file"
    echo "# Generated on $(date)" >> "$chain_file"
    echo >> "$chain_file"
    
    for ((i=0; i<${#IMPORT_CHAIN[@]}; i++)); do
        local file="${IMPORT_CHAIN[$i]}"
        local rel_path=$(realpath --relative-to="$NIXOS_DIR" "$file" 2>/dev/null || echo "$file")
        local depth=$((i))
        local indent=""
        
        for ((j=0; j<depth; j++)); do
            indent+="  "
        done
        
        echo "${indent}📄 $rel_path"
        echo "${indent}📄 $rel_path" >> "$chain_file"
    done
    
    echo
    info "Import chain saved to: $chain_file"
}

# Comprehensive NixOS structure analysis
analyze_nixos_structure() {
    log "🔍 Starting comprehensive NixOS structure analysis with recursive import following..."
    
    # Reset global arrays
    PROCESSED_FILES=()
    FOUND_IMPORTS=()
    FLAKE_MODULES=()
    CONFIG_CONFLICTS=()
    IMPORT_CHAIN=()
    
    local has_flake=false
    local has_config=false
    
    echo
    
    # Check for flake.nix first
    if [[ -f "$NIXOS_DIR/flake.nix" ]]; then
        has_flake=true
        success "📦 Flake-based NixOS configuration detected"
        echo "========================================"
        analyze_flake_recursive "$NIXOS_DIR/flake.nix"
    fi
    
    # Check for configuration.nix (can coexist with flakes)
    if [[ -f "$NIXOS_DIR/configuration.nix" ]]; then
        has_config=true
        success "📄 Traditional configuration.nix detected"
        echo "========================================"
        analyze_configuration_recursive "$NIXOS_DIR/configuration.nix"
    fi
    
    # Scan for additional .nix files not yet processed
    log "🔍 Scanning for additional .nix files..."
    find "$NIXOS_DIR" -name "*.nix" -type f ! -name "flake.nix" ! -name "configuration.nix" 2>/dev/null | while read -r nix_file; do
        local rel_path=$(realpath --relative-to="$NIXOS_DIR" "$nix_file")
        
        # Skip if already processed
        local abs_file=$(realpath "$nix_file")
        local already_processed=false
        for processed in "${PROCESSED_FILES[@]}"; do
            if [[ "$processed" == "$abs_file" ]]; then
                already_processed=true
                break
            fi
        done
        
        if [[ "$already_processed" == false ]]; then
            info "📄 Orphaned file: $rel_path"
            analyze_configuration_recursive "$nix_file" 1 "orphaned"
        fi
    done
    
    # Generate import chain visualization
    visualize_import_chain
    
    # Comprehensive summary
    echo
    log "📊 Comprehensive Analysis Summary:"
    echo "================================="
    
    if [[ "$has_flake" == true ]]; then
        success "✅ Flake-based system detected"
        info "   Flake modules found: ${#FLAKE_MODULES[@]}"
        info "   Integration method: Add to flake modules"
        info "   Rebuild command: nixos-rebuild switch --flake ."
    fi
    
    if [[ "$has_config" == true ]]; then
        success "✅ Traditional configuration system detected"
        info "   Integration method: Add to imports"
        info "   Rebuild command: nixos-rebuild switch"
    fi
    
    info "📋 Total imports analyzed: ${#FOUND_IMPORTS[@]}"
    info "📄 Configuration files processed: ${#PROCESSED_FILES[@]}"
    
    if [[ ${#CONFIG_CONFLICTS[@]} -gt 0 ]]; then
        warning "⚠️  Potential conflicts detected (${#CONFIG_CONFLICTS[@]}):"
        for conflict in "${CONFIG_CONFLICTS[@]}"; do
            echo "     • $conflict"
        done
        echo
        warning "   Integration will require conflict resolution"
    else
        success "✅ No web server conflicts detected"
        success "   Safe to proceed with installation"
    fi
    
    echo
}

# Generate detailed integration recommendations
generate_integration_recommendations() {
    echo
    log "💡 Detailed Integration Recommendations:"
    echo "======================================="
    
    if [[ -f "$NIXOS_DIR/flake.nix" ]]; then
        echo "🔧 For Flake-based Installation:"
        echo "  1. Add webserver.nix to flake modules list"
        echo "  2. Update flake.nix nixosConfigurations"
        echo "  3. Use 'nixos-rebuild switch --flake .' for rebuilds"
        echo
        echo "📝 Example flake.nix integration:"
        cat << 'EOF'
  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        ./webserver.nix  # Add this line
      ];
    };
  };
EOF
        echo
    fi
    
    if [[ -f "$NIXOS_DIR/configuration.nix" ]]; then
        echo "🔧 For Traditional Configuration:"
        echo "  1. Add './webserver.nix' to imports in configuration.nix"
        echo "  2. Use 'sudo nixos-rebuild switch' for rebuilds"
        echo "  3. Backup existing configuration before changes"
        echo
        echo "📝 Example configuration.nix integration:"
        cat << 'EOF'
  imports = [
    ./hardware-configuration.nix
    ./webserver.nix  # Add this line
  ];
EOF
        echo
    fi
    
    echo "🛡️  Safety Recommendations:"
    echo "  • Always backup configuration before changes"
    echo "  • Test with 'nixos-rebuild dry-build' first"
    echo "  • Use 'nixos-rebuild switch --rollback' if issues occur"
    echo "  • Keep webserver configuration in separate module for maintainability"
    echo
    
    if [[ ${#CONFIG_CONFLICTS[@]} -gt 0 ]]; then
        echo "⚠️  Conflict Resolution Required:"
        echo "  The following conflicts need attention:"
        for conflict in "${CONFIG_CONFLICTS[@]}"; do
            echo "    • $conflict"
        done
        echo
        echo "  Resolution steps:"
        echo "    1. Backup existing web server configurations"
        echo "    2. Merge existing virtualHosts with new webserver module"
        echo "    3. Resolve port conflicts (80, 443, 3306)"
        echo "    4. Test incrementally with dry-build"
        echo
    fi
    
    echo "🚀 PHP 8.4 Specific Considerations:"
    echo "  • Requires NixOS 25.05 or later channel"
    echo "  • Check current channel: nix-channel --list"
    echo "  • Upgrade if needed: sudo nix-channel --add https://nixos.org/channels/nixos-25.05 nixos"
    echo "  • Update channels: sudo nix-channel --update"
}

# Main analysis function
main() {
    echo "🔍 Enhanced NixOS Configuration Structure Analysis"
    echo "Recursive Import Following for Flake and Traditional Systems"
    echo "==========================================================="
    echo
    
    if ! check_nixos_access; then
        exit 1
    fi
    
    analyze_nixos_structure
    generate_integration_recommendations
    
    echo
    success "🎉 Analysis complete!"
    echo
    info "Use this information to properly integrate the webserver module into your existing NixOS configuration."
    echo "Run the installation script with this analysis for optimal integration."
}

# Run analysis
main "$@"
