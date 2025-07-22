#!/usr/bin/env bash

# Enhanced NixOS Configuration Tree Analyzer
# This script thoroughly analyzes the entire NixOS configuration tree before making changes

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_CONFIG_DIR="/etc/nixos"
ANALYSIS_REPORT="/tmp/nixos-analysis-$(date +%Y%m%d-%H%M%S).txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$ANALYSIS_REPORT"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    echo "✅ $1" >> "$ANALYSIS_REPORT"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    echo "⚠️ $1" >> "$ANALYSIS_REPORT"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    echo "❌ $1" >> "$ANALYSIS_REPORT"
}

critical() {
    echo -e "${RED}🚨 CRITICAL: $1${NC}"
    echo "🚨 CRITICAL: $1" >> "$ANALYSIS_REPORT"
}

info() {
    echo -e "${PURPLE}ℹ️  $1${NC}"
    echo "ℹ️ $1" >> "$ANALYSIS_REPORT"
}

# Initialize analysis report
init_analysis_report() {
    cat > "$ANALYSIS_REPORT" << EOF
NixOS Configuration Tree Analysis Report
Generated: $(date)
System: $(hostname)
NixOS Version: $(nixos-version 2>/dev/null || echo "Unknown")

========================================
CONFIGURATION TREE ANALYSIS
========================================

EOF
}

# Detect configuration type (flake vs traditional)
detect_config_type() {
    log "Detecting NixOS configuration type..."
    
    local config_type="unknown"
    local flake_file=""
    local main_config=""
    
    # Check for flake.nix in various locations
    if [[ -f "$NIXOS_CONFIG_DIR/flake.nix" ]]; then
        config_type="flake"
        flake_file="$NIXOS_CONFIG_DIR/flake.nix"
        info "Found flake.nix at: $flake_file"
    elif [[ -f "/etc/nixos/flake.nix" ]]; then
        config_type="flake"
        flake_file="/etc/nixos/flake.nix"
        info "Found flake.nix at: $flake_file"
    fi
    
    # Check for traditional configuration.nix
    if [[ -f "$NIXOS_CONFIG_DIR/configuration.nix" ]]; then
        main_config="$NIXOS_CONFIG_DIR/configuration.nix"
        if [[ "$config_type" == "unknown" ]]; then
            config_type="traditional"
        fi
        info "Found configuration.nix at: $main_config"
    fi
    
    echo "CONFIG_TYPE=$config_type" >> "$ANALYSIS_REPORT"
    echo "FLAKE_FILE=$flake_file" >> "$ANALYSIS_REPORT"
    echo "MAIN_CONFIG=$main_config" >> "$ANALYSIS_REPORT"
    echo "" >> "$ANALYSIS_REPORT"
    
    case "$config_type" in
        "flake")
            success "Detected flake-based configuration"
            analyze_flake_configuration "$flake_file"
            ;;
        "traditional")
            success "Detected traditional configuration"
            analyze_traditional_configuration "$main_config"
            ;;
        *)
            critical "Could not detect configuration type!"
            return 1
            ;;
    esac
}

# Analyze flake-based configuration
analyze_flake_configuration() {
    local flake_file="$1"
    log "Analyzing flake-based configuration..."
    
    echo "FLAKE ANALYSIS:" >> "$ANALYSIS_REPORT"
    echo "===============" >> "$ANALYSIS_REPORT"
    
    # Parse flake.nix to find nixosConfigurations
    if [[ -f "$flake_file" ]]; then
        info "Parsing flake.nix for nixosConfigurations..."
        
        # Extract host configurations
        local hosts=$(grep -A 20 "nixosConfigurations" "$flake_file" | grep -E "^\s*[a-zA-Z0-9_-]+\s*=" | sed 's/[[:space:]]*=[[:space:]]*.*$//' | sed 's/^[[:space:]]*//')
        
        if [[ -n "$hosts" ]]; then
            info "Found host configurations:"
            while IFS= read -r host; do
                [[ -n "$host" ]] && info "  - $host"
                echo "HOST: $host" >> "$ANALYSIS_REPORT"
            done <<< "$hosts"
        fi
        
        # Find modules directory
        find_and_analyze_modules
        
        # Find host-specific configurations
        find_host_configurations
    fi
}

