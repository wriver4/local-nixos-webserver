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
    
    # Copy service modules from script directory
    if [[ -d "$SCRIPT_DIR/modules/services" ]]; then
        log "Copying service modules from script directory..."
        sudo cp -r "$SCRIPT_DIR/modules/services"/* "$NIXOS_CONFIG_DIR/modules/services/"
    else
        error "Service modules not found in script directory: $SCRIPT_DIR/modules/services"
    fi
    
    # Update web root paths in service modules if different from default
    if [[ "$WEB_ROOT" != "/var/www" ]]; then
        log "Updating web root paths in service modules..."
        sudo sed -i "s|/var/www|$WEB_ROOT|g" "$NIXOS_CONFIG_DIR/modules/services/nginx.nix"
        sudo sed -i "s|/var/www|$WEB_ROOT|g" "$NIXOS_CONFIG_DIR/modules/services/system.nix"
        sudo sed -i "s|/var/www|$WEB_ROOT|g" "$NIXOS_CONFIG_DIR/modules/services/users.nix"
    fi
    
    success "Service modules created successfully"
}

# Update main configuration to use modular structure
update_main_configuration() {
    log "Updating main NixOS configuration to use modular structure..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    local temp_file=$(mktemp)
    
    # Copy the new modular configuration.nix
    if [[ -f "$SCRIPT_DIR/configuration.nix" ]]; then
        sudo cp "$SCRIPT_DIR/configuration.nix" "$config_file"
        
        # Update system state version to 25.05
        sudo sed -i 's/system\.stateVersion = "[^"]*"/system.stateVersion = "25.05"/' "$config_file"
        
        # Update web root if different from default
        if [[ "$WEB_ROOT" != "/var/www" ]]; then
            sudo sed -i "s|/var/www|$WEB_ROOT|g" "$config_file"
        fi
        
        success "Main configuration updated with modular structure and system state 25.05"
    else
        error "Main configuration template not found: $SCRIPT_DIR/configuration.nix"
    fi
}

# Create nginx user and group immediately
create_nginx_user_group() {
    log "Creating nginx user and group..."
    
    # Check if nginx group exists
    if ! getent group nginx >/dev/null 2>&1; then
        log "Creating nginx group..."
        sudo groupadd -r nginx
        success "nginx group created"
    else
        log "nginx group already exists"
    fi
    
    # Check if nginx user exists
    if ! getent passwd nginx >/dev/null 2>&1; then
        log "Creating nginx user..."
        sudo useradd -r -g nginx -d /var/lib/nginx -s /sbin/nologin -c "nginx web server" nginx
        success "nginx user created"
    else
        log "nginx user already exists"
    fi
    
    # Create nginx home directory
    sudo mkdir -p /var/lib/nginx
    sudo chown nginx /var/lib/nginx
    sudo chgrp nginx /var/lib/nginx
    sudo chmod 755 /var/lib/nginx
    
    success "nginx user and group setup complete"
}

# Setup web directories and content
setup_web_content() {
    log "Setting up web directories and content..."
    
    # Create web directories
    sudo mkdir -p "$WEB_ROOT"/{dashboard,phpmyadmin,sample1,sample2,sample3,caching-scripts}
    sudo mkdir -p "$WEB_ROOT/caching-scripts"/{api,scripts}
    
    # Copy web content if available
    if [[ -d "$SCRIPT_DIR/web-content" ]]; then
        log "Copying web content from script directory..."
        sudo cp -r "$SCRIPT_DIR/web-content/dashboard"/* "$WEB_ROOT/dashboard/" 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample1"/* "$WEB_ROOT/sample1/" 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample2"/* "$WEB_ROOT/sample2/" 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/web-content/sample3"/* "$WEB_ROOT/sample3/" 2>/dev/null || true
        sudo cp -r "$SCRIPT_DIR/caching-scripts"/* "$WEB_ROOT/caching-scripts/" 2>/dev/null || true
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
        
        # Create basic caching scripts index
        sudo tee "$WEB_ROOT/caching-scripts/index.php" > /dev/null << 'EOF'
<?php
echo "<h1>Caching Scripts Management</h1>";
echo "<p>This is a placeholder for the caching scripts system.</p>";
echo "<p>PHP Version: " . PHP_VERSION . "</p>";
?>
EOF
    fi
    
    # Set proper permissions using separate chown and chgrp commands
    sudo chown -R nginx "$WEB_ROOT"
    sudo chgrp -R nginx "$WEB_ROOT"
    sudo chmod -R 755 "$WEB_ROOT"
    
    success "Web directories and content set up"
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
    
    # Set proper permissions for phpMyAdmin using separate commands
    sudo chown -R nginx "$phpmyadmin_dir"
    sudo chgrp -R nginx "$phpmyadmin_dir"
    sudo chmod -R 755 "$phpmyadmin_dir"
    
    # Clean up
    cd "$SCRIPT_DIR"
    rm -rf "$temp_dir"
    
    success "phpMyAdmin set up successfully with PHP 8.4 compatibility"
}

# Create helper scripts with PHP 8.4 support and NixOS hosts management
create_helper_scripts() {
    log "Creating helper scripts with PHP 8.4 support and NixOS hosts management..."
    
    # Rebuild script
    sudo tee /usr/local/bin/rebuild-webserver > /dev/null << 'EOF'
#!/usr/bin/env bash
echo "🔄 Rebuilding NixOS configuration with PHP 8.4 and modular services..."
sudo nixos-rebuild switch
if [ $? -eq 0 ]; then
    echo "✅ NixOS rebuild successful!"
    echo "🌐 Restarting web services..."
    sudo systemctl restart nginx
    sudo systemctl restart phpfpm-www
    echo "✅ Web services restarted!"
    echo "🚀 PHP Version: $(php --version | head -1)"
    echo "📍 Hosts file updated via NixOS configuration"
    echo "🏗️  System State Version: 25.05"
else
    echo "❌ NixOS rebuild failed!"
    exit 1
fi
EOF

    sudo chmod +x /usr/local/bin/rebuild-webserver

    # Database creation script
    sudo tee /usr/local/bin/create-site-db > /dev/null << 'EOF'
#!/usr/bin/env bash
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

    sudo chmod +x /usr/local/bin/create-site-db

    # Site directory creation script with PHP 8.4 template and NixOS hosts management
    sudo tee /usr/local/bin/create-site-dir > /dev/null << EOF
#!/usr/bin/env bash
if [ \$# -ne 2 ]; then
    echo "Usage: \$0 <domain> <site_name>"
    exit 1
fi

DOMAIN=\$1
SITE_NAME=\$2
SITE_DIR="$WEB_ROOT/\$DOMAIN"

echo "Creating site directory: \$SITE_DIR"
mkdir -p "\$SITE_DIR"

# Create PHP 8.4 optimized index.php
cat > "\$SITE_DIR/index.php" << PHP
<?php
// \$SITE_NAME - PHP 8.4 Ready
echo '<h1>Welcome to \$SITE_NAME</h1>';
echo '<p>This site is hosted on \$DOMAIN</p>';
echo '<p>PHP Version: ' . PHP_VERSION . '</p>';
echo '<p>Created: ' . date('Y-m-d H:i:s') . '</p>';

if (version_compare(PHP_VERSION, '8.4.0', '>=')) {
    echo '<h2>🚀 PHP 8.4 Features Available</h2>';
    echo '<ul>';
    echo '<li>Property hooks for cleaner object-oriented code</li>';
    echo '<li>Asymmetric visibility modifiers</li>';
    echo '<li>Enhanced performance and memory optimizations</li>';
    echo '<li>New array and string manipulation functions</li>';
    echo '<li>Improved type system and error handling</li>';
    echo '</ul>';
}
?>
PHP

# Set proper ownership using separate commands
chown -R nginx "\$SITE_DIR"
chgrp -R nginx "\$SITE_DIR"
chmod -R 755 "\$SITE_DIR"

echo "✅ Site directory created successfully with PHP 8.4 template!"
echo "📝 PHP 8.4 optimized index.php file created"
echo "🔐 Permissions set correctly"
echo ""
echo "⚠️  To add \$DOMAIN to hosts file:"
echo "   1. Edit $NIXOS_CONFIG_DIR/modules/services/networking.nix"
echo "   2. Add \"\$DOMAIN\" to networking.hosts.\"127.0.0.1\" array"
echo "   3. Run: sudo nixos-rebuild switch"
EOF

    sudo chmod +x /usr/local/bin/create-site-dir

    # NixOS hosts management script
    sudo tee /usr/local/bin/manage-nixos-hosts > /dev/null << EOF
#!/usr/bin/env bash

NETWORKING_CONFIG="$NIXOS_CONFIG_DIR/modules/services/networking.nix"

show_help() {
    echo "NixOS Hosts Management Script (Modular Configuration)"
    echo "Usage: \$0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  list                    - Show current local domains"
    echo "  add <domain>           - Add domain to NixOS hosts configuration"
    echo "  remove <domain>        - Remove domain from NixOS hosts configuration"
    echo "  rebuild                - Rebuild NixOS configuration to apply changes"
    echo "  show-current           - Show current active hosts file location"
    echo ""
    echo "Examples:"
    echo "  \$0 add mysite.local"
    echo "  \$0 remove oldsite.local"
    echo "  \$0 list"
}

find_current_hosts() {
    find /nix/store -maxdepth 1 -name "*-hosts" -type f 2>/dev/null | head -1
}

list_domains() {
    echo "Current local domains in NixOS configuration:"
    if [[ -f "\$NETWORKING_CONFIG" ]]; then
        grep -A 10 'networking.hosts' "\$NETWORKING_CONFIG" | grep -E '^\s*".*\.local"' | sed 's/[",]//g' | sed 's/^[[:space:]]*/  /'
    else
        echo "  networking.nix not found"
    fi
    
    echo ""
    echo "Active hosts file location:"
    local current_hosts=\$(find_current_hosts)
    if [[ -n "\$current_hosts" ]]; then
        echo "  \$current_hosts"
        echo ""
        echo "Active hosts entries:"
        grep "127.0.0.1.*\.local" "\$current_hosts" 2>/dev/null | sed 's/^/  /' || echo "  No .local entries found"
    else
        echo "  No hosts file found in /nix/store"
    fi
}

