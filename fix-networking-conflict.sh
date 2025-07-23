#!/usr/bin/env bash

# Fix Networking Conflict Between hardware-configuration.nix and networking.nix
# This script identifies and resolves lib.mkDefault conflicts

set -e  # Exit on any error

NIXOS_CONFIG_DIR="/etc/nixos"
HARDWARE_CONFIG="$NIXOS_CONFIG_DIR/hardware-configuration.nix"
NETWORKING_CONFIG="$NIXOS_CONFIG_DIR/modules/networking.nix"

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

# Check if files exist
check_files() {
    log "Checking for configuration files..."
    
    if [[ ! -f "$HARDWARE_CONFIG" ]]; then
        error "hardware-configuration.nix not found at $HARDWARE_CONFIG"
    fi
    success "Found hardware-configuration.nix"
    
    if [[ ! -f "$NETWORKING_CONFIG" ]]; then
        error "networking.nix not found at $NETWORKING_CONFIG"
    fi
    success "Found networking.nix"
}

# Analyze networking conflicts
analyze_conflicts() {
    log "Analyzing networking conflicts..."
    echo ""
    
    echo "🔍 Networking options in hardware-configuration.nix:"
    grep -n "networking\." "$HARDWARE_CONFIG" | sed 's/^/  /' || echo "  No networking options found"
    echo ""
    
    echo "🔍 Networking options in networking.nix:"
    grep -n "networking\." "$NETWORKING_CONFIG" | sed 's/^/  /' || echo "  No networking options found"
    echo ""
    
    # Check for specific conflicts
    echo "🔍 Checking for common conflicts:"
    
    # Check useDHCP
    local hw_dhcp=$(grep -c "networking\.useDHCP" "$HARDWARE_CONFIG" 2>/dev/null || echo "0")
    local net_dhcp=$(grep -c "networking\.useDHCP" "$NETWORKING_CONFIG" 2>/dev/null || echo "0")
    if [[ $hw_dhcp -gt 0 && $net_dhcp -gt 0 ]]; then
        warning "networking.useDHCP defined in both files"
        echo "  hardware-configuration.nix: $(grep "networking\.useDHCP" "$HARDWARE_CONFIG")"
        echo "  networking.nix: $(grep "networking\.useDHCP" "$NETWORKING_CONFIG")"
        echo ""
    fi
    
    # Check interfaces
    local hw_interfaces=$(grep -c "networking\.interfaces" "$HARDWARE_CONFIG" 2>/dev/null || echo "0")
    local net_interfaces=$(grep -c "networking\.interfaces" "$NETWORKING_CONFIG" 2>/dev/null || echo "0")
    if [[ $hw_interfaces -gt 0 && $net_interfaces -gt 0 ]]; then
        warning "networking.interfaces defined in both files"
        echo "  hardware-configuration.nix: $(grep "networking\.interfaces" "$HARDWARE_CONFIG")"
        echo "  networking.nix: $(grep "networking\.interfaces" "$NETWORKING_CONFIG")"
        echo ""
    fi
    
    # Check networkmanager
    local hw_nm=$(grep -c "networking\.networkmanager" "$HARDWARE_CONFIG" 2>/dev/null || echo "0")
    local net_nm=$(grep -c "networking\.networkmanager" "$NETWORKING_CONFIG" 2>/dev/null || echo "0")
    if [[ $hw_nm -gt 0 && $net_nm -gt 0 ]]; then
        warning "networking.networkmanager defined in both files"
        echo "  hardware-configuration.nix: $(grep "networking\.networkmanager" "$HARDWARE_CONFIG")"
        echo "  networking.nix: $(grep "networking\.networkmanager" "$NETWORKING_CONFIG")"
        echo ""
    fi
}

# Fix networking conflicts
fix_conflicts() {
    log "Fixing networking conflicts..."
    
    # Create backup
    sudo cp "$NETWORKING_CONFIG" "$NETWORKING_CONFIG.backup-$(date +%Y%m%d-%H%M%S)"
    success "Created backup of networking.nix"
    
    # Remove conflicting options from networking.nix that should be in hardware-configuration.nix
    log "Removing hardware-specific networking options from networking.nix..."
    
    # Remove useDHCP if it conflicts
    if grep -q "networking\.useDHCP" "$HARDWARE_CONFIG" && grep -q "networking\.useDHCP" "$NETWORKING_CONFIG"; then
        warning "Removing networking.useDHCP from networking.nix (keeping hardware-configuration.nix version)"
        sudo sed -i '/networking\.useDHCP/d' "$NETWORKING_CONFIG"
    fi
    
    # Remove interfaces if it conflicts
    if grep -q "networking\.interfaces" "$HARDWARE_CONFIG" && grep -q "networking\.interfaces" "$NETWORKING_CONFIG"; then
        warning "Removing networking.interfaces from networking.nix (keeping hardware-configuration.nix version)"
        sudo sed -i '/networking\.interfaces/,/^[[:space:]]*};/d' "$NETWORKING_CONFIG"
    fi
    
    # Keep networkmanager in networking.nix but use mkForce if needed
    if grep -q "networking\.networkmanager" "$HARDWARE_CONFIG" && grep -q "networking\.networkmanager" "$NETWORKING_CONFIG"; then
        warning "Converting networking.networkmanager to lib.mkForce in networking.nix"
        sudo sed -i 's/networking\.networkmanager\.enable = lib\.mkDefault true/networking.networkmanager.enable = lib.mkForce true/' "$NETWORKING_CONFIG"
    fi
    
    success "Fixed networking conflicts"
}

