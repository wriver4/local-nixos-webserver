# Still a work in progress not ready for primetime

# NixOS Web Server with Virtual Host Management

A complete NixOS configuration for hosting multiple PHP websites with nginx, PHP-FPM, MySQL/MariaDB, and **dynamic virtual host management** with **configurable installation paths**.

## 🌟 Enhanced Features

- **Dynamic Virtual Host Management**: Add/remove virtual hosts via web interface
- **Configurable Installation Paths**: Customize NixOS config, backup, and web root directories
- **Automatic Configuration Updates**: NixOS configuration automatically updated
- **Database Management**: Automatic database creation for new sites
- **Activity Logging**: Track all virtual host changes and system events
- **Protected System Sites**: Core sites (dashboard, phpMyAdmin) cannot be removed
- **SSL Support**: Enable HTTPS for individual virtual hosts
- **Interactive Installation**: Guided setup with path configuration options

## 🏗️ Architecture

### Core Domains
- `dashboard.local` - **Enhanced management dashboard with virtual host controls**
- `phpmyadmin.local` - Database administration
- `sample1.local` - E-commerce demo site
- `sample2.local` - Blog/news site  
- `sample3.local` - Portfolio/agency site

### Technology Stack
- **OS**: NixOS 23.11/25.05
- **Web Server**: nginx with dynamic configuration
- **PHP**: PHP 8.4 with FPM
- **Database**: MariaDB with automatic database creation
- **Management**: Enhanced PHP dashboard with virtual host management

## 🚀 Installation Options

### Option 1: Fresh NixOS Installation

For new NixOS systems or complete replacement of existing configuration:

```bash
# Copy the configuration
sudo cp configuration.nix /etc/nixos/configuration.nix

# Rebuild NixOS system
sudo nixos-rebuild switch

# Run the enhanced setup script
chmod +x enhanced-setup-script.sh
sudo ./enhanced-setup-script.sh
```

### Option 2: Existing NixOS Installation (Recommended)

For existing NixOS systems where you want to add web server functionality without disrupting current configuration. **Now with configurable paths!**

#### Basic Installation (Default Paths)
```bash
# Make the installation script executable
chmod +x install-on-existing-nixos.sh

# Run with default paths
./install-on-existing-nixos.sh

# After successful completion, rebuild the system
sudo nixos-rebuild switch
```

#### Advanced Installation with Custom Paths

**Command Line Options:**
- `--config-dir PATH` - NixOS configuration directory (default: `/etc/nixos`)
- `--backup-dir PATH` - Backup base directory (default: `/etc/nixos/webserver-backups`)
- `--webroot PATH` - Web root directory for sites (default: `/var/www`)
- `--interactive` - Interactive mode with guided path configuration
- `--dry-run` - Preview configuration without making changes
- `--help` - Show detailed usage information

**Usage Examples:**

```bash
# Custom configuration directory and web root
./install-on-existing-nixos.sh --config-dir /home/user/nixos-config --webroot /srv/www

# Custom backup location
./install-on-existing-nixos.sh --backup-dir /home/user/backups/nixos

# Interactive mode (recommended for first-time users)
./install-on-existing-nixos.sh --interactive

# Preview what would be done without making changes
./install-on-existing-nixos.sh --dry-run

# Combination of options
./install-on-existing-nixos.sh --config-dir /etc/nixos --webroot /opt/websites --interactive
```

#### Interactive Mode Features

When using `--interactive`, the script will:
1. **Show current defaults** for each path
2. **Prompt for custom paths** with option to keep defaults
3. **Validate paths** before proceeding
4. **Display configuration summary** before installation
5. **Create missing directories** with confirmation

#### Dry Run Mode

Use `--dry-run` to:
- **Preview all paths** that would be used
- **Validate configuration** without making changes
- **Check permissions** and directory accessibility
- **See what files** would be created/modified
- **Test path resolution** and absolute path conversion

#### What the Enhanced Installation Script Does:

