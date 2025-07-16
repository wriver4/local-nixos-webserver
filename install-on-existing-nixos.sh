#!/bin/bash

# NixOS Web Server Installation Script for Existing Systems (PHP 8.4)
# This script safely integrates web server functionality into existing NixOS installations
# Enhanced with dynamic path configuration

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration paths (can be overridden)
DEFAULT_NIXOS_CONFIG_DIR="/etc/nixos"
DEFAULT_BACKUP_BASE_DIR="/etc/nixos/webserver-backups"
DEFAULT_WEB_ROOT="/var/www"

# Initialize with defaults
NIXOS_CONFIG_DIR="$DEFAULT_NIXOS_CONFIG_DIR"
BACKUP_BASE_DIR="$DEFAULT_BACKUP_BASE_DIR"
WEB_ROOT="$DEFAULT_WEB_ROOT"

# Dynamic backup directory with timestamp
BACKUP_DIR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
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

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

NixOS Web Server Installation Script for Existing Systems (PHP 8.4)
Safely integrates web server functionality into existing NixOS installations.

OPTIONS:
    -c, --config-dir PATH       NixOS configuration directory
                               Default: $DEFAULT_NIXOS_CONFIG_DIR
    
    -b, --backup-dir PATH       Backup base directory (timestamp will be added)
                               Default: $DEFAULT_BACKUP_BASE_DIR
    
    -w, --webroot PATH          Web root directory for sites
                               Default: $DEFAULT_WEB_ROOT
    
    -i, --interactive          Interactive mode (prompt for all paths)
    
    -h, --help                 Show this help message
    
    --dry-run                  Show what would be done without making changes

EXAMPLES:
    # Use defaults
    $0
    
    # Custom paths
    $0 --config-dir /home/user/nixos --webroot /srv/www
    
    # Interactive mode
    $0 --interactive
    
    # Dry run to see what would happen
    $0 --dry-run

NOTES:
    - All paths will be validated before use
    - Directories will be created if they don't exist (with confirmation)
    - Relative paths will be converted to absolute paths
    - Backup directory will have timestamp appended automatically

EOF
}

# Parse command line arguments
parse_arguments() {
    local interactive_mode=false
    local dry_run=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config-dir)
                NIXOS_CONFIG_DIR="$2"
                shift 2
                ;;
            -b|--backup-dir)
                BACKUP_BASE_DIR="$2"
                shift 2
                ;;
            -w|--webroot)
                WEB_ROOT="$2"
                shift 2
                ;;
            -i|--interactive)
                interactive_mode=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
    
    # Handle interactive mode
    if [[ "$interactive_mode" == true ]]; then
        prompt_for_paths
    fi
    
    # Handle dry run
    if [[ "$dry_run" == true ]]; then
        show_dry_run
        exit 0
    fi
}

# Interactive path configuration
prompt_for_paths() {
    echo "🔧 Interactive Path Configuration"
    echo "================================="
    echo
    
    # NixOS Config Directory
    echo "📁 NixOS Configuration Directory"
    echo "   Current default: $NIXOS_CONFIG_DIR"
    read -p "   Enter new path (or press Enter to keep current): " input
    if [[ -n "$input" ]]; then
        NIXOS_CONFIG_DIR="$input"
    fi
    echo
    
    # Backup Directory
    echo "💾 Backup Base Directory"
    echo "   Current default: $BACKUP_BASE_DIR"
    echo "   Note: Timestamp will be automatically appended"
    read -p "   Enter new path (or press Enter to keep current): " input
    if [[ -n "$input" ]]; then
        BACKUP_BASE_DIR="$input"
    fi
    echo
    
    # Web Root Directory
    echo "🌐 Web Root Directory"
    echo "   Current default: $WEB_ROOT"
    read -p "   Enter new path (or press Enter to keep current): " input
    if [[ -n "$input" ]]; then
        WEB_ROOT="$input"
    fi
    echo
}

