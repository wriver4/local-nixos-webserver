# NixOS Web Server with Virtual Host Management

A comprehensive NixOS configuration for hosting multiple PHP websites with nginx, PHP-FPM, MySQL/MariaDB, and **dynamic virtual host management** with **performance optimization** and **standalone caching scripts system**.

## 🌟 System Architecture

- **OS**: NixOS 25.05 with modular configuration structure
- **Web Server**: nginx with dynamic configuration and FastCGI caching
- **PHP**: PHP 8.4 with FPM, OPcache, JIT compilation, and performance optimizations
- **Database**: MariaDB with automatic database creation for new sites
- **Caching**: Multi-layer caching with OPcache, Redis, and nginx FastCGI cache
- **Management**: Enhanced PHP dashboard with virtual host management and standalone caching scripts

## 🏗️ Modular Configuration Structure

```
/etc/nixos/
├── configuration.nix           # Main entry point (System State 25.05)
├── hardware-configuration.nix  # Hardware-specific configuration
├── modules/
│   └── services/
│       ├── nginx.nix           # Nginx web server configuration
│       ├── php-fpm.nix         # PHP 8.4 with FPM and extensions
│       ├── mysql.nix           # MariaDB database server
│       ├── redis.nix           # Redis caching server
│       ├── networking.nix      # Firewall, hosts, network optimization
│       ├── users.nix           # Users, groups, and permissions
│       └── system.nix          # System scripts and optimization
└── webserver-backups/          # Configuration backups
```

## 🌐 Virtual Domains Structure

- `dashboard.local` - **Enhanced management dashboard with virtual host controls and cache monitoring**
- `phpmyadmin.local` - Database administration
- `sample1.local` - E-commerce demo site (NixOS-themed modern portfolio)
- `sample2.local` - Blog/news site  
- `sample3.local` - Portfolio/agency site
- `caching-scripts.local` - **Standalone caching scripts system**
- **Dynamic domains** - User-created virtual hosts via web interface

## 🚀 Installation Options

### Option 1: Fresh NixOS Installation
```bash
sudo cp configuration.nix /etc/nixos/configuration.nix
sudo cp -r modules /etc/nixos/
sudo nixos-rebuild switch
chmod +x enhanced-setup-script.sh
sudo ./enhanced-setup-script.sh
```

### Option 2: Existing NixOS Installation (Recommended)

#### Basic Installation
```bash
chmod +x install-on-existing-nixos.sh
./install-on-existing-nixos.sh
```

#### Interactive Installation
```bash
./install-on-existing-nixos.sh --interactive
```

#### Custom Directories
```bash
./install-on-existing-nixos.sh \
  --config-dir /etc/nixos \
  --backup-dir /etc/nixos/backups/$(date +%Y%m%d) \
  --web-root /srv/www
```

#### Command Line Options
```bash
./install-on-existing-nixos.sh [OPTIONS]

Options:
  -c, --config-dir DIR     NixOS configuration directory (default: /etc/nixos)
  -b, --backup-dir DIR     Backup directory (default: auto-generated)
  -w, --web-root DIR       Web root directory (default: /var/www)
  -i, --interactive        Interactive mode - prompt for all settings
  -h, --help              Show help message
```

## 🔧 Installation Process

The installation script performs the following steps:

1. **Safety Checks**: Verify NixOS system and sudo access
2. **Configuration Analysis**: Analyze existing config for conflicts
3. **Automatic Backup**: Create timestamped backup of current configuration
4. **Modular Integration**: Create service modules in `/etc/nixos/modules/services/`
5. **System Update**: Update to system state version 25.05
6. **User Creation**: Create nginx user and group before file operations
7. **Content Setup**: Create web directories and sample content
8. **phpMyAdmin**: Download and configure phpMyAdmin automatically
9. **Helper Scripts**: Install management utilities to `/usr/local/bin/`
10. **Validation**: Test configuration syntax before completion

## 🎛️ Virtual Host Management Features

### Dashboard Capabilities
- **➕ Add New Virtual Hosts**: Create new sites with custom domains
- **🗑️ Remove Virtual Hosts**: Delete sites (protected sites cannot be removed)
- **🔄 Toggle Site Status**: Enable/disable sites without removing them
- **🔧 Rebuild Configuration**: Update NixOS configuration with one click
- **📊 Real-time Statistics**: Monitor active sites and recent activity
- **📝 Activity Logging**: Track all changes with detailed logs
- **🌐 Hosts File Management**: Automatic .local domain management with backup/restore

### Automatic Features
- **Directory Creation**: Site directories automatically created in web root
- **Basic Index File**: Default `index.php` created for new sites with PHP 8.4 features
- **Database Setup**: Optional database created with proper permissions
- **Hosts File Update**: Local `/etc/hosts` entries managed via NixOS configuration
- **Permission Management**: Proper nginx ownership and permissions set
- **Backup System**: Automatic backups before destructive operations