add_domain() {
    local domain=\$1
    if [[ -z "\$domain" ]]; then
        echo "Error: Domain name required"
        exit 1
    fi
    
    if [[ ! -f "\$NETWORKING_CONFIG" ]]; then
        echo "Error: networking.nix not found at \$NETWORKING_CONFIG"
        exit 1
    fi
    
    # Check if domain already exists
    if grep -q "\"\$domain\"" "\$NETWORKING_CONFIG"; then
        echo "Domain \$domain already exists in configuration"
        exit 0
    fi
    
    # Create backup
    sudo cp "\$NETWORKING_CONFIG" "\$NETWORKING_CONFIG.backup.\$(date +%Y%m%d-%H%M%S)"
    
    # Add domain to the hosts configuration
    sudo sed -i "/\"127.0.0.1\" = \[/a\\      \"\$domain\"" "\$NETWORKING_CONFIG"
    
    echo "✅ Added \$domain to NixOS hosts configuration"
    echo "🔄 Run 'sudo nixos-rebuild switch' or '\$0 rebuild' to apply changes"
}

remove_domain() {
    local domain=\$1
    if [[ -z "\$domain" ]]; then
        echo "Error: Domain name required"
        exit 1
    fi
    
    if [[ ! -f "\$NETWORKING_CONFIG" ]]; then
        echo "Error: networking.nix not found at \$NETWORKING_CONFIG"
        exit 1
    fi
    
    # Check if domain exists
    if ! grep -q "\"\$domain\"" "\$NETWORKING_CONFIG"; then
        echo "Domain \$domain not found in configuration"
        exit 0
    fi
    
    # Create backup
    sudo cp "\$NETWORKING_CONFIG" "\$NETWORKING_CONFIG.backup.\$(date +%Y%m%d-%H%M%S)"
    
    # Remove domain from configuration
    sudo sed -i "/\"\$domain\"/d" "\$NETWORKING_CONFIG"
    
    echo "✅ Removed \$domain from NixOS hosts configuration"
    echo "🔄 Run 'sudo nixos-rebuild switch' or '\$0 rebuild' to apply changes"
}

