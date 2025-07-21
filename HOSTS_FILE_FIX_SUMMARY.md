# /etc/hosts File Configuration Fix

## 🔧 Issue Fixed

The scripts were incorrectly modifying `/etc/hosts` directly, which is not the NixOS way. In NixOS, the `/etc/hosts` file should be managed through the configuration system using `networking.extraHosts`.

## ✅ Changes Made

### 1. Configuration.nix Already Correct
The main `configuration.nix` already had the correct configuration:
```nix
networking.extraHosts = ''
  127.0.0.1 dashboard.local
  127.0.0.1 phpmyadmin.local
  127.0.0.1 sample1.local
  127.0.0.1 sample2.local
  127.0.0.1 sample3.local
'';
```

### 2. Updated Scripts

#### enhanced-setup-script.sh
**Before:**
```bash
# Add hosts entries for local development
sudo tee -a /etc/hosts << 'EOF'
127.0.0.1 dashboard.local
127.0.0.1 phpmyadmin.local
# ... etc
EOF
```

**After:**
```bash
# Note: /etc/hosts is managed by NixOS configuration (networking.extraHosts)
log "Local domain configuration..."
success "Local domains are configured in NixOS configuration.nix (networking.extraHosts)"
log "Domains available after nixos-rebuild switch:"
log "  • dashboard.local"
log "  • phpmyadmin.local"
# ... etc
```

#### install-on-existing-nixos.sh
**Before:**
```bash
update_hosts_file() {
    # Direct /etc/hosts modification
    sudo tee -a /etc/hosts << 'EOF'
    # ... hosts entries
    EOF
}
```

**After:**
```bash
update_hosts_configuration() {
    # Add networking.extraHosts to NixOS configuration
    # Properly integrates with existing configuration
    # Updates configuration.nix instead of /etc/hosts
}
```

#### setup-script.sh
**Before:**
```bash
# Add hosts entries for local development
sudo tee -a /etc/hosts << 'EOF'
# ... hosts entries
EOF
```

**After:**
```bash
# Note: /etc/hosts is managed by NixOS configuration (networking.extraHosts)
success "Local domains are configured in NixOS configuration.nix (networking.extraHosts)"
```

### 3. Updated Dashboard (web-content/dashboard/index.php)

#### Virtual Host Management
**Before:**
- Dashboard directly modified `/etc/hosts` when adding/removing sites
- Used `file_put_contents('/etc/hosts', ...)` 

**After:**
- Dashboard updates `networking.extraHosts` in NixOS configuration
- Generates proper NixOS configuration syntax
- Updates both `virtualHosts` and `networking.extraHosts` sections

#### Key Changes:
```php
// NEW: Generate networking.extraHosts section
$extra_hosts = "  networking.extraHosts = ''\n";
foreach ($sites as $site) {
    if ($site['status'] === 'active') {
        $extra_hosts .= "    127.0.0.1 {$site['domain']}\n";
    }
}
$extra_hosts .= "  '';";

// NEW: Replace networking.extraHosts section in configuration
$hosts_pattern = '/networking\.extraHosts\s*=\s*\'\'.*?\'\';/s';
$new_config = preg_replace($hosts_pattern, $extra_hosts, $new_config);
```

## 🎯 Benefits

### 1. NixOS Compliance
- Follows NixOS declarative configuration principles
- `/etc/hosts` is properly managed by the system
- Configuration is reproducible and version-controlled

### 2. System Integrity
- No direct file system modifications
- Changes are atomic through `nixos-rebuild switch`
- Rollback capability through NixOS generations

### 3. Consistency
- All configuration in one place
- No conflicts between manual edits and system management
- Proper integration with NixOS rebuild process

## 📋 Usage Instructions

### For Users
1. **Adding Sites**: Use the dashboard to add new virtual hosts
2. **Rebuilding**: Click "Rebuild NixOS Configuration" in dashboard
3. **Applying**: Run `sudo nixos-rebuild switch` to apply changes
4. **Result**: Both nginx virtual hosts and `/etc/hosts` are updated automatically

### For Developers
1. **Configuration**: All hosts are defined in `networking.extraHosts`
2. **Dynamic Updates**: Dashboard manages both nginx and hosts configuration
3. **Backup**: Automatic backup before configuration changes
4. **Recovery**: Use NixOS rollback if needed

## 🔍 Verification

### Check Current Configuration
```bash
# View current networking.extraHosts
grep -A 10 "networking.extraHosts" /etc/nixos/configuration.nix

# View current /etc/hosts (managed by NixOS)
cat /etc/hosts
```

### Test Changes
```bash
# After making changes in dashboard:
sudo nixos-rebuild switch

# Verify hosts are updated:
ping dashboard.local
ping phpmyadmin.local
```

## 🚨 Important Notes

1. **No Manual Editing**: Never manually edit `/etc/hosts` on NixOS
2. **Use Dashboard**: Use the web dashboard for virtual host management
3. **Rebuild Required**: Always run `nixos-rebuild switch` after configuration changes
4. **Backup Available**: Configuration backups are created automatically

## 🎉 Result

The system now properly manages `/etc/hosts` through NixOS configuration, ensuring:
- ✅ Declarative configuration management
- ✅ System integrity and reproducibility  
- ✅ Proper integration with NixOS rebuild process
- ✅ Dynamic virtual host management through web interface
- ✅ Automatic backup and recovery capabilities

All scripts and the dashboard now work correctly with NixOS configuration management principles.