## ⚡ Performance Optimization

### Multi-Layer Caching System
- **OPcache**: PHP bytecode caching with JIT compilation
- **Redis**: In-memory data structure store for application caching
- **FastCGI Cache**: Nginx-level caching for dynamic content
- **APCu**: User cache for application-level caching

### PHP 8.4 Optimizations
- **JIT Compilation**: Just-in-time compilation for performance
- **Memory Management**: Optimized memory usage and garbage collection
- **New Features**: Property hooks, asymmetric visibility modifiers
- **Performance Monitoring**: Built-in performance metrics and monitoring

## 🛠️ Standalone Caching Scripts System

### Project-Level Structure
```
/var/www/caching-scripts/
├── index.php              # Main admin panel with independent authentication
├── api/                   # API endpoints for programmatic access
│   ├── opcache.php        # OPcache management API
│   ├── redis.php          # Redis management API
│   └── system.php         # System scripts execution API
├── scripts/               # Shell scripts for system operations
│   ├── manage-opcache.sh  # OPcache command-line management
│   ├── manage-redis.sh    # Redis command-line management
│   ├── manage-hosts.sh    # Hosts file management
│   └── monitor-hosts.sh   # Hosts file monitoring
└── README.md              # Comprehensive documentation
```

### Independent Authentication System
- **Separate Sessions**: Uses `cache_admin_logged_in` session namespace
- **Security Isolation**: Completely independent from main dashboard authentication
- **Session Management**: 1-hour timeout with secure session handling
- **Activity Logging**: All admin actions logged to `/var/log/caching-scripts/activity.log`
- **Default Credentials**: `admin` / `admin123` (must be changed in production)

## 🔧 Helper Commands

### Service Management
```bash
# Rebuild NixOS configuration and restart services
rebuild-webserver

# Create new database for site
create-site-db <database_name>

# Create new site directory with PHP 8.4 template
create-site-dir <domain> <site_name>
```

### NixOS Hosts Management
```bash
# Show current local domains
manage-nixos-hosts list

# Add domain to NixOS configuration
manage-nixos-hosts add mysite.local

# Remove domain from NixOS configuration
manage-nixos-hosts remove oldsite.local

# Rebuild NixOS to apply changes
manage-nixos-hosts rebuild

# Show current active hosts file location
manage-nixos-hosts show-current
```

### System Aliases
```bash
# Service shortcuts
nginx-restart    # Restart nginx
php-restart      # Restart PHP-FPM
mysql-restart    # Restart MySQL
redis-restart    # Restart Redis

# Status checks
web-status       # Check all web services
web-performance  # Monitor web service processes
web-connections  # Show active connections

# Log viewing
web-logs         # Tail nginx access logs
error-logs       # Tail error logs
```

## 🗄️ Database Configuration

### Automatic Database Management
- **Auto-creation**: New databases created automatically when adding virtual hosts
- **User Permissions**: Proper permissions granted to `webuser`
- **Database Tracking**: Database names tracked in dashboard
- **phpMyAdmin Integration**: Full integration for database management
- **Backup System**: Automated daily backups with retention

### Default Database Users
- `webuser` / `webpass123` - Web application access
- `phpmyadmin` / `pmapass123` - phpMyAdmin full access
- `backup` / `backuppass123` - Read-only backup access
- `monitor` / `monitorpass123` - Performance monitoring

## 🛡️ Security & Protection

### Protected Sites
- `dashboard.local` and `phpmyadmin.local` are protected from removal
- Core system functionality preserved
- Visual indicators for protected sites

### Security Features
- **Input Validation**: All form inputs validated and sanitized
- **SQL Injection Protection**: Prepared statements used throughout
- **File System Security**: Proper permissions and ownership
- **Configuration Backups**: Automatic backups before configuration changes
- **Hosts File Safety**: Transaction-based hosts file modifications with rollback
- **Firewall Configuration**: Rate limiting and attack protection
- **Fail2ban Integration**: Automatic IP blocking for suspicious activity

## 📁 Directory Structure

```
/var/www/                   # Web root (configurable)
├── dashboard/              # Enhanced management dashboard
├── phpmyadmin/             # Database administration
├── sample1/                # E-commerce demo (NixOS-themed)
├── sample2/                # Blog demo
├── sample3/                # Portfolio demo
├── caching-scripts/        # Standalone caching scripts system
└── [custom-sites]/         # Dynamically created sites

/etc/nixos/
├── configuration.nix       # Main NixOS configuration (System State 25.05)
├── modules/services/       # Modular service configurations
├── webserver-backups/      # Configuration backups
└── templates/              # Virtual host templates

/usr/local/bin/
├── rebuild-webserver       # Helper script for rebuilds
├── create-site-db          # Database creation helper
├── create-site-dir         # Site directory helper
├── manage-nixos-hosts      # Hosts file management
└── [other-helpers]         # Additional management scripts

/var/log/
├── nginx/                  # Nginx logs
├── php-fpm/                # PHP-FPM logs
├── mysql/                  # MySQL logs
├── redis/                  # Redis logs
├── webserver/              # System monitoring logs
└── caching-scripts/        # Standalone scripts logging
```

