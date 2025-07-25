#!/usr/bin/env bash

# NixOS Web Server Installation Script for Existing Systems (PHP 8.4)
# This script safely integrates web server functionality into existing NixOS installations
# Handles modular configuration structure with separate service modules
# System State Version: 25.05

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration - can be overridden via command line or interactive prompts
DEFAULT_NIXOS_CONFIG_DIR="/etc/nixos"
DEFAULT_BACKUP_DIR="/etc/nixos/webserver-backups/$(date +%Y%m%d-%H%M%S)"
DEFAULT_WEB_ROOT="/var/www"

# Initialize variables with defaults
NIXOS_CONFIG_DIR="$DEFAULT_NIXOS_CONFIG_DIR"
BACKUP_DIR="$DEFAULT_BACKUP_DIR"
WEB_ROOT="$DEFAULT_WEB_ROOT"

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

# Show help information
show_help() {
    echo "NixOS Web Server Installation Script (PHP 8.4) - System State 25.05"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --config-dir DIR     NixOS configuration directory (default: $DEFAULT_NIXOS_CONFIG_DIR)"
    echo "  -b, --backup-dir DIR     Backup directory (default: $DEFAULT_BACKUP_DIR)"
    echo "  -w, --web-root DIR       Web root directory (default: $DEFAULT_WEB_ROOT)"
    echo "  -i, --interactive        Interactive mode - prompt for all settings"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                          # Use all defaults"
    echo "  $0 -i                                       # Interactive mode"
    echo "  $0 -c /etc/nixos -w /srv/www               # Custom directories"
    echo "  $0 --config-dir /etc/nixos --interactive   # Custom config with interactive"
    echo ""
    echo "Default Configuration:"
    echo "  NixOS Config: $DEFAULT_NIXOS_CONFIG_DIR"
    echo "  Backup Dir:   $DEFAULT_BACKUP_DIR"
    echo "  Web Root:     $DEFAULT_WEB_ROOT"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config-dir)
                NIXOS_CONFIG_DIR="$2"
                shift 2
                ;;
            -b|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -w|--web-root)
                WEB_ROOT="$2"
                shift 2
                ;;
            -i|--interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use -h or --help for usage information."
                ;;
        esac
    done
}

# Interactive configuration
interactive_config() {
    echo -e "${CYAN}🔧 Interactive Configuration Mode${NC}"
    echo "Press Enter to use default values shown in brackets."
    echo ""
    
    read -p "NixOS configuration directory [$NIXOS_CONFIG_DIR]: " input
    NIXOS_CONFIG_DIR="${input:-$NIXOS_CONFIG_DIR}"
    
    read -p "Backup directory [$BACKUP_DIR]: " input
    BACKUP_DIR="${input:-$BACKUP_DIR}"
    
    read -p "Web root directory [$WEB_ROOT]: " input
    WEB_ROOT="${input:-$WEB_ROOT}"
    
    echo ""
    echo -e "${CYAN}📋 Configuration Summary:${NC}"
    echo "  NixOS Config: $NIXOS_CONFIG_DIR"
    echo "  Backup Dir:   $BACKUP_DIR"
    echo "  Web Root:     $WEB_ROOT"
    echo ""
    
    read -p "Continue with these settings? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation cancelled by user"
    fi
}

# Validate configuration paths
validate_config() {
    log "Validating configuration paths..."
    
    # Check if NixOS config directory exists
    if [[ ! -d "$NIXOS_CONFIG_DIR" ]]; then
        error "NixOS configuration directory does not exist: $NIXOS_CONFIG_DIR"
    fi
    
    # Check if configuration.nix exists
    if [[ ! -f "$NIXOS_CONFIG_DIR/configuration.nix" ]]; then
        error "NixOS configuration file not found: $NIXOS_CONFIG_DIR/configuration.nix"
    fi
    
    # Check write permissions
    if [[ ! -w "$NIXOS_CONFIG_DIR" ]]; then
        error "No write permission to NixOS configuration directory: $NIXOS_CONFIG_DIR"
    fi
    
    # Create backup directory parent if it doesn't exist
    local backup_parent=$(dirname "$BACKUP_DIR")
    if [[ ! -d "$backup_parent" ]]; then
        sudo mkdir -p "$backup_parent"
    fi
    
    # Validate web root parent directory
    local web_root_parent=$(dirname "$WEB_ROOT")
    if [[ ! -d "$web_root_parent" ]]; then
        warning "Web root parent directory does not exist: $web_root_parent"
        log "Will create during installation..."
    fi
    
    success "Configuration paths validated"
}

