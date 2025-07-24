#!/usr/bin/env bash

# Fix PHP Optimization Module
# This script fixes the php-optimization.nix module to remove invalid options

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_CONFIG_DIR="/etc/nixos"
PHP_OPT_MODULE="$NIXOS_CONFIG_DIR/modules/webserver/php-optimization.nix"
PROJECT_PHP_OPT="$SCRIPT_DIR/modules/webserver/php-optimization.nix"

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

# Check current php-optimization.nix
check_current_module() {
    log "Checking current php-optimization.nix module..."
    
    if [[ -f "$PHP_OPT_MODULE" ]]; then
        echo "Current module location: $PHP_OPT_MODULE"
        
        # Check for problematic lines
        if grep -q "services\.phpfpm\.enable" "$PHP_OPT_MODULE"; then
            error "Found services.phpfpm.enable (invalid option)"
        fi
        
        if grep -q "json" "$PHP_OPT_MODULE"; then
            warning "Found 'json' extension (built-in to PHP 8.4)"
        fi
        
        if grep -q "session" "$PHP_OPT_MODULE"; then
            warning "Found 'session' extension (built-in to PHP 8.4)"
        fi
        
        if grep -q "filter" "$PHP_OPT_MODULE"; then
            warning "Found 'filter' extension (built-in to PHP 8.4)"
        fi
    else
        error "php-optimization.nix not found at $PHP_OPT_MODULE"
        return 1
    fi
}

# Create fixed php-optimization.nix
create_fixed_module() {
    log "Creating fixed php-optimization.nix module..."
    
    # Backup existing module
    if [[ -f "$PHP_OPT_MODULE" ]]; then
        sudo cp "$PHP_OPT_MODULE" "$PHP_OPT_MODULE.backup-$(date +%Y%m%d-%H%M%S)"
        success "Created backup of existing module"
    fi
    
    # Create fixed module
    sudo tee "$PHP_OPT_MODULE" > /dev/null << 'EOF'
# Webserver PHP Optimization Configuration
# This module adds webserver-specific PHP optimizations to existing PHP configuration

{ config, pkgs, lib, ... }:

{
  # PHP-FPM webserver-specific configuration
  # This enhances the existing PHP configuration with webserver optimizations
  # Note: PHP-FPM is automatically enabled when pools are configured
  
  services.phpfpm = {
    # Configure webserver-specific PHP pool
    pools.www = lib.mkMerge [
      {
        # Pool configuration optimized for webserver
        user = lib.mkDefault "nginx";
        group = lib.mkDefault "nginx";
        
        settings = {
          "listen.owner" = lib.mkDefault "nginx";
          "listen.group" = lib.mkDefault "nginx";
          "listen.mode" = lib.mkDefault "0600";
          
          # Performance optimization for webserver
          "pm" = lib.mkDefault "dynamic";
          "pm.max_children" = lib.mkDefault 75;
          "pm.start_servers" = lib.mkDefault 10;
          "pm.min_spare_servers" = lib.mkDefault 5;
          "pm.max_spare_servers" = lib.mkDefault 20;
          "pm.max_requests" = lib.mkDefault 500;
          
          # Webserver-specific settings
          "pm.process_idle_timeout" = lib.mkDefault "10s";
          "pm.status_path" = lib.mkDefault "/status";
          "ping.path" = lib.mkDefault "/ping";
          "ping.response" = lib.mkDefault "pong";
          
          # Request optimization
          "request_terminate_timeout" = lib.mkDefault "300s";
          "request_slowlog_timeout" = lib.mkDefault "10s";
          "slowlog" = lib.mkDefault "/var/log/php-fpm-slow.log";
        };
        
        # PHP package with webserver-specific extensions and configuration
        phpPackage = lib.mkDefault (pkgs.php.buildEnv {
          extensions = ({ enabled, all }: enabled ++ (with pkgs.php84Extensions; [
            # Database extensions
            mysqli
            pdo_mysql
            
            # String/text processing
            mbstring
            intl
            
            # File handling
            zip
            fileinfo
            
            # Graphics
            gd
            exif
            
            # Network
            curl
            openssl
            
            # Note: json, session, filter are built-in to PHP 8.4
          ]));
          
          extraConfig = ''
            # Webserver-specific PHP configuration
            
            # Memory and execution limits
            memory_limit = 256M
            max_execution_time = 300
            max_input_time = 300
            max_input_vars = 3000
            
            # File upload configuration
            upload_max_filesize = 64M
            post_max_size = 64M
            max_file_uploads = 20
            
            # Session configuration
            session.gc_maxlifetime = 3600
            session.gc_probability = 1
            session.gc_divisor = 1000
            session.cookie_httponly = On
            session.use_strict_mode = On
            
            # Security settings
            expose_php = Off
            display_errors = Off
            log_errors = On
            error_log = /var/log/php_errors.log
            allow_url_fopen = Off
            allow_url_include = Off
            
            # Performance optimization
            realpath_cache_size = 4096k
            realpath_cache_ttl = 600
            
            # OPcache optimization for PHP 8.4
            opcache.enable = 1
            opcache.memory_consumption = 128
            opcache.interned_strings_buffer = 8
            opcache.max_accelerated_files = 4000
            opcache.revalidate_freq = 2
            opcache.fast_shutdown = 1
            opcache.enable_cli = 1
            opcache.save_comments = 0
            opcache.validate_timestamps = 1
            
            # JIT optimization (PHP 8.4 feature)
            opcache.jit_buffer_size = 64M
            opcache.jit = tracing
            
            # Timezone
            date.timezone = UTC
          '';
        });
      }
    ];
  };

  # Create PHP error log directory
  system.activationScripts.webserver-php-logs = ''
    mkdir -p /var/log
    touch /var/log/php_errors.log
    touch /var/log/php-fpm-slow.log
    chown nginx:nginx /var/log/php_errors.log
    chown nginx:nginx /var/log/php-fpm-slow.log
    chmod 644 /var/log/php_errors.log
    chmod 644 /var/log/php-fpm-slow.log
  '';

  # Add PHP CLI to system packages
  environment.systemPackages = with pkgs; [
    php  # PHP 8.4 CLI tools
  ];

  # Log rotation for PHP logs
  services.logrotate.settings = {
    "/var/log/php_errors.log" = {
      frequency = "daily";
      rotate = 7;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      copytruncate = true;
    };
    
    "/var/log/php-fpm-slow.log" = {
      frequency = "daily";
      rotate = 7;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      postrotate = "systemctl reload phpfpm-www";
    };
  };
}
EOF

    success "Created fixed php-optimization.nix module"
}