1. **🔧 Path Configuration**: Accepts custom paths via command line or interactive mode
2. **🔍 Path Validation**: Validates all paths and converts to absolute paths
3. **💾 Smart Backup**: Creates timestamped backup with path information in restore script
4. **🔍 Conflict Detection**: Analyzes existing config for potential conflicts
5. **📦 Dynamic Integration**: Generates configuration files using specified paths
6. **🔧 Helper Scripts**: Creates management utilities with configured paths
7. **🌐 Content Setup**: Creates web directories at specified web root
8. **📥 phpMyAdmin**: Downloads and configures phpMyAdmin automatically
9. **✅ Configuration Test**: Validates NixOS configuration syntax before completion

#### Path Configuration Details

**NixOS Configuration Directory (`--config-dir`)**:
- Contains `configuration.nix` and generated `webserver.nix`
- Must be writable (sudo access required)
- Default: `/etc/nixos`
- Example: `/home/user/nixos-config`

**Backup Directory (`--backup-dir`)**:
- Base directory for configuration backups
- Timestamp automatically appended (e.g., `/path/20241201-143022`)
- Parent directory must be accessible
- Default: `/etc/nixos/webserver-backups`
- Example: `/home/user/backups/nixos-webserver`

**Web Root Directory (`--webroot`)**:
- Base directory for all website files
- Contains subdirectories for each virtual host
- Must be accessible by nginx user
- Default: `/var/www`
- Example: `/srv/websites` or `/opt/web`

#### Recovery Options:

If anything goes wrong, you can easily restore your original configuration:

```bash
# Navigate to backup directory (shown in script output)
cd /path/to/backup/directory/[timestamp]

# Run the restore script (includes original path information)
sudo ./restore.sh

# Rebuild with original configuration
sudo nixos-rebuild switch
```

The restore script automatically uses the original paths and includes helpful information about the backup.

## 🎛️ Virtual Host Management Features

### Dashboard Capabilities
- **➕ Add New Virtual Hosts**: Create new sites with custom domains
- **🗑️ Remove Virtual Hosts**: Delete sites (protected sites cannot be removed)
- **🔄 Toggle Site Status**: Enable/disable sites without removing them
- **🔧 Rebuild Configuration**: Update NixOS configuration with one click
- **📊 Real-time Statistics**: Monitor active sites and recent activity
- **📝 Activity Logging**: Track all changes with detailed logs
- **📁 Path Information**: Display configured web root and paths

### Adding a New Virtual Host
1. Access the dashboard at `http://dashboard.local`
2. Fill out the "Add New Virtual Host" form:
   - **Site Name**: Display name for the site
   - **Domain**: Domain name (e.g., `mysite.local`)
   - **Database Name**: Optional database for the site
   - **SSL Enabled**: Enable HTTPS support
3. Click "Add Virtual Host"
4. Click "Rebuild NixOS Configuration" to apply changes
5. Run `sudo nixos-rebuild switch` in terminal

### Automatic Features
- **Directory Creation**: Site directories automatically created in configured web root
- **Basic Index File**: Default `index.php` created for new sites with path information
- **Database Setup**: Optional database created with proper permissions
- **Hosts File Update**: Local `/etc/hosts` entries added automatically
- **Permission Management**: Proper nginx ownership and permissions set
- **Path Awareness**: All operations use configured paths

## 🗄️ Enhanced Database Configuration

### Automatic Database Management
- New databases created automatically when adding virtual hosts
- Proper user permissions granted to `webuser`
- Database names tracked in dashboard
- Integration with phpMyAdmin for management

### Helper Commands (Path-Aware)
```bash
# Create database for existing site
sudo create-site-db mysite_db

# Create site directory structure (uses configured web root)
sudo create-site-dir mysite.local "My Site"

# Rebuild web server configuration (uses configured config directory)
sudo rebuild-webserver
```

All helper commands automatically use the paths configured during installation.

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
- **Path Validation**: All paths validated and sanitized during installation

## 📊 Enhanced Dashboard Interface

### Statistics Dashboard
- **Total Sites**: Count of all configured virtual hosts
- **Active Sites**: Number of currently active sites
- **Recent Activity**: Latest system changes and actions
- **Path Information**: Display configured web root and backup locations

