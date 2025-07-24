#!/usr/bin/env bash

# Fix DHCP Conflict Between Hardware and Networking Modules
# This script resolves the networking.useDHCP conflict

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
}

# Check current DHCP configuration
check_dhcp_config() {
    log "Checking DHCP configuration..."
    echo ""
    
    echo "🔍 In hardware-configuration.nix:"
    if [[ -f "$HARDWARE_CONFIG" ]]; then
        grep -n "useDHCP\|dhcpcd\|networkmanager" "$HARDWARE_CONFIG" | sed 's/^/  /' || echo "  No DHCP settings found"
    else
        error "hardware-configuration.nix not found"
    fi
    echo ""
    
    echo "🔍 In networking.nix:"
    if [[ -f "$NETWORKING_CONFIG" ]]; then
        grep -n "useDHCP\|dhcpcd\|networkmanager" "$NETWORKING_CONFIG" | sed 's/^/  /' || echo "  No DHCP settings found"
    else
        warning "networking.nix not found"
    fi
    echo ""
}

# Show the conflict
show_conflict() {
    log "DHCP conflict explanation:"
    echo ""
    echo "❌ The conflict:"
    echo "  hardware-configuration.nix: networking.useDHCP = lib.mkDefault true;"
    echo "  networking.nix:             networking.useDHCP = lib.mkDefault true;"
    echo "  OR networking.nix:          networking.dhcpcd.enable = lib.mkDefault true;"
    echo ""
    echo "💡 The solution:"
    echo "  - Keep useDHCP in hardware-configuration.nix (hardware-specific)"
    echo "  - Remove conflicting DHCP settings from networking.nix"
    echo "  - Use networkmanager.enable in networking.nix instead"
    echo ""
}

# Fix networking.nix to avoid DHCP conflicts
fix_networking_module() {
    log "Fixing networking.nix to avoid DHCP conflicts..."
    
    if [[ ! -f "$NETWORKING_CONFIG" ]]; then
        error "networking.nix not found"
        return 1
    fi
    
    # Backup networking.nix
    sudo cp "$NETWORKING_CONFIG" "$NETWORKING_CONFIG.dhcp-fix-backup-$(date +%Y%m%d-%H%M%S)"
    success "Created backup of networking.nix"
    
    # Remove conflicting DHCP settings
    sudo sed -i '/networking\.useDHCP/d' "$NETWORKING_CONFIG"
    sudo sed -i '/networking\.dhcpcd/d' "$NETWORKING_CONFIG"
    
    # Create clean networking.nix without DHCP conflicts
    sudo tee "$NETWORKING_CONFIG" > /dev/null << 'EOF'
# Networking Configuration Module (No DHCP Conflicts)
# This module handles application-level networking without conflicting with hardware config

{ config, pkgs, lib, ... }:

{
  # Application-level network configuration
  networking = {
    # Hostname configuration
    hostName = lib.mkDefault "nixos-webserver";
    
    # Use NetworkManager (doesn't conflict with hardware DHCP)
    networkmanager.enable = lib.mkDefault true;
    
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
    
    # IPv6 configuration
    enableIPv6 = lib.mkDefault true;
    
    # NOTE: useDHCP and dhcpcd are handled by hardware-configuration.nix
    # This avoids conflicts between hardware and application networking
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

    success "Fixed networking.nix to avoid DHCP conflicts"
}

# Test the fixed configuration
test_fixed_config() {
    log "Testing fixed configuration..."
    
    # Test with just networking
    sudo tee "$NIXOS_CONFIG_DIR/test-dhcp-fix.nix" > /dev/null << 'EOF'
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

    if sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-dhcp-fix.nix" &>/dev/null; then
        success "✅ DHCP conflict resolved!"
        sudo rm -f "$NIXOS_CONFIG_DIR/test-dhcp-fix.nix"
        return 0
    else
        error "❌ Still have issues:"
        sudo nixos-rebuild dry-build --impure -I nixos-config="$NIXOS_CONFIG_DIR/test-dhcp-fix.nix" 2>&1 | head -10
        sudo rm -f "$NIXOS_CONFIG_DIR/test-dhcp-fix.nix"
        return 1
    fi
}

# Test full configuration
test_full_config() {
    log "Testing full configuration..."
    
    if sudo nixos-rebuild dry-build --impure &>/dev/null; then
        success "🎉 Full configuration works!"
        return 0
    else
        warning "Full configuration still has issues:"
        sudo nixos-rebuild dry-build --impure 2>&1 | head -10
        return 1
    fi
}

# Show final networking separation
show_networking_separation() {
    log "Networking configuration separation:"
    echo ""
    echo "📄 hardware-configuration.nix handles:"
    echo "  ✅ networking.useDHCP = lib.mkDefault true;"
    echo "  ✅ networking.interfaces.* (hardware-specific)"
    echo "  ✅ Hardware-detected network settings"
    echo ""
    echo "📄 networking.nix handles:"
    echo "  ✅ networking.hostName"
    echo "  ✅ networking.networkmanager.enable"
    echo "  ✅ networking.hosts (application domains)"
    echo "  ✅ networking.firewall (application ports)"
    echo "  ✅ Network optimization settings"
    echo "  ✅ DNS configuration"
    echo ""
    echo "🎯 No conflicts between hardware and application networking!"
}

# Main function
main() {
    echo "🔧 Fix DHCP Conflict Between Hardware and Networking Modules"
    echo "============================================================"
    echo ""
    
    check_dhcp_config
    show_conflict
    
    echo "This will fix the networking.useDHCP conflict by:"
    echo "1. Removing DHCP settings from networking.nix"
    echo "2. Letting hardware-configuration.nix handle DHCP"
    echo "3. Using NetworkManager in networking.nix instead"
    echo ""
    
    read -p "Proceed with DHCP conflict fix? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    fix_networking_module
    
    if test_fixed_config; then
        if test_full_config; then
            show_networking_separation
            
            echo ""
            echo "🎉 SUCCESS! DHCP conflict resolved!"
            echo ""
            echo "🎯 Next steps:"
            echo "1. Run: sudo nixos-rebuild switch --impure"
            echo "2. Your modular webserver should now work!"
            echo "3. No more infinite recursion errors!"
            echo ""
            echo "✅ Configuration:"
            echo "  - hardware-configuration.nix: handles DHCP"
            echo "  - networking.nix: handles application networking"
            echo "  - Clean separation, no conflicts"
        else
            warning "DHCP conflict fixed, but other issues remain"
        fi
    else
        error "DHCP fix didn't resolve the issue"
    fi
}

# Run main function
main "$@"