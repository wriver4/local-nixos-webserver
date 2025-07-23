#!/usr/bin/env bash

# Fix MySQL SSL Configuration Error
# This script resolves the "SSL is required, but the server does not support it" error

set -e  # Exit on any error

NIXOS_CONFIG_DIR="/etc/nixos"
MYSQL_MODULE="$NIXOS_CONFIG_DIR/modules/services/mysql.nix"

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

# Check MySQL service status
check_mysql_status() {
    log "Checking MySQL service status..."
    
    if systemctl is-active --quiet mysql; then
        success "MySQL service is running"
    else
        warning "MySQL service is not running"
        echo "Starting MySQL service..."
        sudo systemctl start mysql || warning "Could not start MySQL service"
    fi
}

# Check current MySQL SSL configuration
check_mysql_ssl_config() {
    log "Checking current MySQL SSL configuration..."
    
    if [[ -f "$MYSQL_MODULE" ]]; then
        echo "Current MySQL module configuration:"
        grep -A 20 -B 5 "ssl\|SSL\|tls\|TLS" "$MYSQL_MODULE" || echo "No SSL configuration found"
        echo ""
    fi
    
    # Check if MySQL is configured to require SSL
    if sudo mysql -e "SHOW VARIABLES LIKE 'require_secure_transport';" 2>/dev/null; then
        echo "MySQL SSL requirement status:"
        sudo mysql -e "SHOW VARIABLES LIKE 'require_secure_transport';"
        echo ""
    else
        warning "Cannot connect to MySQL to check SSL status"
    fi
}

# Fix MySQL SSL configuration
fix_mysql_ssl() {
    log "Fixing MySQL SSL configuration..."
    
    if [[ ! -f "$MYSQL_MODULE" ]]; then
        error "MySQL module not found at $MYSQL_MODULE"
    fi
    
    # Create backup
    sudo cp "$MYSQL_MODULE" "$MYSQL_MODULE.ssl-fix-backup-$(date +%Y%m%d-%H%M%S)"
    success "Created backup of MySQL module"
    
    # Add SSL configuration to MySQL settings
    log "Adding SSL configuration to MySQL module..."
    
    # Check if settings block exists
    if grep -q "settings.*=" "$MYSQL_MODULE"; then
        # Add SSL settings to existing settings block
        sudo sed -i '/settings.*=/,/^[[:space:]]*};/{
            /mysqld.*=/,/^[[:space:]]*};/{
                /^[[:space:]]*};/i\
\
        # SSL/TLS configuration\
        require_secure_transport = lib.mkDefault "OFF";\
        ssl = lib.mkDefault "0";\
        \
        # Allow non-SSL connections for local development\
        bind-address = lib.mkDefault "127.0.0.1";
            }
        }' "$MYSQL_MODULE"
    else
        # Add settings block with SSL configuration
        sudo sed -i '/services\.mysql.*=/,/^[[:space:]]*};/{
            /package.*=/a\
\
    # SSL/TLS configuration\
    settings = {\
      mysqld = {\
        # Disable SSL requirement for local development\
        require_secure_transport = "OFF";\
        ssl = "0";\
        \
        # Bind to localhost only\
        bind-address = "127.0.0.1";\
        port = 3306;\
      };\
    };
        }' "$MYSQL_MODULE"
    fi
    
    success "Added SSL configuration to MySQL module"
}

