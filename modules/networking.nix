# Networking Configuration Module
# This module handles all networking configuration including hosts, firewall, and network settings

{ config, pkgs, lib, ... }:

{
  # Network configuration
  networking = {
    # Hostname configuration
    hostName = lib.mkDefault "nixos-webserver";
    
    # Network manager
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
      
      # Web server ports (added by webserver modules)
      # Additional ports will be appended by service modules using lib.mkAfter
      
      # Security settings
      allowPing = lib.mkDefault false;
      logRefusedConnections = lib.mkDefault true;
      logRefusedPackets = lib.mkDefault false;
    };
    
    # Network optimization settings
    dhcpcd.enable = lib.mkDefault true;
    useDHCP = lib.mkDefault true;
    
    # IPv6 configuration
    enableIPv6 = lib.mkDefault true;
    
    # DNS configuration
    nameservers = lib.mkDefault [ "8.8.8.8" "8.8.4.4" "1.1.1.1" ];
    
    # Network interface configuration
    interfaces = {
      # This will be automatically configured for most systems
      # Add specific interface configuration here if needed
    };
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