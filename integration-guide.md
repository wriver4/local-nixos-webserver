# NixOS Web Server Integration Guide (PHP 8.4)

## 📋 Configuration Structure Analysis

This guide helps integrate the PHP 8.4 web server into existing NixOS installations, whether using flakes or traditional configuration.

## 🔍 Detection Methods

### Flake-based Systems
If `/etc/nixos/flake.nix` exists:
- **Integration**: Add `./webserver.nix` to modules list
- **Rebuild**: `sudo nixos-rebuild switch --flake .`
- **Location**: Usually in `nixosConfigurations.<hostname>.modules`

### Traditional Systems  
If only `/etc/nixos/configuration.nix` exists:
- **Integration**: Add `./webserver.nix` to imports list
- **Rebuild**: `sudo nixos-rebuild switch`
- **Location**: In the `imports = [ ... ];` section

## 🛠️ Integration Steps

### For Flake Systems

1. **Add webserver module to flake.nix:**
```nix
nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
  modules = [
    ./configuration.nix
    ./webserver.nix  # Add this line
  ];
};
```

2. **Copy webserver module:**
```bash
sudo cp webserver.nix /etc/nixos/
```

3. **Rebuild:**
```bash
sudo nixos-rebuild switch --flake .
```

### For Traditional Systems

1. **Add to configuration.nix imports:**
```nix
imports = [
  ./hardware-configuration.nix
  ./webserver.nix  # Add this line
];
```

2. **Copy webserver module:**
```bash
sudo cp webserver.nix /etc/nixos/
```

3. **Rebuild:**
```bash
sudo nixos-rebuild switch
```

## 🔧 Automated Integration

### Using the Installation Script
```bash
chmod +x install-on-existing-nixos.sh
./install-on-existing-nixos.sh
```

The script automatically:
- ✅ Detects flake vs traditional setup
- ✅ Creates configuration backups
- ✅ Handles import integration
- ✅ Verifies PHP 8.4 availability
- ✅ Sets up helper scripts

### Manual Integration Checklist

- [ ] Backup existing configuration
- [ ] Check for conflicting web server configs
- [ ] Verify NixOS 25.05 channel for PHP 8.4
- [ ] Copy webserver.nix to /etc/nixos/
- [ ] Add import/module reference
- [ ] Test with dry-build first
- [ ] Rebuild and verify services

## 🚨 Conflict Resolution

### Existing Web Services
If you have existing nginx/apache/php configurations:

1. **Backup current config:**
```bash
sudo cp -r /etc/nixos /etc/nixos.backup.$(date +%Y%m%d)
```

2. **Merge configurations:**
   - Extract existing virtualHosts
   - Combine with new webserver module
   - Resolve port conflicts

3. **Test incrementally:**
```bash
sudo nixos-rebuild dry-build  # Test first
sudo nixos-rebuild switch     # Apply if successful
```

## 📦 PHP 8.4 Specific Considerations

### Channel Requirements
- **Required**: NixOS 25.05 or later
- **Check**: `nix-channel --list`
- **Upgrade**: `sudo nix-channel --add https://nixos.org/channels/nixos-25.05 nixos`

### PHP Extensions
The webserver module includes PHP 8.4 optimized extensions:
- mysqli, pdo_mysql (database)
- mbstring, intl (internationalization)  
- gd, exif (image processing)
- zip, fileinfo (file handling)
- openssl, curl (networking)

### Performance Optimizations
- OPcache enabled with 8.4 settings
- Memory limits optimized for 8.4
- FastCGI tuned for PHP 8.4 performance

## 🎯 Post-Integration Verification

### Service Status
```bash
sudo systemctl status nginx
sudo systemctl status phpfpm
sudo systemctl status mysql
```

### PHP Version Check
```bash
php --version  # Should show 8.4.x
```

### Web Access Test
- http://dashboard.local
- http://phpmyadmin.local  
- http://sample1.local

### Helper Commands
```bash
rebuild-webserver        # Rebuild and restart services
create-site-db mysite    # Create database
create-site-dir site.local "My Site"  # Create site directory
```

## 🔄 Rollback Procedure

If issues occur:

### Flake Systems
```bash
sudo nixos-rebuild switch --rollback --flake .
```

### Traditional Systems  
```bash
sudo nixos-rebuild switch --rollback
```

### Manual Restore
```bash
sudo cp -r /etc/nixos.backup.YYYYMMDD/* /etc/nixos/
sudo nixos-rebuild switch
```

## 📞 Troubleshooting

### Common Issues

**PHP 8.4 not available:**
- Upgrade to NixOS 25.05 channel
- Update channel: `sudo nix-channel --update`

**Port conflicts:**
- Check existing nginx configs
- Modify virtualHost ports if needed

**Permission errors:**
- Verify nginx user/group settings
- Check /var/www ownership

**Database connection issues:**
- Verify MySQL service status
- Check user credentials in config

### Debug Commands
```bash
sudo journalctl -u nginx -f      # Nginx logs
sudo journalctl -u phpfpm -f     # PHP-FPM logs  
sudo journalctl -u mysql -f      # MySQL logs
tail -f /var/log/php_errors.log  # PHP errors
```

## 🎉 Success Indicators

- ✅ All services running without errors
- ✅ PHP 8.4.x version displayed
- ✅ All local domains accessible
- ✅ phpMyAdmin login working
- ✅ Sample sites displaying content
- ✅ Dashboard virtual host management functional

## 📚 Additional Resources

- [NixOS Manual - Configuration](https://nixos.org/manual/nixos/stable/)
- [PHP 8.4 Release Notes](https://www.php.net/releases/8.4/en.php)
- [Nginx Configuration Guide](https://nginx.org/en/docs/)
- [NixOS Flakes Tutorial](https://nixos.wiki/wiki/Flakes)