# Create a comprehensive MySQL configuration
create_comprehensive_mysql_config() {
    log "Creating comprehensive MySQL configuration..."
    
    # Create backup
    sudo cp "$MYSQL_MODULE" "$MYSQL_MODULE.comprehensive-backup-$(date +%Y%m%d-%H%M%S)"
    
    # Create comprehensive MySQL configuration
    sudo tee "$MYSQL_MODULE" > /dev/null << 'EOF'
# Enhanced MySQL/MariaDB Service Module with SSL Configuration
# This module provides MySQL configuration with proper SSL handling

{ config, pkgs, lib, ... }:

{
  # MySQL/MariaDB configuration with SSL handling
  services.mysql = {
    enable = lib.mkDefault true;
    package = lib.mkDefault pkgs.mariadb;
    
    # Comprehensive MySQL settings
    settings = {
      mysqld = {
        # Basic configuration
        bind-address = lib.mkDefault "127.0.0.1";
        port = lib.mkDefault 3306;
        
        # SSL/TLS configuration - disabled for local development
        require_secure_transport = lib.mkDefault "OFF";
        ssl = lib.mkDefault "0";
        
        # Character set
        character-set-server = lib.mkDefault "utf8mb4";
        collation-server = lib.mkDefault "utf8mb4_unicode_ci";
        
        # InnoDB optimization
        innodb_buffer_pool_size = lib.mkDefault "256M";
        innodb_log_file_size = lib.mkDefault "64M";
        innodb_flush_log_at_trx_commit = lib.mkDefault "2";
        innodb_flush_method = lib.mkDefault "O_DIRECT";
        
        # Query optimization
        query_cache_type = lib.mkDefault "1";
        query_cache_size = lib.mkDefault "32M";
        query_cache_limit = lib.mkDefault "2M";
        
        # Connection settings
        max_connections = lib.mkDefault "200";
        max_connect_errors = lib.mkDefault "1000";
        
        # Buffer optimization
        key_buffer_size = lib.mkDefault "32M";
        sort_buffer_size = lib.mkDefault "2M";
        read_buffer_size = lib.mkDefault "1M";
        read_rnd_buffer_size = lib.mkDefault "2M";
        
        # Temporary table optimization
        tmp_table_size = lib.mkDefault "32M";
        max_heap_table_size = lib.mkDefault "32M";
        
        # Logging
        slow_query_log = lib.mkDefault "1";
        slow_query_log_file = lib.mkDefault "/var/log/mysql/slow.log";
        long_query_time = lib.mkDefault "2";
      };
    };
    
    # Webserver-specific databases
    initialDatabases = lib.mkDefault [
      { name = "dashboard_db"; }
      { name = "sample1_db"; }
      { name = "sample2_db"; }
      { name = "sample3_db"; }
    ];
    
    # Database initialization with non-SSL users
    initialScript = lib.mkDefault (pkgs.writeText "webserver-mysql-init.sql" ''
      -- Webserver database initialization
      CREATE USER IF NOT EXISTS 'webuser'@'localhost' IDENTIFIED BY 'webpass123';
      GRANT ALL PRIVILEGES ON dashboard_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample1_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample2_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample3_db.* TO 'webuser'@'localhost';
      
      -- phpMyAdmin user
      CREATE USER IF NOT EXISTS 'phpmyadmin'@'localhost' IDENTIFIED BY 'pmapass123';
      GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost' WITH GRANT OPTION;
      
      -- Ensure users can connect without SSL
      ALTER USER 'webuser'@'localhost' REQUIRE NONE;
      ALTER USER 'phpmyadmin'@'localhost' REQUIRE NONE;
      
      FLUSH PRIVILEGES;
    '');
  };

  # Add MySQL client tools
  environment.systemPackages = with pkgs; [
    mysql80  # MySQL client tools
  ];

  # Open MySQL port in firewall
  networking.firewall.allowedTCPPorts = lib.mkAfter [ 3306 ];

  # Create MySQL log directory
  system.activationScripts.mysql-logs = ''
    mkdir -p /var/log/mysql
    chown mysql:mysql /var/log/mysql
    chmod 755 /var/log/mysql
  '';

  # Systemd service optimization
  systemd.services.mysql.serviceConfig = lib.mkMerge [
    {
      LimitNOFILE = lib.mkDefault 65535;
      LimitNPROC = lib.mkDefault 4096;
    }
  ];
}
EOF

    success "Created comprehensive MySQL configuration with SSL disabled"
}

# Test MySQL connection
test_mysql_connection() {
    log "Testing MySQL connection..."
    
    # Test basic connection
    if sudo mysql -e "SELECT 'MySQL connection successful' as status;" 2>/dev/null; then
        success "MySQL connection successful"
        
        # Check SSL status
        echo "MySQL SSL status:"
        sudo mysql -e "SHOW VARIABLES LIKE '%ssl%';" 2>/dev/null | head -10
        echo ""
        
        # Check require_secure_transport
        echo "Secure transport requirement:"
        sudo mysql -e "SHOW VARIABLES LIKE 'require_secure_transport';" 2>/dev/null
        echo ""
        
    else
        warning "MySQL connection failed"
        echo "Checking MySQL service status..."
        sudo systemctl status mysql --no-pager -l
    fi
}

# Rebuild and restart services
rebuild_and_restart() {
    log "Rebuilding NixOS configuration..."
    
    if sudo nixos-rebuild switch &>/dev/null; then
        success "NixOS rebuild successful"
        
        log "Restarting MySQL service..."
        sudo systemctl restart mysql
        
        success "MySQL service restarted"
        
        # Wait a moment for service to start
        sleep 3
        
        test_mysql_connection
        
    else
        warning "NixOS rebuild failed:"
        sudo nixos-rebuild switch 2>&1 | head -10
    fi
}

# Show connection examples
show_connection_examples() {
    log "MySQL connection examples..."
    echo ""
    echo "🔧 Connect to MySQL without SSL:"
    echo "  mysql -u root"
    echo "  mysql -u webuser -p"
    echo ""
    echo "🔧 Connect with specific SSL settings:"
    echo "  mysql -u root --ssl-mode=DISABLED"
    echo "  mysql -u webuser -p --ssl-mode=DISABLED"
    echo ""
    echo "🔧 PHP connection string (no SSL):"
    echo "  \$pdo = new PDO('mysql:host=localhost;dbname=dashboard_db', 'webuser', 'webpass123');"
    echo ""
    echo "🔧 phpMyAdmin connection:"
    echo "  Username: phpmyadmin"
    echo "  Password: pmapass123"
    echo "  Server: localhost"
}

# Main function
main() {
    echo "🔧 Fix MySQL SSL Configuration Error"
    echo "===================================="
    echo ""
    
    echo "This script will fix the MySQL SSL error by:"
    echo "1. Disabling SSL requirement for local development"
    echo "2. Configuring MySQL to allow non-SSL connections"
    echo "3. Setting up proper user permissions"
    echo ""
    
    read -p "Proceed with MySQL SSL fix? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    check_mysql_status
    check_mysql_ssl_config
    
    echo ""
    echo "Choose fix method:"
    echo "1. Add SSL configuration to existing MySQL module"
    echo "2. Create comprehensive MySQL configuration (recommended)"
    echo ""
    read -p "Enter choice (1 or 2): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            fix_mysql_ssl
            ;;
        2)
            create_comprehensive_mysql_config
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    rebuild_and_restart
    show_connection_examples
    
    echo ""
    echo "🎯 Summary:"
    echo "- MySQL SSL requirement disabled for local development"
    echo "- Users can connect without SSL certificates"
    echo "- Database connections should work normally"
    echo "- phpMyAdmin should connect successfully"
}

# Run main function
main "$@"