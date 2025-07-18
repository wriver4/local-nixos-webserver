# NixOS Web Server with Virtual Host Management

A complete NixOS configuration for hosting multiple PHP websites with nginx, PHP-FPM, MySQL/MariaDB, and **dynamic virtual host management**.

## 🌟 Enhanced Features

- **Dynamic Virtual Host Management**: Add/remove virtual hosts via web interface
- **Automatic Configuration Updates**: NixOS configuration automatically updated
- **Database Management**: Automatic database creation for new sites
- **Activity Logging**: Track all virtual host changes and system events
- **Protected System Sites**: Core sites (dashboard, phpMyAdmin) cannot be removed
- **SSL Support**: Enable HTTPS for individual virtual hosts

## 🏗️ Architecture

### Core Domains
- `dashboard.local` - **Enhanced management dashboard with virtual host controls**
- `phpmyadmin.local` - Database administration
- `sample1.local` - E-commerce demo site
- `sample2.local` - Blog/news site  
- `sample3.local` - Portfolio/agency site

### Technology Stack
- **OS**: NixOS 23.11
- **Web Server**: nginx with dynamic configuration
- **PHP**: PHP 8.2 with FPM
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

For existing NixOS systems where you want to add web server functionality without disrupting current configuration:

```bash
# Make the installation script executable
chmod +x install-on-existing-nixos.sh

# Run the installation script
./install-on-existing-nixos.sh

# After successful completion, rebuild the system
sudo nixos-rebuild switch
```

#### What the Existing Installation Script Does:

1. **🔍 Safety Checks**: Verifies NixOS system and sudo access
2. **💾 Automatic Backup**: Creates timestamped backup of current configuration
3. **🔍 Conflict Detection**: Analyzes existing config for potential conflicts
4. **📦 Modular Integration**: Adds web server as separate module (`webserver.nix`)
5. **🔧 Helper Scripts**: Installs management utilities
6. **🌐 Content Setup**: Creates web directories and sample content
7. **📥 phpMyAdmin**: Downloads and configures phpMyAdmin automatically
8. **✅ Validation**: Tests configuration syntax before completion

#### Recovery Options:

If anything goes wrong, you can easily restore your original configuration:

```bash
# Navigate to backup directory (shown in script output)
cd /etc/nixos/webserver-backups/[timestamp]

# Run the restore script
sudo ./restore.sh

# Rebuild with original configuration
sudo nixos-rebuild switch
```

## 🎛️ Virtual Host Management Features

### Dashboard Capabilities
- **➕ Add New Virtual Hosts**: Create new sites with custom domains
- **🗑️ Remove Virtual Hosts**: Delete sites (protected sites cannot be removed)
- **🔄 Toggle Site Status**: Enable/disable sites without removing them
- **🔧 Rebuild Configuration**: Update NixOS configuration with one click
- **📊 Real-time Statistics**: Monitor active sites and recent activity
- **📝 Activity Logging**: Track all changes with detailed logs

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
- **Directory Creation**: Site directories automatically created in `/var/www/`
- **Basic Index File**: Default `index.php` created for new sites
- **Database Setup**: Optional database created with proper permissions
- **Hosts File Update**: Local `/etc/hosts` entries added automatically
- **Permission Management**: Proper nginx ownership and permissions set

## 🗄️ Enhanced Database Configuration

### Automatic Database Management
- New databases created automatically when adding virtual hosts
- Proper user permissions granted to `webuser`
- Database names tracked in dashboard
- Integration with phpMyAdmin for management

### Helper Commands
```bash
# Create database for existing site
sudo create-site-db mysite_db

# Create site directory structure
sudo create-site-dir mysite.local "My Site"

# Rebuild web server configuration
sudo rebuild-webserver
```

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

## 📊 Enhanced Dashboard Interface

### Statistics Dashboard
- **Total Sites**: Count of all configured virtual hosts
- **Active Sites**: Number of currently active sites
- **Recent Activity**: Latest system changes and actions

### Activity Logging
- **Site Creation/Removal**: Track virtual host lifecycle
- **Status Changes**: Monitor site enable/disable actions
- **Configuration Updates**: Log NixOS configuration rebuilds
- **Detailed Timestamps**: Precise tracking of all changes

### User Interface
- **Modern Design**: Clean, responsive interface
- **Modal Confirmations**: Safe removal with confirmation dialogs
- **Real-time Updates**: Immediate feedback on all actions
- **Quick Links**: Direct access to all configured sites

## 🔧 Advanced Configuration

### Custom Virtual Host Templates
Virtual hosts are generated using templates in `/etc/nixos/templates/`

### SSL Configuration
Enable SSL for any virtual host through the dashboard interface. SSL certificates can be managed through ACME/Let's Encrypt.

### Database Integration
Each virtual host can have its own dedicated database, automatically created and configured with proper permissions.

## 📁 Enhanced Directory Structure

```
/var/www/
├── dashboard/          # Enhanced management dashboard
├── phpmyadmin/         # Database administration
├── sample1/            # E-commerce demo
├── sample2/            # Blog demo
├── sample3/            # Portfolio demo
└── [custom-sites]/     # Dynamically created sites

/etc/nixos/
├── configuration.nix   # Main NixOS configuration
├── webserver.nix       # Web server module (existing installs)
├── backups/           # Configuration backups
└── templates/         # Virtual host templates

/usr/local/bin/
├── rebuild-webserver  # Helper script for rebuilds
├── create-site-db     # Database creation helper
└── create-site-dir    # Site directory helper
```

## 🔄 Workflow for Adding Sites

1. **Dashboard Interface**: Use web interface to add new virtual host
2. **Automatic Setup**: System creates directory, database, and configuration
3. **Configuration Update**: NixOS configuration automatically updated
4. **Manual Rebuild**: Run `sudo nixos-rebuild switch` to apply changes
5. **Site Ready**: New site immediately accessible at specified domain

## 🐛 Troubleshooting

### Installation Issues
- **Permission errors**: Ensure you have sudo access
- **Configuration conflicts**: Check backup directory for restore options
- **Network issues**: Verify internet connection for phpMyAdmin download

### Virtual Host Issues
- **Site not accessible**: Check if NixOS rebuild was completed
- **Database connection errors**: Verify database was created successfully
- **Permission errors**: Ensure proper nginx ownership of site directories

### Dashboard Issues
- **Cannot add sites**: Check database connectivity and permissions
- **Configuration not updating**: Verify write permissions to `/etc/nixos/`
- **Protected site removal**: Core sites cannot be removed by design

### Recovery
- **Configuration backups**: Located in `/etc/nixos/webserver-backups/`
- **Database backups**: Use phpMyAdmin or mysqldump
- **Site restoration**: Recreate through dashboard interface

## 🚀 Production Considerations

### Security Hardening
- Change default database passwords
- Implement proper SSL certificates
- Configure firewall rules appropriately
- Regular security updates

### Performance Optimization
- Configure PHP-FPM pools per site
- Implement caching strategies
- Monitor resource usage
- Optimize database configurations

### Backup Strategy
- Regular configuration backups
- Database backup automation
- Site content backup procedures
- Disaster recovery planning

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
- ✅ **Safe installation script for existing NixOS systems**
- ✅ **Automatic backup and recovery system**
- ✅ **Conflict detection and resolution**

## 🤝 Contributing

This enhanced configuration provides a solid foundation for dynamic web hosting on NixOS. Areas for further development:
- Automated SSL certificate management
- Multi-user access controls
- Advanced monitoring and alerting
- Backup automation
- Performance monitoring dashboard

## 📄 License

This configuration is provided as-is for educational and development purposes. Review and modify security settings before production use.