## 🔄 Complete Workflow

### Adding New Sites
1. **Dashboard Interface**: Use web interface to add new virtual host
2. **Automatic Setup**: System creates directory, database, and configuration
3. **Hosts File Update**: .local domains automatically added to NixOS configuration
4. **Configuration Update**: Service modules automatically updated
5. **Manual Rebuild**: Run `sudo nixos-rebuild switch` to apply changes
6. **Site Ready**: New site immediately accessible at specified domain

### Cache Management Workflow
1. **Main Dashboard**: Monitor cache status and performance metrics
2. **Standalone Scripts**: Access independent cache management system
3. **Authentication**: Login with separate admin credentials
4. **Operations**: Perform cache operations via GUI or API
5. **Monitoring**: Track performance and activity through logging
6. **Integration**: View unified status across both systems

## 🐛 Troubleshooting

### Installation Issues
- **Permission errors**: Ensure sudo access and proper file permissions
- **Configuration conflicts**: Check backup directory for restore options
- **Network issues**: Verify internet connection for phpMyAdmin download
- **Channel compatibility**: Verify NixOS channel version compatibility

### Virtual Host Issues
- **Site not accessible**: Check if NixOS rebuild was completed
- **Database connection errors**: Verify database was created successfully
- **Permission errors**: Ensure proper nginx ownership of site directories
- **Hosts file issues**: Check hosts file permissions and backup availability

### Recovery Options
- **Configuration backups**: Located in `/etc/nixos/webserver-backups/`
- **Restore command**: `bash /etc/nixos/webserver-backups/[timestamp]/restore.sh`
- **Service restart**: `sudo systemctl restart nginx phpfpm-www mysql redis-main`
- **Full rebuild**: `sudo nixos-rebuild switch`

## 🚀 Production Considerations

### Security Hardening
- Change default database passwords
- Update standalone caching scripts admin password
- Implement proper SSL certificates
- Configure firewall rules appropriately
- Regular security updates

### Performance Optimization
- Configure PHP-FPM pools per site
- Implement advanced caching strategies
- Monitor resource usage and optimize
- Tune OPcache and Redis configurations
- Optimize database configurations

### Backup Strategy
- Regular configuration backups (automated)
- Database backup automation (daily)
- Site content backup procedures
- Disaster recovery planning
- Cache configuration backups

## 📊 System Monitoring

### Automated Monitoring
- **System Performance**: CPU, memory, disk usage every 5 minutes
- **Network Performance**: Traffic and error monitoring every 10 minutes
- **Service Health**: Service status checks every 10 minutes
- **Cache Performance**: OPcache and Redis metrics every 5 minutes
- **Database Performance**: MySQL performance tracking

### Log Management
- **Automatic Rotation**: All logs rotated daily with compression
- **Retention Policy**: 30 days for most logs, 14 days for high-volume logs
- **Centralized Logging**: All web server logs in `/var/log/webserver/`
- **Performance Logs**: Detailed performance metrics and alerts

## 🔧 Advanced Configuration

### Customizing Service Modules
Each service module can be customized independently:

```bash
# Edit specific service configurations
sudo nano /etc/nixos/modules/services/nginx.nix      # Nginx settings
sudo nano /etc/nixos/modules/services/php-fpm.nix    # PHP 8.4 settings
sudo nano /etc/nixos/modules/services/mysql.nix      # Database settings
sudo nano /etc/nixos/modules/services/redis.nix      # Redis settings
sudo nano /etc/nixos/modules/services/networking.nix # Network and firewall
sudo nano /etc/nixos/modules/services/users.nix      # Users and permissions
sudo nano /etc/nixos/modules/services/system.nix     # System optimization

# Apply changes
sudo nixos-rebuild switch
```

### Adding Custom Services
Create new service modules in `/etc/nixos/modules/services/` and import them in `configuration.nix`.

## 📝 System State Version

This configuration uses **NixOS System State Version 25.05**, which provides:
- PHP 8.4 support with latest features
- Enhanced security and performance optimizations
- Improved service management and monitoring
- Better resource utilization and caching
- Modern development tools and libraries

## 🤝 Contributing

This is a comprehensive NixOS web server configuration. Feel free to:
- Report issues or bugs
- Suggest improvements
- Submit pull requests
- Share your customizations

## 📄 License

This project is provided as-is for educational and development purposes. Use in production environments at your own risk after proper security review and hardening.

---

**Note**: This configuration is designed for development and testing environments. For production use, additional security hardening, SSL certificate configuration, and performance tuning may be required.