# Create a clean networking.nix
create_clean_networking() {
    log "Creating a clean networking.nix without hardware conflicts..."
    
    # Create backup
    sudo cp "$NETWORKING_CONFIG" "$NETWORKING_CONFIG.backup-$(date +%Y%m%d-%H%M%S)"
    
    # Create a clean networking.nix focused on application-level networking
    sudo tee "$NETWORKING_CONFIG" > /dev/null << 'EOF'
# Networking Configuration Module
# This module handles application-level networking (not hardware-specific)

{ config, pkgs, lib, ... }:

{
  # Application-level network configuration
  networking = {
    # Hostname configuration (if not set elsewhere)
    hostName = lib.mkDefault "nixos-webserver";
    
    # Host entries for local development
    hosts = {
      "127.0.0.1" = [ 
        "localhost" 
        "dashboard.local" 
        "phpmyadmin.local" 
        "sample1.local" 
        "sample2.local" 
        "sample3.local" 
      ];
      "127.0.0.2" = [ "king" ];
    };
    
    # Firewall configuration
    firewall = {
      enable = lib.mkDefault true;
      
      # Basic ports (SSH)
      allowedTCPPorts = [ 22 ];
      
      # Security settings
      allowPing = lib.mkDefault false;
      logRefusedConnections = lib.mkDefault true;
      logRefusedPackets = lib.mkDefault false;
    };
    
    # DNS configuration
    nameservers = lib.mkDefault [ "8.8.8.8" "8.8.4.4" "1.1.1.1" ];
  };

  # System-level network optimizations
  boot.kernel.sysctl = {
    # Network performance optimization
    "net.core.rmem_max" = lib.mkDefault 16777216;
    "net.core.wmem_max" = lib.mkDefault 16777216;
    "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = lib.mkDefault "4096 65536 16777216";
    
    # TCP optimization
    "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
    "net.ipv4.tcp_fastopen" = lib.mkDefault 3;
    "net.ipv4.tcp_slow_start_after_idle" = lib.mkDefault 0;
    
    # Network security
    "net.ipv4.conf.all.rp_filter" = lib.mkDefault 1;
    "net.ipv4.conf.default.rp_filter" = lib.mkDefault 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = lib.mkDefault 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = lib.mkDefault 1;
    "net.ipv4.conf.all.log_martians" = lib.mkDefault 1;
    "net.ipv4.conf.default.log_martians" = lib.mkDefault 1;
    "net.ipv4.conf.all.accept_source_route" = lib.mkDefault 0;
    "net.ipv4.conf.default.accept_source_route" = lib.mkDefault 0;
    "net.ipv4.conf.all.send_redirects" = lib.mkDefault 0;
    "net.ipv4.conf.default.send_redirects" = lib.mkDefault 0;
    "net.ipv4.conf.all.accept_redirects" = lib.mkDefault 0;
    "net.ipv4.conf.default.accept_redirects" = lib.mkDefault 0;
  };

  # Network services
  services = {
    # Network time synchronization
    timesyncd.enable = lib.mkDefault true;
    
    # Resolved for DNS
    resolved = {
      enable = lib.mkDefault true;
      dnssec = lib.mkDefault "allow-downgrade";
      domains = lib.mkDefault [ "~." ];
      fallbackDns = lib.mkDefault [ "8.8.8.8" "8.8.4.4" "1.1.1.1" ];
    };
  };

  # Network monitoring and debugging tools
  environment.systemPackages = with pkgs; [
    nettools
    inetutils
    dnsutils
    tcpdump
    wireshark-cli
    nmap
    iperf3
    mtr
    traceroute
  ];
}
EOF

    success "Created clean networking.nix without hardware conflicts"
}

# Test configuration
test_configuration() {
    log "Testing configuration after fixes..."
    
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "Configuration is valid! Infinite recursion fixed."
        echo ""
        echo "🎉 Ready to rebuild:"
        echo "   sudo nixos-rebuild switch --upgrade --impure"
    else
        warning "Configuration still has issues. Let's see the error:"
        echo ""
        sudo nixos-rebuild dry-build 2>&1 | head -20
    fi
}

# Show what each file should handle
show_responsibilities() {
    log "File responsibilities to avoid conflicts:"
    echo ""
    echo "📄 hardware-configuration.nix should handle:"
    echo "  - networking.useDHCP"
    echo "  - networking.interfaces (hardware-specific)"
    echo "  - Hardware-detected network settings"
    echo ""
    echo "📄 networking.nix should handle:"
    echo "  - networking.hosts (application domains)"
    echo "  - networking.firewall (application ports)"
    echo "  - networking.hostName (if desired)"
    echo "  - Network optimization settings"
    echo "  - DNS configuration"
    echo ""
}

# Main function
main() {
    echo "🔧 Fix Networking Conflict Between Hardware and Application Config"
    echo "================================================================="
    echo ""
    
    check_files
    analyze_conflicts
    show_responsibilities
    
    echo "Choose fix approach:"
    echo "1. Remove conflicts from networking.nix (recommended)"
    echo "2. Create completely clean networking.nix"
    echo ""
    read -p "Enter choice (1 or 2): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            fix_conflicts
            ;;
        2)
            create_clean_networking
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    test_configuration
    
    echo ""
    echo "🎯 Summary:"
    echo "- Removed hardware-specific networking from networking.nix"
    echo "- Kept application-specific networking in networking.nix"
    echo "- Hardware-configuration.nix handles hardware networking"
    echo "- Should resolve infinite recursion"
}

# Run main function
main "$@"