rebuild_config() {
    echo "🔄 Rebuilding NixOS configuration..."
    sudo nixos-rebuild switch
    if [ \$? -eq 0 ]; then
        echo "✅ NixOS rebuild successful!"
        echo "📍 Hosts file updated"
    else
        echo "❌ NixOS rebuild failed!"
        exit 1
    fi
}

case "\$1" in
    list)
        list_domains
        ;;
    add)
        add_domain "\$2"
        ;;
    remove)
        remove_domain "\$2"
        ;;
    rebuild)
        rebuild_config
        ;;
    show-current)
        find_current_hosts
        ;;
    *)
        show_help
        exit 1
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/manage-nixos-hosts

    success "Helper scripts created successfully with NixOS hosts management"
}

# Setup PHP error logging
setup_php_logging() {
    log "Setting up PHP 8.4 error logging..."
    
    sudo mkdir -p /var/log
    sudo touch /var/log/php_errors.log
    sudo chown nginx /var/log/php_errors.log
    sudo chgrp nginx /var/log/php_errors.log
    sudo chmod 644 /var/log/php_errors.log
    
    success "PHP error logging configured"
}

# Validate configuration syntax before proceeding
validate_configuration() {
    log "Validating NixOS configuration syntax..."
    
    if sudo nixos-rebuild dry-build >/dev/null 2>&1; then
        success "Configuration syntax is valid"
    else
        error "Configuration syntax validation failed. Please check the configuration manually."
    fi
}

