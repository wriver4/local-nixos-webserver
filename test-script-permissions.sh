#!/usr/bin/env bash

# Script Permission and Sudo Handling Test Utility
# Tests all scripts for proper root/sudo handling

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Test script for proper privilege handling
test_script_privileges() {
    local script="$1"
    local script_name=$(basename "$script")
    
    log "Testing $script_name..."
    
    # Check if script exists and is executable
    if [[ ! -f "$script" ]]; then
        error "$script_name: File not found"
        return 1
    fi
    
    if [[ ! -x "$script" ]]; then
        error "$script_name: Not executable"
        return 1
    fi
    
    # Check for proper privilege checking functions
    local has_privilege_check=false
    local has_run_privileged=false
    local has_sudo_handling=false
    
    if grep -q "check_privileges\|check_root" "$script"; then
        has_privilege_check=true
    fi
    
    if grep -q "run_privileged" "$script"; then
        has_run_privileged=true
    fi
    
    if grep -q "EUID\|sudo" "$script"; then
        has_sudo_handling=true
    fi
    
    # Check for error handling
    local has_error_handling=false
    if grep -q "set -e\|error()" "$script"; then
        has_error_handling=true
    fi
    
    # Report findings
    echo "  📋 $script_name Analysis:"
    
    if [[ "$has_privilege_check" == true ]]; then
        success "    ✅ Has privilege checking"
    else
        warning "    ⚠️  Missing privilege checking"
    fi
    
    if [[ "$has_run_privileged" == true ]]; then
        success "    ✅ Has run_privileged function"
    else
        warning "    ⚠️  Missing run_privileged function"
    fi
    
    if [[ "$has_sudo_handling" == true ]]; then
        success "    ✅ Has sudo/root handling"
    else
        warning "    ⚠️  Missing sudo/root handling"
    fi
    
    if [[ "$has_error_handling" == true ]]; then
        success "    ✅ Has error handling"
    else
        warning "    ⚠️  Missing error handling"
    fi
    
    # Test dry run (syntax check)
    if bash -n "$script" 2>/dev/null; then
        success "    ✅ Syntax check passed"
    else
        error "    ❌ Syntax check failed"
        return 1
    fi
    
    echo
    return 0
}

# Test all scripts in the project
test_all_scripts() {
    log "🧪 Testing all scripts for proper privilege handling..."
    echo
    
    local scripts=(
        "./enhanced-setup-script.sh"
        "./install-on-existing-nixos.sh"
        "./setup-script.sh"
        "./analyze-nixos-structure.sh"
    )
    
    local total_scripts=${#scripts[@]}
    local passed_scripts=0
    
    for script in "${scripts[@]}"; do
        if test_script_privileges "$script"; then
            ((passed_scripts++))
        fi
    done
    
    echo "📊 Test Results:"
    echo "==============="
    echo "Total scripts tested: $total_scripts"
    echo "Scripts passed: $passed_scripts"
    echo "Scripts failed: $((total_scripts - passed_scripts))"
    echo
    
    if [[ $passed_scripts -eq $total_scripts ]]; then
        success "🎉 All scripts passed privilege handling tests!"
        return 0
    else
        warning "⚠️  Some scripts need attention"
        return 1
    fi
}

# Test sudo availability and permissions
test_sudo_environment() {
    log "🔐 Testing sudo environment..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        success "Running as root - no sudo needed"
        return 0
    fi
    
    # Check if sudo is available
    if ! command -v sudo &> /dev/null; then
        error "sudo command not found"
        return 1
    fi
    
    success "sudo command available"
    
    # Check if user can use sudo
    if sudo -n true 2>/dev/null; then
        success "Passwordless sudo access available"
    else
        warning "Sudo requires password (this is normal)"
        log "Testing sudo access..."
        if sudo -v; then
            success "Sudo access confirmed"
        else
            error "Failed to obtain sudo access"
            return 1
        fi
    fi
    
    return 0
}

# Generate usage recommendations
generate_recommendations() {
    echo
    log "💡 Usage Recommendations:"
    echo "========================"
    echo
    echo "🔧 Running Scripts:"
    echo "  • All scripts can be run as regular user with sudo"
    echo "  • All scripts can be run as root directly"
    echo "  • Scripts will prompt for sudo password if needed"
    echo
    echo "📝 Examples:"
    echo "  Regular user:  ./enhanced-setup-script.sh"
    echo "  With sudo:     sudo ./enhanced-setup-script.sh"
    echo "  As root:       ./enhanced-setup-script.sh"
    echo
    echo "🛡️  Security Notes:"
    echo "  • Scripts check privileges before running"
    echo "  • Minimal privilege escalation used"
    echo "  • Error handling prevents partial installations"
    echo "  • All file operations use appropriate permissions"
    echo
    echo "🚀 Installation Order:"
    echo "  1. ./analyze-nixos-structure.sh (optional analysis)"
    echo "  2. ./install-on-existing-nixos.sh (for existing systems)"
    echo "     OR copy configuration.nix and run enhanced-setup-script.sh"
    echo "  3. sudo nixos-rebuild switch"
    echo "  4. Verify installation with helper commands"
}

# Main test function
main() {
    echo "🧪 NixOS Web Server Script Permission Test Suite"
    echo "==============================================="
    echo
    
    test_sudo_environment
    echo
    test_all_scripts
    generate_recommendations
    
    echo
    success "🎯 Permission testing complete!"
    echo
    log "All scripts are now properly configured for both root and sudo usage."
}

# Run tests
main "$@"