### Activity Logging
- **Site Creation/Removal**: Track virtual host lifecycle
- **Status Changes**: Monitor site enable/disable actions
- **Configuration Updates**: Log NixOS configuration rebuilds
- **Path Changes**: Track any path-related modifications
- **Detailed Timestamps**: Precise tracking of all changes

### User Interface
- **Modern Design**: Clean, responsive interface
- **Modal Confirmations**: Safe removal with confirmation dialogs
- **Real-time Updates**: Immediate feedback on all actions
- **Quick Links**: Direct access to all configured sites
- **Path Display**: Show current web root and configuration paths

## 🔧 Advanced Configuration

### Custom Virtual Host Templates
Virtual hosts are generated using templates that automatically use configured paths:
- Template location: `[config-dir]/templates/`
- Web root references: Dynamically inserted based on `--webroot` setting
- Helper scripts: Automatically configured with correct paths

### SSL Configuration
Enable SSL for any virtual host through the dashboard interface. SSL certificates can be managed through ACME/Let's Encrypt.

### Database Integration
Each virtual host can have its own dedicated database, automatically created and configured with proper permissions.

### Path Migration
If you need to change paths after installation:
1. Run the installation script with new paths
2. The script will detect existing configuration
3. Choose to migrate or create fresh installation
4. Backup and restore functionality preserved

## 📁 Enhanced Directory Structure

### Default Structure
```
/etc/nixos/                 # Default NixOS config directory
├── configuration.nix       # Main NixOS configuration
├── webserver.nix          # Web server module
├── webserver-backups/     # Configuration backups
│   └── [timestamp]/       # Timestamped backup directories
└── templates/             # Virtual host templates

/var/www/                  # Default web root
├── dashboard/             # Enhanced management dashboard
├── phpmyadmin/           # Database administration
├── sample1/              # E-commerce demo
├── sample2/              # Blog demo
├── sample3/              # Portfolio demo
└── [custom-sites]/       # Dynamically created sites

/usr/local/bin/           # Helper scripts (path-aware)
├── rebuild-webserver     # NixOS rebuild script
├── create-site-db        # Database creation helper
└── create-site-dir       # Site directory helper
```

### Custom Path Structure Example
```bash
# Installation with custom paths:
./install-on-existing-nixos.sh \
  --config-dir /home/user/nixos-config \
  --backup-dir /home/user/backups \
  --webroot /srv/websites
```

Results in:
```
/home/user/nixos-config/    # Custom NixOS config directory
├── configuration.nix       # Main NixOS configuration
├── webserver.nix          # Web server module
└── templates/             # Virtual host templates

/home/user/backups/        # Custom backup directory
└── [timestamp]/           # Timestamped backup directories

/srv/websites/             # Custom web root
├── dashboard/             # Management dashboard
├── phpmyadmin/           # Database administration
└── [sites]/              # Website directories
```

## 🔄 Workflow for Adding Sites

1. **Dashboard Interface**: Use web interface to add new virtual host
2. **Automatic Setup**: System creates directory in configured web root, database, and configuration
3. **Configuration Update**: NixOS configuration automatically updated in configured directory
4. **Manual Rebuild**: Run `sudo nixos-rebuild switch` to apply changes
5. **Site Ready**: New site immediately accessible at specified domain

## 🐛 Troubleshooting

### Installation Issues
- **Permission errors**: Ensure you have sudo access and paths are writable
- **Path validation errors**: Check that parent directories exist and are accessible
- **Configuration conflicts**: Check backup directory for restore options
- **Network issues**: Verify internet connection for phpMyAdmin download

### Path-Related Issues
- **Invalid paths**: Use absolute paths or ensure relative paths resolve correctly
- **Permission denied**: Ensure parent directories exist and are writable
- **Path not found**: Verify directories exist before running installation
- **Backup restoration**: Use the restore script in the backup directory

### Virtual Host Issues
- **Site not accessible**: Check if NixOS rebuild was completed
- **Database connection errors**: Verify database was created successfully
- **Permission errors**: Ensure proper nginx ownership of site directories in web root
- **Path mismatches**: Verify web root configuration matches dashboard settings