# Main installation function
main() {
    echo -e "${CYAN}🚀 NixOS Web Server Installation Script (PHP 8.4)${NC}"
    echo -e "${CYAN}Modular Configuration with System State Version 25.05${NC}"
    echo -e "${CYAN}Handles NixOS hosts file management in /nix/store${NC}"
    echo "=================================================="
    echo
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Interactive configuration if requested
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        interactive_config
    fi
    
    # Validate configuration
    validate_config
    
    # Pre-flight checks
    check_root
    check_nixos
    check_nixos_channel
    
    # Show current hosts file location
    local current_hosts=$(find_nixos_hosts_file)
    log "Current NixOS hosts file: $current_hosts"
    
    # Show configuration summary
    echo -e "${CYAN}📋 Installation Configuration:${NC}"
    echo "  NixOS Config: $NIXOS_CONFIG_DIR"
    echo "  Backup Dir:   $BACKUP_DIR"
    echo "  Web Root:     $WEB_ROOT"
    echo "  System State: 25.05"
    echo
    
    # Backup and analysis
    backup_configuration
    analyze_existing_config
    
    # Create modular configuration structure
    create_service_modules
    update_main_configuration
    
    # Validate configuration before proceeding
    validate_configuration
    
    # Create nginx user/group before any file operations
    create_nginx_user_group
    
    # Setup web content and services
    setup_web_content
    setup_phpmyadmin
    setup_php_logging
    
    # Create helper scripts with NixOS hosts management
    create_helper_scripts
    
    echo
    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo
    echo -e "${CYAN}🎯 Next steps:${NC}"
    echo "1. Run: sudo nixos-rebuild switch"
    echo "2. Wait for the system to rebuild and restart services"
    echo "3. Access your sites:"
    echo "   • Dashboard: http://dashboard.local"
    echo "   • phpMyAdmin: http://phpmyadmin.local"
    echo "   • Sample 1: http://sample1.local"
    echo "   • Sample 2: http://sample2.local"
    echo "   • Sample 3: http://sample3.local"
    echo "   • Caching Scripts: http://caching-scripts.local"
    echo
    echo -e "${CYAN}🚀 PHP 8.4 Features Available:${NC}"
    echo "   • Property hooks for cleaner object-oriented code"
    echo "   • Asymmetric visibility modifiers"
    echo "   • Enhanced performance with JIT improvements"
    echo "   • New array functions and string manipulation"
    echo "   • Improved type system and error handling"
    echo
    echo -e "${CYAN}🏗️  System Architecture:${NC}"
    echo "   • Modular NixOS configuration with separate service modules"
    echo "   • System State Version: 25.05"
    echo "   • Service modules in: $NIXOS_CONFIG_DIR/modules/services/"
    echo "   • Automatic service monitoring and health checks"
    echo "   • Performance optimization and caching"
    echo
    echo -e "${CYAN}🔧 Helper commands:${NC}"
    echo "   • rebuild-webserver - Rebuild NixOS and restart services"
    echo "   • create-site-db <db_name> - Create new database"
    echo "   • create-site-dir <domain> <site_name> - Create new site"
    echo "   • manage-nixos-hosts <command> - Manage local domains in NixOS"
    echo
    echo -e "${CYAN}📍 NixOS Hosts Management:${NC}"
    echo "   • manage-nixos-hosts list - Show current domains"
    echo "   • manage-nixos-hosts add <domain> - Add domain"
    echo "   • manage-nixos-hosts remove <domain> - Remove domain"
    echo "   • manage-nixos-hosts rebuild - Apply changes"
    echo
    echo -e "${CYAN}📦 Configuration Details:${NC}"
    echo "   • Main config: $NIXOS_CONFIG_DIR/configuration.nix"
    echo "   • Service modules: $NIXOS_CONFIG_DIR/modules/services/"
    echo "   • Web root: $WEB_ROOT"
    echo "   • Backup location: $BACKUP_DIR"
    echo "   • System state: 25.05"
    echo
    echo -e "${CYAN}🔄 To restore: bash $BACKUP_DIR/restore.sh${NC}"
    echo
    echo -e "${YELLOW}⚠️  Important: Hosts file management is now handled via NixOS configuration${NC}"
    echo "   Local domains are managed through networking.hosts in modules/services/networking.nix"
    echo "   Changes require 'sudo nixos-rebuild switch' to take effect"
}

# Run main function
main "$@"
