# Networking Configuration Module
# NixOS 25.05 Compatible
# Firewall, hosts, and network optimization

{ config, pkgs, ... }:

{
  # Hostname configuration
  networking.hostName = "nixos-webserver";
  
  # Hosts file configuration for local development domains
  networking.hosts = {
    "127.0.0.1" = [ 
      "dashboard.local" 
      "phpmyadmin.local" 
      "sample1.local" 
      "sample2.local" 
      "sample3.local"
      "caching-scripts.local"
    ];
    
    # IPv6 localhost entries
    "::1" = [
      "dashboard.local"
      "phpmyadmin.local" 
      "sample1.local" 
      "sample2.local" 
      "sample3.local"
      "caching-scripts.local"
    ];
  };
  
  # Firewall configuration with security and performance optimizations
  networking.firewall = {
    enable = true;
    
    # Allowed TCP ports
    allowedTCPPorts = [ 
      22    # SSH
      80    # HTTP
      443   # HTTPS
      3306  # MySQL/MariaDB
      6379  # Redis (localhost only, but listed for reference)
    ];
    
    # Allowed UDP ports (if needed)
    allowedUDPPorts = [ ];
    
    # Custom firewall rules for enhanced security
    extraCommands = ''
      # Rate limiting for HTTP connections
      iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
      iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
      
      # Rate limiting for SSH connections
      iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH
      iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
      
      # Block common attack patterns
      iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
      iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
      iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
      iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP
      
      # Allow loopback traffic
      iptables -A INPUT -i lo -j ACCEPT
      iptables -A OUTPUT -o lo -j ACCEPT
      
      # Allow established and related connections
      iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      
      # Log dropped packets (limited to prevent log spam)
      iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7
      
      # Protect against port scanning
      iptables -A INPUT -m conntrack --ctstate NEW -m recent --set
      iptables -A INPUT -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 20 -j DROP
      
      # Restrict MySQL access to localhost only
      iptables -A INPUT -p tcp --dport 3306 ! -s 127.0.0.1 -j DROP
      iptables -A INPUT -p tcp --dport 3306 ! -s ::1 -j DROP
      
      # Restrict Redis access to localhost only
      iptables -A INPUT -p tcp --dport 6379 ! -s 127.0.0.1 -j DROP
      iptables -A INPUT -p tcp --dport 6379 ! -s ::1 -j DROP
    '';
    
    # Cleanup rules when firewall is stopped
    extraStopCommands = ''
      iptables -D INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m limit --limit 25/minute --limit-burst 100 -j ACCEPT 2>/dev/null || true
      iptables -D INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -m limit --limit 25/minute --limit-burst 100 -j ACCEPT 2>/dev/null || true
    '';
    
    # Allow ping
    allowPing = true;
    
    # Log refused connections
    logRefusedConnections = false; # Disabled to prevent log spam
    
    # Log refused packets
    logRefusedPackets = false; # Disabled to prevent log spam
  };
  
  # Network optimization settings
  boot.kernel.sysctl = {
    # TCP optimization
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 65536 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.ipv4.tcp_tw_reuse" = 1;
    "net.ipv4.tcp_fin_timeout" = 30;
    "net.ipv4.tcp_keepalive_time" = 1200;
    "net.ipv4.tcp_keepalive_probes" = 7;
    "net.ipv4.tcp_keepalive_intvl" = 30;
    "net.ipv4.tcp_max_syn_backlog" = 8192;
    "net.ipv4.tcp_max_tw_buckets" = 2000000;
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_mtu_probing" = 1;
    
    # Network buffer optimization
    "net.core.netdev_max_backlog" = 5000;
    "net.core.netdev_budget" = 600;
    "net.core.somaxconn" = 8192;
    
    # Security settings
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "net.ipv4.ip_forward" = 0;
    
    # IPv6 security
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;
    
    # Memory and file system optimization
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
    "fs.file-max" = 2097152;
    
    # Process limits
    "kernel.pid_max" = 4194304;
    
    # Shared memory
    "kernel.shmmax" = 268435456;
    "kernel.shmall" = 268435456;
  };
  
  # DNS configuration
  networking.nameservers = [ 
    "1.1.1.1"     # Cloudflare DNS
    "1.0.0.1"     # Cloudflare DNS
    "8.8.8.8"     # Google DNS
    "8.8.4.4"     # Google DNS
  ];
  
  # Network interface optimization
  systemd.network.enable = false; # Use traditional networking
  
  # Fail2ban for additional security (optional)
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    findtime = "10m";
    
    jails = {
      # SSH protection
      sshd = {
        enabled = true;
        filter = "sshd";
        logpath = "/var/log/auth.log";
        maxretry = 3;
        bantime = "1h";
      };
      
      # Nginx protection
      nginx-http-auth = {
        enabled = true;
        filter = "nginx-http-auth";
        logpath = "/var/log/nginx/error.log";
        maxretry = 5;
        bantime = "30m";
      };
      
      nginx-limit-req = {
        enabled = true;
        filter = "nginx-limit-req";
        logpath = "/var/log/nginx/error.log";
        maxretry = 10;
        bantime = "30m";
      };
      
      # MySQL protection
      mysql-auth = {
        enabled = true;
        filter = "mysql-auth";
        logpath = "/var/log/mysql/error.log";
        maxretry = 3;
        bantime = "1h";
      };
    };
  };
  
  # Network monitoring
  systemd.services.network-monitor = {
    description = "Network Performance Monitor";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "network-monitor" ''
        #!/usr/bin/env bash
        LOG_FILE="/var/log/network-performance.log"
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Get network statistics
        RX_BYTES=$(cat /sys/class/net/*/statistics/rx_bytes | awk '{sum+=$1} END {print sum}')
        TX_BYTES=$(cat /sys/class/net/*/statistics/tx_bytes | awk '{sum+=$1} END {print sum}')
        RX_PACKETS=$(cat /sys/class/net/*/statistics/rx_packets | awk '{sum+=$1} END {print sum}')
        TX_PACKETS=$(cat /sys/class/net/*/statistics/tx_packets | awk '{sum+=$1} END {print sum}')
        RX_ERRORS=$(cat /sys/class/net/*/statistics/rx_errors | awk '{sum+=$1} END {print sum}')
        TX_ERRORS=$(cat /sys/class/net/*/statistics/tx_errors | awk '{sum+=$1} END {print sum}')
        
        # Convert bytes to MB
        RX_MB=$((RX_BYTES / 1024 / 1024))
        TX_MB=$((TX_BYTES / 1024 / 1024))
        
        # Log statistics
        echo "[$TIMESTAMP] RX: ${RX_MB}MB (${RX_PACKETS} packets, ${RX_ERRORS} errors), TX: ${TX_MB}MB (${TX_PACKETS} packets, ${TX_ERRORS} errors)" >> "$LOG_FILE"
        
        # Check for high error rates
        if [ "$RX_ERRORS" -gt 100 ] || [ "$TX_ERRORS" -gt 100 ]; then
          echo "[$TIMESTAMP] WARNING: High network error rate - RX: $RX_ERRORS, TX: $TX_ERRORS" >> "$LOG_FILE"
        fi
        
        # Cleanup old logs (keep last 1000 lines)
        tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
      '';
    };
  };
  
  # Schedule network monitoring every 10 minutes
  systemd.timers.network-monitor = {
    description = "Network Performance Monitoring";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/10";
      Persistent = true;
    };
  };
}