# Update project module too
update_project_module() {
    log "Updating project module..."
    
    if [[ -f "$PROJECT_PHP_OPT" ]]; then
        # Backup project module
        cp "$PROJECT_PHP_OPT" "$PROJECT_PHP_OPT.backup-$(date +%Y%m%d-%H%M%S)"
        
        # Copy the fixed version back to project
        sudo cp "$PHP_OPT_MODULE" "$PROJECT_PHP_OPT"
        sudo chown $(whoami):$(whoami) "$PROJECT_PHP_OPT"
        
        success "Updated project module"
    else
        warning "Project module not found at $PROJECT_PHP_OPT"
    fi
}

# Test the fixed module
test_fixed_module() {
    log "Testing fixed module..."
    
    # Test syntax
    if nix-instantiate --parse "$PHP_OPT_MODULE" &>/dev/null; then
        success "Module syntax is valid"
    else
        error "Module syntax is invalid"
        nix-instantiate --parse "$PHP_OPT_MODULE" 2>&1 | head -5
        return 1
    fi
    
    # Test full configuration
    if sudo nixos-rebuild dry-build &>/dev/null; then
        success "Full configuration is valid"
        return 0
    else
        warning "Configuration still has issues:"
        sudo nixos-rebuild dry-build 2>&1 | head -10
        return 1
    fi
}

# Show what was fixed
show_fixes() {
    log "Summary of fixes applied:"
    echo ""
    echo "🔧 Fixed issues:"
    echo "  ✅ Removed services.phpfpm.enable (invalid option)"
    echo "  ✅ Removed json extension (built-in to PHP 8.4)"
    echo "  ✅ Removed session extension (built-in to PHP 8.4)"
    echo "  ✅ Removed filter extension (built-in to PHP 8.4)"
    echo ""
    echo "✅ Kept extensions that need explicit loading:"
    echo "  - mysqli (MySQL improved)"
    echo "  - pdo_mysql (PDO MySQL driver)"
    echo "  - mbstring (Multibyte string)"
    echo "  - intl (Internationalization)"
    echo "  - zip (ZIP archive)"
    echo "  - fileinfo (File information)"
    echo "  - gd (Image processing)"
    echo "  - exif (EXIF data)"
    echo "  - curl (HTTP client)"
    echo "  - openssl (SSL/TLS)"
    echo ""
}

# Main function
main() {
    echo "🔧 Fix PHP Optimization Module"
    echo "=============================="
    echo ""
    
    check_current_module
    
    echo ""
    echo "This will fix the php-optimization.nix module by:"
    echo "1. Removing services.phpfpm.enable (invalid option)"
    echo "2. Removing built-in PHP 8.4 extensions (json, session, filter)"
    echo "3. Keeping only extensions that need explicit loading"
    echo ""
    
    read -p "Proceed with fix? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    create_fixed_module
    update_project_module
    
    if test_fixed_module; then
        show_fixes
        
        echo ""
        echo "🎯 Next steps:"
        echo "1. Run: sudo nixos-rebuild switch"
        echo "2. The php-optimization.nix module should now work correctly"
        echo "3. PHP-FPM will be automatically enabled through pool configuration"
    else
        error "Module still has issues. Check the error output above."
    fi
}

# Run main function
main "$@"