# Standalone Caching Scripts

This folder contains standalone caching management scripts for the NixOS web server environment. These scripts provide comprehensive cache management capabilities through both web interface and command-line tools.

## 📁 Structure

```
caching-scripts/
├── index.php              # Main admin panel with authentication
├── api/                   # API endpoints for programmatic access
│   ├── opcache.php        # OPcache management API
│   ├── redis.php          # Redis management API
│   └── system.php         # System scripts execution API
├── scripts/               # Shell scripts for system operations
│   ├── manage-opcache.sh  # OPcache command-line management
│   ├── manage-redis.sh    # Redis command-line management
│   ├── manage-hosts.sh    # Hosts file management
│   └── monitor-hosts.sh   # Hosts file monitoring
└── README.md              # This documentation
```

## 🔐 Authentication

The system uses session-based authentication with the following features:

- **Default Credentials**: `admin` / `admin123` (should be changed!)
- **Session Timeout**: 1 hour automatic logout
- **Activity Logging**: All admin actions are logged
- **Secure Sessions**: Separate session namespace for cache admin

## ⚡ OPcache Management

### Web Interface Features:
- Real-time status monitoring with hit rates
- Cache reset functionality
- File invalidation capabilities
- Memory usage tracking
- Cached scripts overview

### API Endpoints:
- `GET/POST api/opcache.php?action=status` - Get OPcache status
- `POST api/opcache.php?action=reset` - Reset OPcache
- `POST api/opcache.php?action=invalidate&file=path` - Invalidate specific file

### Command Line:
```bash
# Show OPcache status
./scripts/manage-opcache.sh status

# Reset OPcache
./scripts/manage-opcache.sh reset

# Invalidate specific file
./scripts/manage-opcache.sh invalidate /var/www/site/file.php
```

## 🔴 Redis Management

### Web Interface Features:
- Connection status monitoring
- Database management (flush all/specific)
- Key operations (add, delete, modify)
- Performance metrics tracking
- Multi-database support (0-15)

### API Endpoints:
- `GET/POST api/redis.php?action=status` - Get Redis status
- `POST api/redis.php?action=flushall` - Flush all databases
- `POST api/redis.php?action=flushdb&database=0` - Flush specific database
- `POST api/redis.php?action=get_keys&database=0` - List keys

### Command Line:
```bash
# Show Redis status
./scripts/manage-redis.sh status

# Flush all databases
./scripts/manage-redis.sh flushall

# Flush specific database
./scripts/manage-redis.sh flushdb 1
```

## 🌐 Hosts File Management

### Web Interface Features:
- Add/remove .local domains
- Automatic backup creation
- Domain listing and monitoring
- Backup/restore functionality

### API Endpoints:
- `POST api/system.php?action=execute&script=manage-hosts` - Execute hosts commands

### Command Line:
```bash
# Add domain to hosts file
./scripts/manage-hosts.sh add mysite.local

# Remove domain from hosts file
./scripts/manage-hosts.sh remove mysite.local

# List all .local domains
./scripts/manage-hosts.sh list

# Create backup
./scripts/manage-hosts.sh backup
```

## 🛡️ Security Features

### Access Control:
- Admin authentication required for all operations
- Session-based security with timeout
- Script execution validation and sanitization
- Whitelisted commands only

### Activity Logging:
- All admin actions logged with timestamps
- Command execution history
- User attribution for all operations
- Log file: `/var/log/caching-scripts/activity.log`

### Safety Controls:
- Automatic backups before destructive operations
- Confirmation dialogs for dangerous actions
- Error handling and user feedback
- Resource protection mechanisms

## 🚀 Installation & Setup

### 1. Copy Scripts to System
```bash
# Copy shell scripts to system bin
sudo cp scripts/*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/manage-*.sh
sudo chmod +x /usr/local/bin/monitor-*.sh
```

### 2. Create Log Directory
```bash
sudo mkdir -p /var/log/caching-scripts
sudo chown nginx:nginx /var/log/caching-scripts
sudo chmod 755 /var/log/caching-scripts
```

### 3. Set Up Web Access
The web interface should be accessible through your web server configuration. Ensure PHP has the necessary permissions to execute system commands and write to log files.

### 4. Configure Authentication
Edit `index.php` to change the default admin password:
```php
$admin_config = [
    'username' => 'admin',
    'password' => password_hash('your_secure_password', PASSWORD_DEFAULT),
    'session_timeout' => 3600
];
```

## 📊 Usage Examples

### Web Interface Access:
1. Navigate to the caching scripts directory in your browser
2. Login with admin credentials
3. Use the GUI to manage caches and system operations

### API Usage:
```bash
# Get OPcache status via API
curl -X POST "http://your-server/caching-scripts/api/opcache.php" \
     -d "action=status" \
     -H "Content-Type: application/x-www-form-urlencoded"

# Reset OPcache via API
curl -X POST "http://your-server/caching-scripts/api/opcache.php" \
     -d "action=reset" \
     -H "Content-Type: application/x-www-form-urlencoded"
```

### Command Line Usage:
```bash
# Check all cache statuses
./scripts/manage-opcache.sh status
./scripts/manage-redis.sh status

# Perform maintenance
./scripts/manage-opcache.sh reset
./scripts/manage-redis.sh flushall

# Manage hosts file
./scripts/manage-hosts.sh list
./scripts/monitor-hosts.sh
```

## 🔧 Integration with Main Dashboard

The standalone caching scripts can be integrated with the main dashboard through:

1. **Direct Links**: Add links to the caching scripts admin panel
2. **API Integration**: Use the APIs to display cache status on main dashboard
3. **Embedded Widgets**: Include cache status widgets in dashboard cards
4. **Unified Authentication**: Share authentication state between systems

## 📝 Logging & Monitoring

### Activity Logs:
- Location: `/var/log/caching-scripts/activity.log`
- Format: `[timestamp] - Admin: username - Action: command`
- Rotation: Manual or via logrotate configuration

### Hosts File Changes:
- Location: `/var/log/caching-scripts/hosts-changes.log`
- Automatic tracking of .local domain modifications
- Backup creation timestamps

### Performance Monitoring:
- Real-time cache hit rates
- Memory usage tracking
- Connection status monitoring
- Database size tracking

## ⚠️ Important Notes

1. **Change Default Password**: Always change the default admin password before deployment
2. **File Permissions**: Ensure proper permissions for log files and script execution
3. **System Access**: These scripts have system-level access - use with caution
4. **Backup Strategy**: Regular backups are created automatically, but verify backup integrity
5. **Security Updates**: Keep the system updated and monitor for security issues

## 🔄 Maintenance

### Regular Tasks:
- Monitor log file sizes and rotate as needed
- Review activity logs for unusual patterns
- Test backup and restore procedures
- Update authentication credentials periodically
- Verify script permissions and functionality

### Troubleshooting:
- Check log files for error messages
- Verify file permissions and ownership
- Test individual scripts from command line
- Ensure web server has necessary PHP extensions
- Validate Redis and OPcache configurations