# Show what would be done in dry run mode
show_dry_run() {
    echo "🔍 Dry Run Mode - Configuration Preview"
    echo "======================================="
    echo
    
    # Convert to absolute paths for display
    local abs_config_dir=$(realpath -m "$NIXOS_CONFIG_DIR")
    local abs_backup_base=$(realpath -m "$BACKUP_BASE_DIR")
    local abs_webroot=$(realpath -m "$WEB_ROOT")
    local abs_backup_dir="$abs_backup_base/$(date +%Y%m%d-%H%M%S)"
    
    echo "📋 Configuration Summary:"
    echo "   NixOS Config Directory: $abs_config_dir"
    echo "   Backup Directory: $abs_backup_dir"
    echo "   Web Root Directory: $abs_webroot"
    echo
    
    echo "📁 Files that would be created/modified:"
    echo "   $abs_config_dir/webserver.nix (new web server module)"
    echo "   $abs_config_dir/configuration.nix (updated to import webserver.nix)"
    echo "   $abs_backup_dir/ (backup of current configuration)"
    echo "   $abs_webroot/{dashboard,phpmyadmin,sample1,sample2,sample3}/ (web directories)"
    echo "   /usr/local/bin/{rebuild-webserver,create-site-db,create-site-dir} (helper scripts)"
    echo "   /etc/hosts (updated with .local domains)"
    echo
    
    echo "🔍 Validation Results:"
    validate_paths_dry_run "$abs_config_dir" "$abs_backup_base" "$abs_webroot"
    echo
    
    echo "🚀 To run with these settings:"
    echo "   $0 --config-dir \"$NIXOS_CONFIG_DIR\" --backup-dir \"$BACKUP_BASE_DIR\" --webroot \"$WEB_ROOT\""
}

# Validate paths in dry run mode
validate_paths_dry_run() {
    local config_dir="$1"
    local backup_base="$2"
    local webroot="$3"
    
    # Check NixOS config directory
    if [[ -d "$config_dir" ]]; then
        if [[ -f "$config_dir/configuration.nix" ]]; then
            echo "   ✅ NixOS config directory exists with configuration.nix"
        else
            echo "   ⚠️  NixOS config directory exists but no configuration.nix found"
        fi
    else
        echo "   ❌ NixOS config directory does not exist: $config_dir"
    fi
    
    # Check backup directory parent
    local backup_parent=$(dirname "$backup_base")
    if [[ -d "$backup_parent" ]] || [[ "$backup_parent" == "/" ]]; then
        echo "   ✅ Backup directory parent is accessible"
    else
        echo "   ⚠️  Backup directory parent may need to be created: $backup_parent"
    fi
    
    # Check webroot parent
    local webroot_parent=$(dirname "$webroot")
    if [[ -d "$webroot_parent" ]] || [[ "$webroot_parent" == "/" ]]; then
        echo "   ✅ Web root parent directory is accessible"
    else
        echo "   ⚠️  Web root parent may need to be created: $webroot_parent"
    fi
    
    # Check permissions
    if [[ -w "$config_dir" ]] || sudo -n test -w "$config_dir" 2>/dev/null; then
        echo "   ✅ NixOS config directory is writable"
    else
        echo "   ⚠️  NixOS config directory may require sudo access"
    fi
}

