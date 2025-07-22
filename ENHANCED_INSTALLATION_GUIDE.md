# Enhanced Installation Guide with Configuration Tree Analysis

## 🛡️ Safe Installation Process

The enhanced installation process now includes comprehensive configuration tree analysis to prevent conflicts and ensure safe integration with existing NixOS setups.

## 📋 What's New

### 🔍 Comprehensive Analysis
- **Flake Detection**: Automatically detects flake-based vs traditional configurations
- **Module Discovery**: Finds and analyzes all modules in your configuration tree
- **Host Configuration Analysis**: Examines host-specific configurations
- **Service Conflict Detection**: Identifies conflicting service definitions
- **Networking Analysis**: Checks for networking configuration conflicts

### 🛠️ Conflict Resolution
- **lib.mkDefault**: Uses mkDefault for services that might conflict
- **lib.mkMerge**: Merges configurations safely where possible
- **lib.mkAfter**: Appends to existing lists (like firewall ports)
- **Conditional Logic**: Adapts configuration based on detected conflicts

## 🚀 Installation Options

### Option 1: Enhanced Safe Installation (Recommended)

```bash
# Run comprehensive analysis and safe installation
./safe-install-with-analysis.sh
```

**What it does:**
1. Analyzes entire configuration tree (flake.nix, modules/, hosts/, etc.)
2. Detects service conflicts (MySQL, Nginx, PHP-FPM)
3. Generates conflict-aware configuration using lib.mkDefault
4. Creates comprehensive backup with analysis report
5. Tests configuration syntax before completion

### Option 2: Analysis Only

```bash
# Run analysis without making changes
./enhanced-install-analyzer.sh
```

**Use this to:**
- Understand your current configuration structure
- Identify potential conflicts before installation
- Generate detailed analysis report

### Option 3: Traditional Installation

```bash
# Original installation method (not recommended for complex setups)
./install-on-existing-nixos.sh
```

## 📊 Analysis Report

The analysis generates a comprehensive report including:

### Configuration Structure
```
CONFIG_TYPE=flake
FLAKE_FILE=/etc/nixos/flake.nix
MAIN_CONFIG=/etc/nixos/configuration.nix

MODULES DIRECTORY: /etc/nixos/modules
================================
MODULE: services/webserver.nix
MODULE: services/servers.nix
MODULE: hosts/king.nix
```

### Service Analysis
```
SERVICES ANALYSIS: module:webserver
===========================
SERVICE_ENABLED: mysql in module:webserver at line 15
SERVICE_PACKAGE: mysql in module:webserver -> pkgs.mariadb

SERVICES ANALYSIS: module:servers
==========================
SERVICE_ENABLED: mysql in module:servers at line 23
SERVICE_PACKAGE: mysql in module:servers -> pkgs.mariadb
```

### Conflict Detection
```
CONFLICT ANALYSIS:
==================
CONFLICT: MySQL defined 2 times
RECOMMENDATION: Use lib.mkDefault for service packages to allow overrides
```

## 🔧 Conflict Resolution Strategies

### MySQL/MariaDB Conflicts

**Problem**: Multiple modules defining `services.mysql.package`

**Solution**: Use `lib.mkDefault` in the web server module:
```nix
services.mysql = {
  enable = lib.mkDefault true;
  package = lib.mkDefault pkgs.mariadb;  # Can be overridden
  # ... other settings
};
```

### Nginx Virtual Hosts Conflicts

**Problem**: Multiple nginx configurations

**Solution**: Use `lib.mkMerge` for virtual hosts:
```nix
services.nginx.virtualHosts = lib.mkMerge [
  # Existing virtual hosts will be preserved
  {
    "dashboard.local" = { /* config */ };
    "phpmyadmin.local" = { /* config */ };
  }
];
```

### Firewall Port Conflicts

**Problem**: Multiple firewall configurations

**Solution**: Use `lib.mkAfter` to append ports:
```nix
networking.firewall.allowedTCPPorts = lib.mkAfter [ 80 443 3306 ];
```

## 📁 Generated Files

### Safe Installation
- `webserver-safe.nix` - Conflict-aware web server module
- Analysis report with conflict detection
- Comprehensive backup with restore script

### File Structure
```
/etc/nixos/
├── flake.nix                    # Your existing flake
├── configuration.nix            # Your main config
├── webserver-safe.nix          # Generated safe module
├── modules/
│   ├── services/
│   │   ├── webserver.nix       # Existing (may conflict)
│   │   └── servers.nix         # Existing (may conflict)
│   └── hosts/
│       └── king.nix            # Host-specific config
└── webserver-backups/
    └── 20240721-123456/
        ├── analysis-report.txt
        ├── restore.sh
        └── [backup files]
```

## 🎯 Integration Steps

### For Flake-Based Setups

1. **Add the safe module to your flake inputs** (if using flakes):
```nix
# In your flake.nix
nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
  modules = [
    ./configuration.nix
    ./webserver-safe.nix  # Add this line
    # ... other modules
  ];
};
```

2. **Or import in configuration.nix**:
```nix
{
  imports = [
    ./hardware-configuration.nix
    ./webserver-safe.nix  # Add this line
    # ... other imports
  ];
}
```

3. **Add networking.hosts to your host configuration**:
```nix
# In modules/hosts/king.nix
{
  networking.hosts = {
    "127.0.0.1" = [ 
      "localhost" 
      "dashboard.local" 
      "phpmyadmin.local" 
      "sample1.local" 
      "sample2.local" 
      "sample3.local" 
    ];
    "127.0.0.2" = [ "king" ];
  };
}
```

## 🔍 Verification

### Check for Conflicts
```bash
# Test configuration syntax
sudo nixos-rebuild dry-build

# Check for service conflicts
systemctl list-units | grep -E "(mysql|nginx|phpfpm)"

# Verify networking
ping dashboard.local
```

### Review Analysis
```bash
# View the analysis report
less /tmp/nixos-analysis-*.txt

# Check generated module
cat /etc/nixos/webserver-safe.nix
```

## 🚨 Troubleshooting

### Common Issues

**"services.mysql.package is defined multiple times"**
- The safe installer uses `lib.mkDefault` to prevent this
- If still occurring, check for `lib.mkForce` in other modules

**"networking.hosts conflicts"**
- Move networking.hosts to host-specific configuration
- Use the provided king-hosts-config.nix as reference

**"Configuration syntax error"**
- Review the analysis report for specific issues
- Use the backup restore script if needed

### Recovery

**Restore from backup:**
```bash
cd /etc/nixos/webserver-backups/[timestamp]
sudo ./restore.sh
sudo nixos-rebuild switch
```

## 🎉 Benefits

### Safety
- ✅ No destructive changes to existing configuration
- ✅ Comprehensive backup with restore capability
- ✅ Conflict detection before installation
- ✅ Syntax validation before applying

### Compatibility
- ✅ Works with flake-based setups
- ✅ Preserves existing service configurations
- ✅ Merges safely with existing nginx configs
- ✅ Respects existing networking setup

### Maintainability
- ✅ Clear separation of concerns
- ✅ Detailed analysis reports for future reference
- ✅ Modular configuration structure
- ✅ Easy to remove or modify

The enhanced installation process ensures your web server integration is safe, conflict-free, and maintainable! 🚀