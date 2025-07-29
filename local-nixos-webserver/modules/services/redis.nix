# Redis Configuration Module
# NixOS 25.05 Compatible
# High-performance in-memory data structure store

{ config, pkgs, ... }:

{
  # Redis service configuration
  services.redis.servers.main = {
    enable = true;
    
    # Network configuration
    bind = "127.0.0.1";
    port = 6379;
    
    # Database configuration
    databases = 16;
    
    # Memory management
    maxmemory = "512mb";
    maxmemoryPolicy = "allkeys-lru";
    
    # Persistence configuration
    save = [
      [900 1]    # Save after 900 sec if at least 1 key changed
      [300 10]   # Save after 300 sec if at least 10 keys changed
      [60 10000] # Save after 60 sec if at least 10000 keys changed
    ];
    
    # Additional Redis configuration
    settings = {
      # Basic settings
      timeout = 300;
      tcp-keepalive = 60;
      tcp-backlog = 511;
      
      # Client management
      maxclients = 1000;
      
      # Memory optimization
      hash-max-ziplist-entries = 512;
      hash-max-ziplist-value = 64;
      list-max-ziplist-size = -2;
      list-compress-depth = 0;
      set-max-intset-entries = 512;
      zset-max-ziplist-entries = 128;
      zset-max-ziplist-value = 64;
      hll-sparse-max-bytes = 3000;
      
      # Lazy freeing
      lazyfree-lazy-eviction = "yes";
      lazyfree-lazy-expire = "yes";
      lazyfree-lazy-server-del = "yes";
      replica-lazy-flush = "yes";
      
      # Threading (Redis 6.0+)
      io-threads = 2;
      io-threads-do-reads = "yes";
      
      # Logging
      loglevel = "notice";
      logfile = "/var/log/redis/redis.log";
      
      # Slow log
      slowlog-log-slower-than = 10000;
      slowlog-max-len = 128;
      
      # Security
      protected-mode = "yes";
      
      # Persistence tuning
      rdbcompression = "yes";
      rdbchecksum = "yes";
      dbfilename = "dump.rdb";
      dir = "/var/lib/redis-main";
      
      # AOF (Append Only File) configuration
      appendonly = "yes";
      appendfilename = "appendonly.aof";
      appendfsync = "everysec";
      no-appendfsync-on-rewrite = "no";
      auto-aof-rewrite-percentage = 100;
      auto-aof-rewrite-min-size = "64mb";
      aof-load-truncated = "yes";
      aof-use-rdb-preamble = "yes";
      
      # Lua scripting
      lua-time-limit = 5000;
      
      # Latency monitoring
      latency-monitor-threshold = 100;
      
      # Memory usage optimization
      activerehashing = "yes";
      
      # Client output buffer limits
      client-output-buffer-limit-normal = "0 0 0";
      client-output-buffer-limit-replica = "256mb 64mb 60";
      client-output-buffer-limit-pubsub = "32mb 8mb 60";
      
      # Frequency of rehashing
      hz = 10;
      
      # Dynamic HZ
      dynamic-hz = "yes";
      
      # Jemalloc background thread
      jemalloc-bg-thread = "yes";
      
      # Disable dangerous commands in production
      rename-command = [
        "FLUSHDB FLUSHDB_DISABLED"
        "FLUSHALL FLUSHALL_DISABLED"
        "DEBUG DEBUG_DISABLED"
        "CONFIG CONFIG_DISABLED"
        "SHUTDOWN SHUTDOWN_DISABLED"
      ];
    };
  };

  # Create Redis log directory
  systemd.tmpfiles.rules = [
    "d /var/log/redis 0755 redis redis -"
    "d /var/lib/redis-main 0755 redis redis -"
  ];

  # Redis service optimization
  systemd.services.redis-main = {
    serviceConfig = {
      # Process management
      TimeoutStartSec = "60s";
      TimeoutStopSec = "60s";
      
      # Security
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/redis-main" "/var/log/redis" ];
      
      # Resource limits
      LimitNOFILE = "65536";
      LimitNPROC = "4096";
      
      # Memory settings
      OOMScoreAdjust = -900;
    };
    
    # Restart on failure
    unitConfig = {
      StartLimitBurst = "3";
      StartLimitIntervalSec = "60s";
    };
  };

  # Log rotation for Redis
  services.logrotate.settings.redis = {
    files = [ "/var/log/redis/*.log" ];
    frequency = "daily";
    rotate = 14;
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    sharedscripts = true;
    postrotate = "systemctl reload redis-main";
  };

  # Redis monitoring script
  systemd.services.redis-monitor = {
    description = "Redis Performance Monitor";
    serviceConfig = {
      Type = "oneshot";
      User = "redis";
      ExecStart = pkgs.writeShellScript "redis-monitor" ''
        #!/usr/bin/env bash
        REDIS_CLI="${pkgs.redis}/bin/redis-cli"
        LOG_FILE="/var/log/redis/performance.log"
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Get Redis info
        INFO=$($REDIS_CLI INFO)
        
        # Extract key metrics
        MEMORY_USED=$(echo "$INFO" | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r')
        MEMORY_PEAK=$(echo "$INFO" | grep "used_memory_peak_human:" | cut -d: -f2 | tr -d '\r')
        CONNECTED_CLIENTS=$(echo "$INFO" | grep "connected_clients:" | cut -d: -f2 | tr -d '\r')
        TOTAL_COMMANDS=$(echo "$INFO" | grep "total_commands_processed:" | cut -d: -f2 | tr -d '\r')
        KEYSPACE_HITS=$(echo "$INFO" | grep "keyspace_hits:" | cut -d: -f2 | tr -d '\r')
        KEYSPACE_MISSES=$(echo "$INFO" | grep "keyspace_misses:" | cut -d: -f2 | tr -d '\r')
        
        # Calculate hit rate
        if [ "$KEYSPACE_HITS" -gt 0 ] && [ "$KEYSPACE_MISSES" -gt 0 ]; then
          TOTAL_REQUESTS=$((KEYSPACE_HITS + KEYSPACE_MISSES))
          HIT_RATE=$(echo "scale=2; $KEYSPACE_HITS * 100 / $TOTAL_REQUESTS" | bc)
        else
          HIT_RATE="N/A"
        fi
        
        # Log metrics
        echo "[$TIMESTAMP] Memory: $MEMORY_USED (Peak: $MEMORY_PEAK), Clients: $CONNECTED_CLIENTS, Commands: $TOTAL_COMMANDS, Hit Rate: $HIT_RATE%" >> "$LOG_FILE"
        
        # Check for issues
        if [ "$CONNECTED_CLIENTS" -gt 800 ]; then
          echo "[$TIMESTAMP] WARNING: High client connections: $CONNECTED_CLIENTS" >> "$LOG_FILE"
        fi
        
        # Cleanup old logs (keep last 1000 lines)
        tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
      '';
    };
  };

  # Schedule Redis monitoring every 5 minutes
  systemd.timers.redis-monitor = {
    description = "Redis Performance Monitoring";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
  };

  # Redis backup script
  systemd.services.redis-backup = {
    description = "Redis Database Backup";
    serviceConfig = {
      Type = "oneshot";
      User = "redis";
      ExecStart = pkgs.writeShellScript "redis-backup" ''
        #!/usr/bin/env bash
        BACKUP_DIR="/var/backups/redis"
        DATE=$(date +%Y%m%d_%H%M%S)
        REDIS_CLI="${pkgs.redis}/bin/redis-cli"
        
        mkdir -p "$BACKUP_DIR"
        
        # Trigger a background save
        $REDIS_CLI BGSAVE
        
        # Wait for the save to complete
        while [ "$($REDIS_CLI LASTSAVE)" = "$($REDIS_CLI LASTSAVE)" ]; do
          sleep 1
        done
        
        # Copy the RDB file
        cp /var/lib/redis-main/dump.rdb "$BACKUP_DIR/redis_backup_$DATE.rdb"
        
        # Compress the backup
        gzip "$BACKUP_DIR/redis_backup_$DATE.rdb"
        
        # Remove backups older than 7 days
        find "$BACKUP_DIR" -name "*.rdb.gz" -mtime +7 -delete
        
        echo "Redis backup completed: redis_backup_$DATE.rdb.gz"
      '';
    };
  };

  # Schedule daily Redis backups
  systemd.timers.redis-backup = {
    description = "Daily Redis Backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };

  # Create backup directory
  systemd.tmpfiles.rules = [
    "d /var/backups/redis 0755 redis redis -"
  ];
}