### Dashboard Issues
- **Cannot add sites**: Check database connectivity and permissions
- **Configuration not updating**: Verify write permissions to configured NixOS directory
- **Protected site removal**: Core sites cannot be removed by design
- **Path display errors**: Check if configured paths are still accessible

### Recovery and Migration
- **Configuration backups**: Located in configured backup directory
- **Database backups**: Use phpMyAdmin or mysqldump
- **Site restoration**: Recreate through dashboard interface
- **Path migration**: Re-run installation script with new paths

## 🚀 Production Considerations

### Security Hardening
- Change default database passwords
- Implement proper SSL certificates
- Configure firewall rules appropriately
- Regular security updates
- Validate custom paths for security implications

### Performance Optimization
- Configure PHP-FPM pools per site
- Implement caching strategies
- Monitor resource usage
- Optimize database configurations
- Consider web root location for performance

### Backup Strategy
- Regular configuration backups (automated with timestamps)
- Database backup automation
- Site content backup procedures
- Disaster recovery planning
- Path-aware backup scripts

### Path Management
- Document custom paths used in installation
- Ensure backup scripts include path information
- Plan for path migrations if needed
- Monitor disk space in custom directories

## 📝 Changelog

### Enhanced Features Added
- ✅ Dynamic virtual host add/remove functionality
- ✅ Automatic NixOS configuration updates
- ✅ Database creation and management
- ✅ Enhanced activity logging
- ✅ Protected site system
- ✅ SSL support configuration
- ✅ Helper command utilities
- ✅ Improved user interface
- ✅ Safe installation script for existing NixOS systems
- ✅ Automatic backup and recovery system
- ✅ Conflict detection and resolution
- ✅ **NEW: Dynamic path configuration with command-line options**
- ✅ **NEW: Interactive installation mode with guided setup**
- ✅ **NEW: Dry-run mode for installation preview**
- ✅ **NEW: Path validation and absolute path conversion**
- ✅ **NEW: Enhanced backup system with path information**
- ✅ **NEW: Path-aware helper scripts and configuration**

### Recent Updates (Dynamic Path Configuration)
- **Command-line options**: `--config-dir`, `--backup-dir`, `--webroot`, `--interactive`, `--dry-run`, `--help`
- **Path validation**: Automatic validation and absolute path conversion
- **Interactive mode**: Guided setup with current defaults displayed
- **Dry-run functionality**: Preview installation without making changes
- **Enhanced backups**: Restore scripts include original path information
- **Path-aware scripts**: All helper scripts use configured paths
- **Comprehensive logging**: Clear indication of paths being used
- **Backward compatibility**: Default behavior unchanged when no options provided

## 🤝 Contributing

This enhanced configuration provides a solid foundation for dynamic web hosting on NixOS with flexible path configuration. Areas for further development:
- Automated SSL certificate management
- Multi-user access controls with path restrictions
- Advanced monitoring and alerting
- Backup automation with path awareness
- Performance monitoring dashboard
- Path migration utilities
- Configuration templates for different setups

## 📄 License

This configuration is provided as-is for educational and development purposes. Review and modify security settings and path configurations before production use.

---

## 🔍 Quick Reference

### Installation Commands
```bash
# Default installation
./install-on-existing-nixos.sh

# Custom paths
./install-on-existing-nixos.sh --config-dir /custom/nixos --webroot /custom/www

# Interactive setup
./install-on-existing-nixos.sh --interactive

# Preview installation
./install-on-existing-nixos.sh --dry-run

# Get help
./install-on-existing-nixos.sh --help
```

### Helper Commands (Path-Aware)
```bash
# Rebuild system (uses configured paths)
rebuild-webserver

# Create database
create-site-db mysite_db

# Create site directory (uses configured web root)
create-site-dir mysite.local "My Site"
```

### Access URLs
- Dashboard: http://dashboard.local
- phpMyAdmin: http://phpmyadmin.local
- Sample sites: http://sample1.local, http://sample2.local, http://sample3.local

### Default Paths
- **NixOS Config**: `/etc/nixos`
- **Backup Directory**: `/etc/nixos/webserver-backups`
- **Web Root**: `/var/www`
- **Helper Scripts**: `/usr/local/bin`