# Find the actual NixOS hosts file in /nix/store
find_nixos_hosts_file() {
    log "Locating NixOS hosts file in /nix/store..."
    
    # Search for hosts files in /nix/store with the pattern *-hosts
    local hosts_files=($(find /nix/store -maxdepth 1 -name "*-hosts" -type f 2>/dev/null | head -5))
    
    if [[ ${#hosts_files[@]} -eq 0 ]]; then
        warning "No hosts files found in /nix/store. Using /etc/hosts as fallback."
        echo "/etc/hosts"
        return 0
    fi
    
    # If multiple hosts files found, try to find the most recent or active one
    local active_hosts_file=""
    
    # Check if any of the hosts files contain localhost entries (indicating it's active)
    for hosts_file in "${hosts_files[@]}"; do
        if grep -q "127.0.0.1.*localhost" "$hosts_file" 2>/dev/null; then
            active_hosts_file="$hosts_file"
            break
        fi
    done
    
    # If no active hosts file found, use the first one
    if [[ -z "$active_hosts_file" ]]; then
        active_hosts_file="${hosts_files[0]}"
    fi
    
    log "Found NixOS hosts file: $active_hosts_file"
    echo "$active_hosts_file"
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
    
    if [[ ! -f "$NIXOS_CONFIG_DIR/configuration.nix" ]]; then
        error "NixOS configuration file not found at $NIXOS_CONFIG_DIR/configuration.nix"
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

# Scan for existing users and determine group memberships
scan_existing_users() {
    log "Scanning for existing users and determining group memberships..."
    
    # Get all regular users (UID >= 1000, excluding nobody)
    local existing_users=()
    while IFS=: read -r username _ uid gid _ _ home shell; do
        # Skip system users, nobody, and users with nologin/false shells
        if [[ $uid -ge 1000 && $username != "nobody" && $shell != "/sbin/nologin" && $shell != "/bin/false" && $shell != "/usr/sbin/nologin" ]]; then
            existing_users+=("$username")
        fi
    done < /etc/passwd
    
    if [[ ${#existing_users[@]} -eq 0 ]]; then
        warning "No existing regular users found"
        return 0
    fi
    
    echo -e "${CYAN}📋 Found existing users:${NC}"
    for user in "${existing_users[@]}"; do
        local user_groups=$(groups "$user" 2>/dev/null | cut -d: -f2 | tr ' ' '\n' | sort | tr '\n' ' ')
        echo "  👤 $user: groups($user_groups)"
    done
    
    echo ""
    echo -e "${CYAN}🔧 Web server group recommendations:${NC}"
    echo "  • wheel - sudo access for service management"
    echo "  • nginx - access to nginx configuration and logs"
    echo "  • www-data - access to web content directories"
    echo "  • mysql - database access and management"
    echo "  • redis - redis cache management"
    echo "  • systemd-journal - access to system logs"
    echo ""
    
    # Store users for later group assignment
    EXISTING_USERS=("${existing_users[@]}")
    
    success "User scan completed - found ${#existing_users[@]} users"
}

# Add existing users to web server groups
add_users_to_webserver_groups() {
    if [[ ${#EXISTING_USERS[@]} -eq 0 ]]; then
        log "No existing users to add to web server groups"
        return 0
    fi
    
    log "Adding existing users to web server groups for CLI access..."
    
    # Define the groups that provide web server CLI capabilities
    local web_groups=("wheel" "nginx" "www-data" "mysql" "redis" "systemd-journal")
    
    for user in "${EXISTING_USERS[@]}"; do
        log "Processing user: $user"
        
        # Get current user groups
        local current_groups=($(groups "$user" 2>/dev/null | cut -d: -f2))
        
        # Determine which groups to add
        local groups_to_add=()
        for group in "${web_groups[@]}"; do
            # Check if user is already in the group
            if ! printf '%s\n' "${current_groups[@]}" | grep -q "^$group$"; then
                # Check if group exists (some may not exist yet)
                if getent group "$group" >/dev/null 2>&1; then
                    groups_to_add+=("$group")
                fi
            fi
        done
        
        if [[ ${#groups_to_add[@]} -gt 0 ]]; then
            log "Adding $user to groups: ${groups_to_add[*]}"
            
            # Add user to each group
            for group in "${groups_to_add[@]}"; do
                if sudo usermod -a -G "$group" "$user" 2>/dev/null; then
                    success "Added $user to $group group"
                else
                    warning "Failed to add $user to $group group (group may not exist yet)"
                fi
            done
        else
            log "User $user already has appropriate group memberships"
        fi
    done
    
    # Store user group assignments for NixOS configuration
    USERS_FOR_NIXOS_CONFIG=("${EXISTING_USERS[@]}")
    
    success "User group assignments completed"
}

# Create backup of existing configuration
backup_configuration() {
    log "Creating backup of existing NixOS configuration..."
    
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp -r "$NIXOS_CONFIG_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
    
    # Also backup the current hosts file
    local current_hosts_file=$(find_nixos_hosts_file)
    if [[ -f "$current_hosts_file" ]]; then
        sudo cp "$current_hosts_file" "$BACKUP_DIR/hosts.backup"
        log "Hosts file backed up from: $current_hosts_file"
    fi
    
    # Create restore script
    sudo tee "$BACKUP_DIR/restore.sh" > /dev/null << EOF
#!/usr/bin/env bash
# Restore script created on $(date)
echo "Restoring NixOS configuration from backup..."
sudo cp -r "$BACKUP_DIR"/* "$NIXOS_CONFIG_DIR/"
sudo rm "$NIXOS_CONFIG_DIR/restore.sh"  # Remove this script
sudo rm "$NIXOS_CONFIG_DIR/hosts.backup" 2>/dev/null || true  # Remove hosts backup
echo "Configuration restored. Run 'sudo nixos-rebuild switch' to apply."
echo "Note: Hosts file changes require NixOS rebuild to take effect."
EOF
    
    sudo chmod +x "$BACKUP_DIR/restore.sh"
    success "Configuration backed up to: $BACKUP_DIR"
}

# Analyze existing configuration and imports structure
analyze_existing_config() {
    log "Analyzing existing NixOS configuration and imports structure..."
    
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
    
    # Analyze imports structure
    log "Analyzing imports structure..."
    
    if grep -q "imports = \[" "$config_file"; then
        success "Existing imports section found"
        
        # Extract current imports
        local imports_section=$(sed -n '/imports = \[/,/\];/p' "$config_file")
        echo "Current imports:"
        echo "$imports_section" | grep -E '\./|\.nix|<' | sed 's/^[[:space:]]*/  /'
        
        # Check if any service modules are already imported
        if echo "$imports_section" | grep -q "modules/services"; then
            warning "Service modules already imported in configuration"
        fi
    else
        warning "No imports section found - will create one"
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

# Create modular service configuration structure
create_service_modules() {
    log "Creating modular service configuration structure..."
    
    # Create modules directory structure
    sudo mkdir -p "$NIXOS_CONFIG_DIR/modules/services"
    
    # Create service modules with updated content
    log "Creating nginx.nix service module..."
    sudo tee "$NIXOS_CONFIG_DIR/modules/services/nginx.nix" > /dev/null << 'EOF'
# Nginx Web Server Configuration Module
# NixOS 25.05 Compatible
# High-performance web server with FastCGI caching

{ config, pkgs, ... }:

{
  # Nginx web server configuration
  services.nginx = {
    enable = true;
    user = "nginx";
    group = "nginx";
    
    # Performance optimization
    appendConfig = ''
      worker_processes auto;
      worker_connections 1024;
      worker_rlimit_nofile 2048;
      
      # Event handling optimization
      events {
        use epoll;
        multi_accept on;
      }
    '';

    # Global HTTP configuration with caching and security
    commonHttpConfig = ''
      # Basic performance settings
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
      keepalive_timeout 65;
      keepalive_requests 100;
      types_hash_max_size 2048;
      client_max_body_size 64M;
      client_body_timeout 12;
      client_header_timeout 12;
      send_timeout 10;
      
      # Buffer settings
      client_body_buffer_size 10K;
      client_header_buffer_size 1k;
      large_client_header_buffers 2 1k;
      
      # Gzip compression
      gzip on;
      gzip_vary on;
      gzip_min_length 1024;
      gzip_comp_level 6;
      gzip_proxied any;
      gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
      
      # FastCGI caching configuration
      fastcgi_cache_path /var/cache/nginx/fastcgi 
        levels=1:2 
        keys_zone=PHPFPM:100m 
        inactive=60m 
        max_size=1g;