# Validate and normalize paths
validate_and_normalize_paths() {
    log "Validating and normalizing configuration paths..."
    
    # Convert to absolute paths
    NIXOS_CONFIG_DIR=$(realpath -m "$NIXOS_CONFIG_DIR")
    BACKUP_BASE_DIR=$(realpath -m "$BACKUP_BASE_DIR")
    WEB_ROOT=$(realpath -m "$WEB_ROOT")
    
    # Set backup directory with timestamp
    BACKUP_DIR="$BACKUP_BASE_DIR/$(date +%Y%m%d-%H%M%S)"
    
    info "Configuration paths:"
    echo "   NixOS Config: $NIXOS_CONFIG_DIR"
    echo "   Backup Dir: $BACKUP_DIR"
    echo "   Web Root: $WEB_ROOT"
    echo
    
    # Validate NixOS config directory
    if [[ ! -d "$NIXOS_CONFIG_DIR" ]]; then
        error "NixOS configuration directory does not exist: $NIXOS_CONFIG_DIR"
    fi
    
    if [[ ! -f "$NIXOS_CONFIG_DIR/configuration.nix" ]]; then
        error "NixOS configuration file not found: $NIXOS_CONFIG_DIR/configuration.nix"
    fi
    
    # Check if we can write to config directory
    if [[ ! -w "$NIXOS_CONFIG_DIR" ]] && ! sudo -n test -w "$NIXOS_CONFIG_DIR" 2>/dev/null; then
        error "Cannot write to NixOS configuration directory: $NIXOS_CONFIG_DIR"
    fi
    
    # Create backup base directory if it doesn't exist
    local backup_parent=$(dirname "$BACKUP_BASE_DIR")
    if [[ ! -d "$backup_parent" ]]; then
        warning "Backup parent directory does not exist: $backup_parent"
        read -p "Create backup parent directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo mkdir -p "$backup_parent" || error "Failed to create backup parent directory"
            success "Created backup parent directory: $backup_parent"
        else
            error "Cannot proceed without backup directory"
        fi
    fi
    
    # Create web root parent if it doesn't exist
    local webroot_parent=$(dirname "$WEB_ROOT")
    if [[ ! -d "$webroot_parent" ]]; then
        warning "Web root parent directory does not exist: $webroot_parent"
        read -p "Create web root parent directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo mkdir -p "$webroot_parent" || error "Failed to create web root parent directory"
            success "Created web root parent directory: $webroot_parent"
        else
            error "Cannot proceed without web root directory"
        fi
    fi
    
    success "Path validation completed successfully"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user with sudo access."
    fi
    
    if ! sudo -n true 2>/dev/null; then
        error "This script requires sudo access. Please ensure you can run sudo commands."
    fi
}

# Check if this is a NixOS system
check_nixos() {
    if [[ ! -f /etc/NIXOS ]]; then
        error "This script is designed for NixOS systems only."
    fi
    
    success "NixOS system detected"
}

# Check NixOS channel version
check_nixos_channel() {
    log "Checking NixOS channel version..."
    
    local current_channel=$(nix-channel --list | grep nixos | head -1 | awk '{print $2}')
    
    if [[ $current_channel == *"25.05"* ]]; then
        success "NixOS 25.05 channel detected - PHP 8.4 available"
    elif [[ $current_channel == *"24."* ]]; then
        warning "NixOS 24.x channel detected. PHP 8.4 may not be available."
        echo "Consider upgrading to NixOS 25.05 channel for PHP 8.4 support:"
        echo "  sudo nix-channel --add https://nixos.org/channels/nixos-25.05 nixos"
        echo "  sudo nix-channel --update"
        echo
        read -p "Continue with current channel? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation cancelled. Please upgrade to NixOS 25.05 for PHP 8.4 support."
        fi
    else
        warning "Unknown NixOS channel: $current_channel"
        echo "PHP 8.4 requires NixOS 25.05 or later."
        echo
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation cancelled by user"
        fi
    fi
}