# Analyze traditional configuration
analyze_traditional_configuration() {
    local config_file="$1"
    log "Analyzing traditional configuration..."
    
    echo "TRADITIONAL ANALYSIS:" >> "$ANALYSIS_REPORT"
    echo "====================" >> "$ANALYSIS_REPORT"
    
    analyze_imports "$config_file"
    analyze_services "$config_file"
}

# Find and analyze modules
find_and_analyze_modules() {
    log "Searching for modules directory..."
    
    local modules_dirs=$(find "$NIXOS_CONFIG_DIR" -type d -name "modules" 2>/dev/null)
    
    if [[ -n "$modules_dirs" ]]; then
        while IFS= read -r modules_dir; do
            [[ -n "$modules_dir" ]] && analyze_modules_directory "$modules_dir"
        done <<< "$modules_dirs"
    else
        warning "No modules directory found"
    fi
}

# Analyze modules directory
analyze_modules_directory() {
    local modules_dir="$1"
    log "Analyzing modules directory: $modules_dir"
    
    echo "MODULES DIRECTORY: $modules_dir" >> "$ANALYSIS_REPORT"
    echo "================================" >> "$ANALYSIS_REPORT"
    
    # Find all .nix files in modules
    local nix_files=$(find "$modules_dir" -name "*.nix" -type f 2>/dev/null)
    
    if [[ -n "$nix_files" ]]; then
        info "Found module files:"
        while IFS= read -r nix_file; do
            if [[ -n "$nix_file" ]]; then
                local relative_path=${nix_file#$modules_dir/}
                info "  - $relative_path"
                echo "MODULE: $relative_path" >> "$ANALYSIS_REPORT"
                
                # Analyze each module for service conflicts
                analyze_module_services "$nix_file"
            fi
        done <<< "$nix_files"
    fi
}

# Find host configurations
find_host_configurations() {
    log "Searching for host-specific configurations..."
    
    local hosts_dirs=$(find "$NIXOS_CONFIG_DIR" -type d -name "hosts" 2>/dev/null)
    
    if [[ -n "$hosts_dirs" ]]; then
        while IFS= read -r hosts_dir; do
            [[ -n "$hosts_dir" ]] && analyze_hosts_directory "$hosts_dir"
        done <<< "$hosts_dirs"
    else
        warning "No hosts directory found"
    fi
}

# Analyze hosts directory
analyze_hosts_directory() {
    local hosts_dir="$1"
    log "Analyzing hosts directory: $hosts_dir"
    
    echo "HOSTS DIRECTORY: $hosts_dir" >> "$ANALYSIS_REPORT"
    echo "==============================" >> "$ANALYSIS_REPORT"
    
    # Find all .nix files in hosts
    local host_files=$(find "$hosts_dir" -name "*.nix" -type f 2>/dev/null)
    
    if [[ -n "$host_files" ]]; then
        info "Found host configurations:"
        while IFS= read -r host_file; do
            if [[ -n "$host_file" ]]; then
                local host_name=$(basename "$host_file" .nix)
                info "  - $host_name"
                echo "HOST_CONFIG: $host_name -> $host_file" >> "$ANALYSIS_REPORT"
                
                # Analyze each host configuration
                analyze_host_services "$host_file" "$host_name"
            fi
        done <<< "$host_files"
    fi
}

# Analyze imports in a configuration file
analyze_imports() {
    local config_file="$1"
    log "Analyzing imports in: $config_file"
    
    if [[ -f "$config_file" ]]; then
        local imports=$(grep -A 20 "imports.*=.*\[" "$config_file" | grep -E "^\s*\./.*\.nix" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        
        if [[ -n "$imports" ]]; then
            info "Found imports:"
            while IFS= read -r import_line; do
                if [[ -n "$import_line" ]]; then
                    info "  - $import_line"
                    echo "IMPORT: $import_line" >> "$ANALYSIS_REPORT"
                    
                    # Resolve and analyze imported file
                    local import_path=$(echo "$import_line" | sed 's/^[[:space:]]*\.\///' | sed 's/[[:space:]]*;[[:space:]]*$//')
                    local full_import_path="$(dirname "$config_file")/$import_path"
                    
                    if [[ -f "$full_import_path" ]]; then
                        analyze_services "$full_import_path"
                    else
                        warning "Import file not found: $full_import_path"
                    fi
                fi
            done <<< "$imports"
        fi
    fi
}

# Analyze services in a configuration file
analyze_services() {
    local config_file="$1"
    local context="${2:-$(basename "$config_file")}"
    
    if [[ ! -f "$config_file" ]]; then
        return
    fi
    
    log "Analyzing services in: $context"
    
    echo "SERVICES ANALYSIS: $context" >> "$ANALYSIS_REPORT"
    echo "===========================" >> "$ANALYSIS_REPORT"
    
    # Check for web server services
    check_service_definition "$config_file" "nginx" "$context"
    check_service_definition "$config_file" "apache" "$context"
    check_service_definition "$config_file" "phpfpm" "$context"
    
    # Check for database services
    check_service_definition "$config_file" "mysql" "$context"
    check_service_definition "$config_file" "mariadb" "$context"
    check_service_definition "$config_file" "postgresql" "$context"
    
    # Check for other common services
    check_service_definition "$config_file" "redis" "$context"
    check_service_definition "$config_file" "memcached" "$context"
    
    # Check for networking configuration
    check_networking_config "$config_file" "$context"
    
    echo "" >> "$ANALYSIS_REPORT"
}

# Analyze module services
analyze_module_services() {
    local module_file="$1"
    local module_name=$(basename "$module_file" .nix)
    
    analyze_services "$module_file" "module:$module_name"
}

# Analyze host services
analyze_host_services() {
    local host_file="$1"
    local host_name="$2"
    
    analyze_services "$host_file" "host:$host_name"
}

# Check for specific service definition
check_service_definition() {
    local config_file="$1"
    local service_name="$2"
    local context="$3"
    
    if grep -q "services\.$service_name" "$config_file"; then
        local service_lines=$(grep -n "services\.$service_name" "$config_file")
        
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local line_num=$(echo "$line" | cut -d: -f1)
                local line_content=$(echo "$line" | cut -d: -f2-)
                
                if echo "$line_content" | grep -q "enable.*=.*true"; then
                    warning "Service $service_name ENABLED in $context (line $line_num)"
                    echo "SERVICE_ENABLED: $service_name in $context at line $line_num" >> "$ANALYSIS_REPORT"
                elif echo "$line_content" | grep -q "package.*="; then
                    local package_def=$(echo "$line_content" | sed 's/.*package[[:space:]]*=[[:space:]]*//')
                    warning "Service $service_name package defined in $context: $package_def"
                    echo "SERVICE_PACKAGE: $service_name in $context -> $package_def" >> "$ANALYSIS_REPORT"
                else
                    info "Service $service_name referenced in $context (line $line_num)"
                    echo "SERVICE_REF: $service_name in $context at line $line_num" >> "$ANALYSIS_REPORT"
                fi
            fi
        done <<< "$service_lines"
    fi
}

# Check networking configuration
check_networking_config() {
    local config_file="$1"
    local context="$2"
    
    # Check for networking.hosts
    if grep -q "networking\.hosts" "$config_file"; then
        info "networking.hosts defined in $context"
        echo "NETWORKING_HOSTS: defined in $context" >> "$ANALYSIS_REPORT"
    fi
    
    # Check for networking.extraHosts
    if grep -q "networking\.extraHosts" "$config_file"; then
        info "networking.extraHosts defined in $context"
        echo "NETWORKING_EXTRAHOSTS: defined in $context" >> "$ANALYSIS_REPORT"
    fi
    
    # Check for firewall configuration
    if grep -q "networking\.firewall" "$config_file"; then
        info "networking.firewall configured in $context"
        echo "NETWORKING_FIREWALL: configured in $context" >> "$ANALYSIS_REPORT"
    fi
}

# Generate conflict report
generate_conflict_report() {
    log "Generating conflict analysis..."
    
    echo "" >> "$ANALYSIS_REPORT"
    echo "CONFLICT ANALYSIS:" >> "$ANALYSIS_REPORT"
    echo "==================" >> "$ANALYSIS_REPORT"
    
    # Analyze service conflicts
    local mysql_defs=$(grep "SERVICE_ENABLED: mysql\|SERVICE_PACKAGE: mysql" "$ANALYSIS_REPORT" | wc -l)
    local nginx_defs=$(grep "SERVICE_ENABLED: nginx\|SERVICE_PACKAGE: nginx" "$ANALYSIS_REPORT" | wc -l)
    local phpfpm_defs=$(grep "SERVICE_ENABLED: phpfpm\|SERVICE_PACKAGE: phpfpm" "$ANALYSIS_REPORT" | wc -l)
    
    if [[ $mysql_defs -gt 1 ]]; then
        critical "MySQL/MariaDB defined in multiple locations ($mysql_defs times)"
        echo "CONFLICT: MySQL defined $mysql_defs times" >> "$ANALYSIS_REPORT"
    fi
    
    if [[ $nginx_defs -gt 1 ]]; then
        critical "Nginx defined in multiple locations ($nginx_defs times)"
        echo "CONFLICT: Nginx defined $nginx_defs times" >> "$ANALYSIS_REPORT"
    fi
    
    if [[ $phpfpm_defs -gt 1 ]]; then
        critical "PHP-FPM defined in multiple locations ($phpfpm_defs times)"
        echo "CONFLICT: PHP-FPM defined $phpfpm_defs times" >> "$ANALYSIS_REPORT"
    fi
    
    # Check for networking conflicts
    local hosts_defs=$(grep "NETWORKING_HOSTS:\|NETWORKING_EXTRAHOSTS:" "$ANALYSIS_REPORT" | wc -l)
    if [[ $hosts_defs -gt 1 ]]; then
        warning "Multiple networking hosts configurations found ($hosts_defs)"
        echo "CONFLICT: Multiple networking hosts configs" >> "$ANALYSIS_REPORT"
    fi
}

# Generate recommendations
generate_recommendations() {
    log "Generating recommendations..."
    
    echo "" >> "$ANALYSIS_REPORT"
    echo "RECOMMENDATIONS:" >> "$ANALYSIS_REPORT"
    echo "================" >> "$ANALYSIS_REPORT"
    
    # Check if this is a flake-based setup
    if grep -q "CONFIG_TYPE=flake" "$ANALYSIS_REPORT"; then
        echo "RECOMMENDATION: Use lib.mkDefault for service packages to allow overrides" >> "$ANALYSIS_REPORT"
        echo "RECOMMENDATION: Place web server config in a dedicated module" >> "$ANALYSIS_REPORT"
        echo "RECOMMENDATION: Use host-specific networking configuration" >> "$ANALYSIS_REPORT"
    fi
    
    # Service-specific recommendations
    if grep -q "CONFLICT: MySQL" "$ANALYSIS_REPORT"; then
        echo "RECOMMENDATION: Consolidate MySQL configuration or use lib.mkForce" >> "$ANALYSIS_REPORT"
    fi
    
    if grep -q "CONFLICT: Nginx" "$ANALYSIS_REPORT"; then
        echo "RECOMMENDATION: Merge nginx virtual hosts or use separate modules" >> "$ANALYSIS_REPORT"
    fi
}

# Display analysis summary
display_summary() {
    echo ""
    echo "========================================="
    echo "CONFIGURATION TREE ANALYSIS COMPLETE"
    echo "========================================="
    echo ""
    
    # Count conflicts
    local conflicts=$(grep "CONFLICT:" "$ANALYSIS_REPORT" | wc -l)
    local warnings=$(grep "⚠️" "$ANALYSIS_REPORT" | wc -l)
    local criticals=$(grep "🚨 CRITICAL:" "$ANALYSIS_REPORT" | wc -l)
    
    if [[ $criticals -gt 0 ]]; then
        critical "Found $criticals critical issues"
    fi
    
    if [[ $conflicts -gt 0 ]]; then
        warning "Found $conflicts potential conflicts"
    fi
    
    if [[ $warnings -gt 0 ]]; then
        info "Found $warnings warnings"
    fi
    
    if [[ $criticals -eq 0 && $conflicts -eq 0 ]]; then
        success "No critical conflicts detected"
    fi
    
    echo ""
    info "Full analysis report saved to: $ANALYSIS_REPORT"
    echo ""
    
    # Ask if user wants to see the report
    read -p "Would you like to view the full analysis report? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        less "$ANALYSIS_REPORT"
    fi
}

# Main analysis function
main() {
    echo "🔍 NixOS Configuration Tree Analyzer"
    echo "====================================="
    echo ""
    
    init_analysis_report
    detect_config_type
    generate_conflict_report
    generate_recommendations
    display_summary
    
    echo "Analysis complete. Review the report before proceeding with installation."
}

# Run main function
main "$@"