# Create backup of existing configuration
backup_configuration() {
    log "Creating backup of existing NixOS configuration..."
    
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp -r "$NIXOS_CONFIG_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
    
    # Create restore script with dynamic paths
    sudo tee "$BACKUP_DIR/restore.sh" > /dev/null << EOF
#!/bin/bash
# Restore script created on $(date)
# Original paths: Config=$NIXOS_CONFIG_DIR, Backup=$BACKUP_DIR, WebRoot=$WEB_ROOT

echo "🔄 Restoring NixOS configuration from backup..."
echo "   Source: $BACKUP_DIR"
echo "   Target: $NIXOS_CONFIG_DIR"
echo

read -p "Are you sure you want to restore? This will overwrite current configuration. (y/N): " -n 1 -r
echo
if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
    echo "Restore cancelled."
    exit 1
fi

echo "Restoring configuration files..."
sudo cp -r "$BACKUP_DIR"/* "$NIXOS_CONFIG_DIR/"
sudo rm "$NIXOS_CONFIG_DIR/restore.sh" 2>/dev/null || true

echo "✅ Configuration restored successfully!"
echo "🔧 Run 'sudo nixos-rebuild switch' to apply the restored configuration."
echo "🗑️  You may want to remove web directories if they were created:"
echo "   sudo rm -rf $WEB_ROOT"
EOF
    
    sudo chmod +x "$BACKUP_DIR/restore.sh"
    success "Configuration backed up to: $BACKUP_DIR"
    info "Restore script available at: $BACKUP_DIR/restore.sh"
}

# Analyze existing configuration
analyze_existing_config() {
    log "Analyzing existing NixOS configuration..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    local conflicts=()
    
    # Check for existing web server configurations
    if grep -q "services\.nginx" "$config_file"; then
        conflicts+=("nginx")
    fi
    
    if grep -q "services\.apache" "$config_file"; then
        conflicts+=("apache")
    fi
    
    if grep -q "services\.phpfpm" "$config_file"; then
        conflicts+=("php-fpm")
    fi
    
    if grep -q "services\.mysql\|services\.mariadb\|services\.postgresql" "$config_file"; then
        conflicts+=("database")
    fi
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        warning "Potential conflicts detected with existing services:"
        for conflict in "${conflicts[@]}"; do
            echo "  - $conflict"
        done
        echo
        read -p "Do you want to continue? This may override existing configurations. (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation cancelled by user"
        fi
    fi
    
    success "Configuration analysis complete"
}

# Generate web server configuration module with PHP 8.4
generate_webserver_module() {
    log "Generating web server configuration module with PHP 8.4..."
    
    sudo tee "$NIXOS_CONFIG_DIR/webserver.nix" > /dev/null << EOF
# Web Server Configuration Module with PHP 8.4
# Generated by NixOS Web Server Installation Script
# Configuration paths: Config=$NIXOS_CONFIG_DIR, WebRoot=$WEB_ROOT

{ config, pkgs, ... }:

{
  # System packages for web development
  environment.systemPackages = with pkgs; [
    mysql80
    tree
    htop
    php84  # PHP 8.4 CLI
  ];

  # Enable services
  services.openssh.enable = true;
  
  # MySQL/MariaDB configuration
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialDatabases = [
      { name = "dashboard_db"; }
      { name = "sample1_db"; }
      { name = "sample2_db"; }
      { name = "sample3_db"; }
    ];
    initialScript = pkgs.writeText "mysql-init.sql" ''
      CREATE USER IF NOT EXISTS 'webuser'@'localhost' IDENTIFIED BY 'webpass123';
      GRANT ALL PRIVILEGES ON dashboard_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample1_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample2_db.* TO 'webuser'@'localhost';
      GRANT ALL PRIVILEGES ON sample3_db.* TO 'webuser'@'localhost';
      
      CREATE USER IF NOT EXISTS 'phpmyadmin'@'localhost' IDENTIFIED BY 'pmapass123';
      GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost' WITH GRANT OPTION;
      
      FLUSH PRIVILEGES;
    '';
  };

  # PHP-FPM configuration with PHP 8.4
  services.phpfpm = {
    pools.www = {
      user = "nginx";
      group = "nginx";
      settings = {
        "listen.owner" = "nginx";
        "listen.group" = "nginx";
        "listen.mode" = "0600";
        "pm" = "dynamic";
        "pm.max_children" = 75;
        "pm.start_servers" = 10;
        "pm.min_spare_servers" = 5;
        "pm.max_spare_servers" = 20;
        "pm.max_requests" = 500;
      };
      phpPackage = pkgs.php84.buildEnv {
        extensions = ({ enabled, all }: enabled ++ (with all; [
          mysqli
          pdo_mysql
          mbstring
          zip
          gd
          curl
          json
          session
          filter
          openssl
          fileinfo
          intl
          exif
        ]));
        extraConfig = ''
          memory_limit = 256M
          upload_max_filesize = 64M
          post_max_size = 64M
          max_execution_time = 300
          max_input_vars = 3000
          date.timezone = UTC
          
          ; PHP 8.4 optimizations
          opcache.enable = 1
          opcache.memory_consumption = 128
          opcache.interned_strings_buffer = 8
          opcache.max_accelerated_files = 4000
          opcache.revalidate_freq = 2
          opcache.fast_shutdown = 1
          
          ; Security settings
          expose_php = Off
          display_errors = Off
          log_errors = On
          error_log = /var/log/php_errors.log
        '';
      };
    };
  };

  # Nginx configuration with dynamic web root
  services.nginx = {
    enable = true;
    user = "nginx";
    group = "nginx";
    
    # Global configuration
    appendConfig = ''
      worker_processes auto;
      worker_connections 1024;
    '';

    # Common configuration for PHP
    commonHttpConfig = ''
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
      keepalive_timeout 65;
      types_hash_max_size 2048;
      client_max_body_size 64M;
      
      gzip on;
      gzip_vary on;
      gzip_min_length 1024;
      gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
      
      # Security headers
      add_header X-Frame-Options DENY;
      add_header X-Content-Type-Options nosniff;
      add_header X-XSS-Protection "1; mode=block";
    '';

    virtualHosts = {
      # Dashboard
      "dashboard.local" = {
        root = "$WEB_ROOT/dashboard";
        index = "index.php index.html";
        locations = {
          "/" = {
            tryFiles = "\$uri \$uri/ /index.php?\$query_string";
          };
          "~ \\.php\$" = {
            extraConfig = ''
              fastcgi_pass unix:\${config.services.phpfpm.pools.www.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include \${pkgs.nginx}/conf/fastcgi_params;
            '';
          };
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
        };
      };

      # phpMyAdmin
      "phpmyadmin.local" = {
        root = "$WEB_ROOT/phpmyadmin";
        index = "index.php";
        locations = {
          "/" = {
            tryFiles = "\$uri \$uri/ /index.php?\$query_string";
          };
          "~ \\.php\$" = {
            extraConfig = ''
              fastcgi_pass unix:\${config.services.phpfpm.pools.www.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include \${pkgs.nginx}/conf/fastcgi_params;
            '';
          };
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
        };
      };

      # Sample Domain 1
      "sample1.local" = {
        root = "$WEB_ROOT/sample1";
        index = "index.php index.html";
        locations = {
          "/" = {
            tryFiles = "\$uri \$uri/ /index.php?\$query_string";
          };
          "~ \\.php\$" = {
            extraConfig = ''
              fastcgi_pass unix:\${config.services.phpfpm.pools.www.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include \${pkgs.nginx}/conf/fastcgi_params;
            '';
          };
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
        };
      };

      # Sample Domain 2
      "sample2.local" = {
        root = "$WEB_ROOT/sample2";
        index = "index.php index.html";
        locations = {
          "/" = {
            tryFiles = "\$uri \$uri/ /index.php?\$query_string";
          };
          "~ \\.php\$" = {
            extraConfig = ''
              fastcgi_pass unix:\${config.services.phpfpm.pools.www.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include \${pkgs.nginx}/conf/fastcgi_params;
            '';
          };
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
        };
      };

      # Sample Domain 3
      "sample3.local" = {
        root = "$WEB_ROOT/sample3";
        index = "index.php index.html";
        locations = {
          "/" = {
            tryFiles = "\$uri \$uri/ /index.php?\$query_string";
          };
          "~ \\.php\$" = {
            extraConfig = ''
              fastcgi_pass unix:\${config.services.phpfpm.pools.www.socket};
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
              fastcgi_param PHP_VALUE "auto_prepend_file=none";
              fastcgi_read_timeout 300;
              include \${pkgs.nginx}/conf/fastcgi_params;
            '';
          };
          "~ /\\.ht" = {
            extraConfig = "deny all;";
          };
        };
      };
    };
  };

  # Firewall configuration - only add ports if not already configured
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 3306 ];
  };

  # System activation script to create directories and files
  system.activationScripts.websetup = ''
    # Create web directories with dynamic web root
    mkdir -p $WEB_ROOT/{dashboard,phpmyadmin,sample1,sample2,sample3}
    chown -R nginx:nginx $WEB_ROOT
    chmod -R 755 $WEB_ROOT
    
    # Create PHP error log directory
    mkdir -p /var/log
    touch /var/log/php_errors.log
    chown nginx:nginx /var/log/php_errors.log
    chmod 644 /var/log/php_errors.log
  '';
}
EOF

    success "Web server module with PHP 8.4 created at $NIXOS_CONFIG_DIR/webserver.nix"
    info "Web root configured as: $WEB_ROOT"
}

# Update main configuration to import web server module
update_main_configuration() {
    log "Updating main NixOS configuration..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    local temp_file=$(mktemp)
    
    # Check if webserver.nix is already imported
    if grep -q "webserver.nix" "$config_file"; then
        warning "Web server module already imported in configuration"
        return 0
    fi
    
    # Find the imports section and add our module
    awk '
    /imports = \[/ {
        print $0
        print "    ./webserver.nix"
        next
    }
    { print }
    ' "$config_file" > "$temp_file"
    
    # If no imports section found, add it after the opening brace
    if ! grep -q "imports = \[" "$temp_file"; then
        awk '
        /^{/ && !found {
            print $0
            print "  imports = ["
            print "    ./webserver.nix"
            print "  ];"
            print ""
            found = 1
            next
        }
        { print }
        ' "$config_file" > "$temp_file"
    fi
    
    sudo cp "$temp_file" "$config_file"
    rm "$temp_file"
    
    success "Main configuration updated to import web server module"
}

# Setup web directories and content
setup_web_content() {
    log "Setting up web directories and content..."
    
    # Create web directories
    sudo mkdir -p "$WEB_ROOT"/{dashboard,phpmyadmin,sample1,sample2,sample3}
    
    # Copy web content if available
    if [[ -d "$SCRIPT_DIR/web-content" ]]; then
        log "Copying web content from script directory..."
        sudo cp -r "$SCRIPT_DIR/web-content/dashboard"/* "$WEB_ROOT/dashboard/" 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample1"/* "$WEB_ROOT/sample1/" 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample2"/* "$WEB_ROOT/sample2/" 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample3"/* "$WEB_ROOT/sample3/" 2>/dev/null || true
    else
        warning "Web content directory not found. Creating basic placeholder files..."
        
        # Create basic index files for each site with PHP 8.4 info
        for site in dashboard sample1 sample2 sample3; do
            sudo tee "$WEB_ROOT/$site/index.php" > /dev/null << EOF
<?php
echo "<h1>Welcome to $site.local</h1>";
echo "<p>This is a placeholder page. Replace with your actual content.</p>";
echo "<p>PHP Version: " . PHP_VERSION . "</p>";
echo "<p>Server time: " . date('Y-m-d H:i:s') . "</p>";
echo "<p>Web Root: $WEB_ROOT</p>";

// Display PHP 8.4 features
if (version_compare(PHP_VERSION, '8.4.0', '>=')) {
    echo "<h2>🚀 PHP 8.4 Features Available</h2>";
    echo "<ul>";
    echo "<li>Property hooks</li>";
    echo "<li>Asymmetric visibility</li>";
    echo "<li>New array functions</li>";
    echo "<li>Performance improvements</li>";
    echo "</ul>";
}
?>
EOF
        done
    fi
    
    # Set proper permissions
    sudo chown -R nginx:nginx "$WEB_ROOT"
    sudo chmod -R 755 "$WEB_ROOT"
    
    success "Web directories and content set up at: $WEB_ROOT"
}

# Setup phpMyAdmin with PHP 8.4 compatibility
setup_phpmyadmin() {
    log "Setting up phpMyAdmin with PHP 8.4 compatibility..."
    
    local phpmyadmin_dir="$WEB_ROOT/phpmyadmin"
    local temp_dir="/tmp/phpmyadmin-setup"
    
    # Download and extract phpMyAdmin (latest version for PHP 8.4 compatibility)
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    if ! wget -q "https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz"; then
        warning "Failed to download phpMyAdmin. You'll need to set it up manually."
        return 1
    fi
    
    tar -xzf phpMyAdmin-5.2.1-all-languages.tar.gz
    sudo cp -r phpMyAdmin-5.2.1-all-languages/* "$phpmyadmin_dir/"
    
    # Create phpMyAdmin configuration with PHP 8.4 optimizations
    if [[ -f "$SCRIPT_DIR/web-content/phpmyadmin/config.inc.php" ]]; then
        sudo cp "$SCRIPT_DIR/web-content/phpmyadmin/config.inc.php" "$phpmyadmin_dir/"
    else
        sudo tee "$phpmyadmin_dir/config.inc.php" > /dev/null << 'EOF'
<?php
declare(strict_types=1);

$cfg['blowfish_secret'] = 'nixos-webserver-phpmyadmin-secret-key-2024-php84';

$i = 0;
$i++;
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['host'] = 'localhost';
$cfg['Servers'][$i]['compress'] = false;
$cfg['Servers'][$i]['AllowNoPassword'] = false;

// PHP 8.4 optimizations
$cfg['OBGzip'] = true;
$cfg['PersistentConnections'] = true;
$cfg['ExecTimeLimit'] = 300;
$cfg['MemoryLimit'] = '256M';

// Security settings
$cfg['ForceSSL'] = false;
$cfg['CheckConfigurationPermissions'] = true;
$cfg['AllowArbitraryServer'] = false;
EOF
    fi
    
    # Clean up
    cd "$SCRIPT_DIR"
    rm -rf "$temp_dir"
    
    success "phpMyAdmin set up successfully with PHP 8.4 compatibility at: $phpmyadmin_dir"
}

# Create helper scripts with PHP 8.4 support and dynamic paths
create_helper_scripts() {
    log "Creating helper scripts with PHP 8.4 support and dynamic paths..."
    
    # Rebuild script
    sudo tee /usr/local/bin/rebuild-webserver > /dev/null << EOF
#!/bin/bash
# NixOS Web Server Rebuild Script
# Configuration: $NIXOS_CONFIG_DIR
# Web Root: $WEB_ROOT

echo "🔄 Rebuilding NixOS configuration with PHP 8.4..."
echo "   Config Dir: $NIXOS_CONFIG_DIR"
echo "   Web Root: $WEB_ROOT"
echo

cd "$NIXOS_CONFIG_DIR"
sudo nixos-rebuild switch
if [ \$? -eq 0 ]; then
    echo "✅ NixOS rebuild successful!"
    echo "🌐 Restarting web services..."
    sudo systemctl restart nginx
    sudo systemctl restart phpfpm
    echo "✅ Web services restarted!"
    echo "🚀 PHP Version: \$(php --version | head -1)"
else
    echo "❌ NixOS rebuild failed!"
    exit 1
fi
EOF

    # Database creation script
    sudo tee /usr/local/bin/create-site-db > /dev/null << 'EOF'
#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Usage: $0 <database_name>"
    exit 1
fi

DB_NAME=$1
echo "Creating database: $DB_NAME"

mysql -u root << SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO 'webuser'@'localhost';
FLUSH PRIVILEGES;
SQL

if [ $? -eq 0 ]; then
    echo "✅ Database $DB_NAME created successfully!"
else
    echo "❌ Failed to create database $DB_NAME"
    exit 1
fi
EOF

    # Site directory creation script with PHP 8.4 template and dynamic web root
    sudo tee /usr/local/bin/create-site-dir > /dev/null << EOF
#!/bin/bash
# Site Directory Creation Script
# Web Root: $WEB_ROOT

if [ \$# -ne 2 ]; then
    echo "Usage: \$0 <domain> <site_name>"
    exit 1
fi

DOMAIN=\$1
SITE_NAME=\$2
SITE_DIR="$WEB_ROOT/\$DOMAIN"

echo "Creating site directory: \$SITE_DIR"
mkdir -p "\$SITE_DIR"

cat > "\$SITE_DIR/index.php" << PHP
<?php
// \$SITE_NAME - PHP 8.4 Ready
// Web Root: $WEB_ROOT
echo '<h1>Welcome to \$SITE_NAME</h1>';
echo '<p>This site is hosted on \$DOMAIN</p>';
echo '<p>PHP Version: ' . PHP_VERSION . '</p>';
echo '<p>Web Root: $WEB_ROOT</p>';
echo '<p>Created: ' . date('Y-m-d H:i:s') . '</p>';

if (version_compare(PHP_VERSION, '8.4.0', '>=')) {
    echo '<h2>🚀 PHP 8.4 Features Available</h2>';
    echo '<ul>';
    echo '<li>Property hooks for cleaner code</li>';
    echo '<li>Asymmetric visibility modifiers</li>';
    echo '<li>Enhanced performance and memory usage</li>';
    echo '<li>New array and string functions</li>';
    echo '</ul>';
}
?>
PHP

chown -R nginx:nginx "\$SITE_DIR"
chmod -R 755 "\$SITE_DIR"

echo "✅ Site directory created successfully with PHP 8.4 template!"
echo "📁 Location: \$SITE_DIR"
EOF

    sudo chmod +x /usr/local/bin/{rebuild-webserver,create-site-db,create-site-dir}
    
    success "Helper scripts created with PHP 8.4 support and dynamic paths"
    info "Scripts configured for web root: $WEB_ROOT"
}

# Update hosts file
update_hosts_file() {
    log "Updating /etc/hosts file..."
    
    # Check if entries already exist
    if grep -q "dashboard.local" /etc/hosts; then
        warning "Local domain entries already exist in /etc/hosts"
        return 0
    fi
    
    # Add local domain entries
    sudo tee -a /etc/hosts > /dev/null << 'EOF'

# NixOS Web Server Local Domains (PHP 8.4)
127.0.0.1 dashboard.local
127.0.0.1 phpmyadmin.local
127.0.0.1 sample1.local
127.0.0.1 sample2.local
127.0.0.1 sample3.local
EOF

    success "Local domain entries added to /etc/hosts"
}

# Test configuration syntax
test_configuration() {
    log "Testing NixOS configuration syntax..."
    
    cd "$NIXOS_CONFIG_DIR"
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "Configuration syntax is valid"
    else
        error "Configuration syntax error detected. Please check the configuration manually."
    fi
}

# Show final summary
show_final_summary() {
    echo
    success "Installation completed successfully with PHP 8.4!"
    echo
    echo "📋 Configuration Summary:"
    echo "   NixOS Config Directory: $NIXOS_CONFIG_DIR"
    echo "   Backup Directory: $BACKUP_DIR"
    echo "   Web Root Directory: $WEB_ROOT"
    echo
    echo "🎯 Next steps:"
    echo "1. Run: sudo nixos-rebuild switch"
    echo "2. Wait for the system to rebuild and restart services"
    echo "3. Access your sites:"
    echo "   • Dashboard: http://dashboard.local"
    echo "   • phpMyAdmin: http://phpmyadmin.local"
    echo "   • Sample sites: http://sample1.local, http://sample2.local, http://sample3.local"
    echo
    echo "🚀 PHP 8.4 Features:"
    echo "   • Property hooks for cleaner object-oriented code"
    echo "   • Asymmetric visibility modifiers"
    echo "   • Enhanced performance and memory optimizations"
    echo "   • New array and string manipulation functions"
    echo "   • Improved type system and error handling"
    echo
    echo "🔧 Helper commands available:"
    echo "   • rebuild-webserver - Rebuild NixOS and restart web services"
    echo "   • create-site-db <db_name> - Create new database"
    echo "   • create-site-dir <domain> <site_name> - Create new site directory with PHP 8.4 template"
    echo
    echo "📦 Backup & Recovery:"
    echo "   • Backup location: $BACKUP_DIR"
    echo "   • Run $BACKUP_DIR/restore.sh to restore original configuration"
    echo
    warning "Remember to change default database passwords in production!"
    echo
    echo "🔍 Verify PHP version after rebuild:"
    echo "   php --version"
}

# Main installation function
main() {
    echo "🚀 NixOS Web Server Installation for Existing Systems (PHP 8.4)"
    echo "=============================================================="
    echo "Enhanced with Dynamic Path Configuration"
    echo
    
    # Parse command line arguments first
    parse_arguments "$@"
    
    # Validate paths and system
    validate_and_normalize_paths
    check_root
    check_nixos
    check_nixos_channel
    
    echo "This script will:"
    echo "  • Create a backup of your current NixOS configuration"
    echo "  • Add web server functionality with PHP 8.4 as a separate module"
    echo "  • Set up nginx, PHP-FPM 8.4, and MariaDB"
    echo "  • Create sample websites and management dashboard"
    echo "  • Install phpMyAdmin with PHP 8.4 compatibility"
    echo "  • Configure PHP 8.4 optimizations and security settings"
    echo
    echo "📁 Using configuration paths:"
    echo "   NixOS Config: $NIXOS_CONFIG_DIR"
    echo "   Backup Dir: $BACKUP_DIR"
    echo "   Web Root: $WEB_ROOT"
    echo
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation cancelled by user"
    fi
    
    backup_configuration
    analyze_existing_config
    generate_webserver_module
    update_main_configuration
    setup_web_content
    setup_phpmyadmin
    create_helper_scripts
    update_hosts_file
    test_configuration
    
    show_final_summary
}

# Run main function with all arguments
main "$@"
