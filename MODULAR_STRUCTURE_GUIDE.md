# Modular NixOS Webserver Structure Guide

## 🏗️ Directory Structure

### Your Current Structure (Enhanced)
```
/etc/nixos/
├── webserver.nix                           # Main webserver module (imports others)
├── modules/
│   ├── hosts/
│   │   └── king.nix                        # Host-specific config (add networking.hosts here)
│   ├── services/
│   │   ├── nginx.nix                       # Enhanced nginx service
│   │   ├── php.nix                         # Enhanced PHP-FPM service  
│   │   ├── mysql.nix                       # Enhanced MySQL service (lib.mkDefault)
│   │   └── [other existing services]       # Your other services
│   ├── webserver/                          # Webserver-specific configuration
│   │   ├── nginx-vhosts.nix               # Virtual hosts definitions
│   │   └── php-optimization.nix           # PHP performance tuning
│   ├── software/                           # Your existing software modules
│   └── [other existing modules]            # Your other modules
```

## 📋 Module Responsibilities

### Main Module: `webserver.nix`
- **Purpose**: Orchestrates all webserver components
- **Imports**: Service modules + webserver config modules
- **Contains**: High-level coordination, system packages, activation scripts

```nix
{
  imports = [
    ./modules/webserver/nginx-vhosts.nix
    ./modules/webserver/php-optimization.nix
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    ./modules/services/mysql.nix
  ];
}
```

### Service Modules: `modules/services/`

#### `nginx.nix` - Enhanced Nginx Service
- **Purpose**: Core nginx service configuration
- **Features**: Performance optimization, security headers, conflict resolution
- **Uses**: `lib.mkDefault` for all settings to avoid conflicts

#### `php.nix` - Enhanced PHP-FPM Service  
- **Purpose**: PHP-FPM service with PHP 8.4 optimization
- **Features**: JIT compilation, process management, security settings
- **Uses**: `lib.mkDefault` for pool configuration

#### `mysql.nix` - Enhanced MySQL Service
- **Purpose**: MySQL/MariaDB service configuration
- **Features**: Performance tuning, webserver databases, conflict resolution
- **Uses**: `lib.mkDefault` extensively to avoid package conflicts

### Webserver Config: `modules/webserver/`

#### `nginx-vhosts.nix` - Virtual Hosts
- **Purpose**: Webserver-specific virtual host definitions
- **Contains**: dashboard.local, phpmyadmin.local, sample sites
- **Uses**: `lib.mkMerge` to combine with existing virtual hosts

#### `php-optimization.nix` - PHP Optimization
- **Purpose**: Webserver-specific PHP performance tuning
- **Features**: OPcache, JIT, memory optimization, security
- **Uses**: `lib.mkMerge` and `lib.mkAfter` for safe integration

## 🔧 Conflict Resolution Strategy

### MySQL Package Conflicts
**Problem**: Multiple modules defining `services.mysql.package`

**Solution**: 
```nix
# In modules/services/mysql.nix
services.mysql = {
  enable = lib.mkDefault true;
  package = lib.mkDefault pkgs.mariadb;  # Can be overridden
};
```

### Nginx Virtual Hosts
**Problem**: Multiple nginx configurations

**Solution**:
```nix
# In modules/webserver/nginx-vhosts.nix
services.nginx.virtualHosts = lib.mkMerge [
  {
    "dashboard.local" = { /* config */ };
    # ... other webserver hosts
  }
];
```

### PHP Configuration
**Problem**: Multiple PHP pool configurations

**Solution**:
```nix
# In modules/services/php.nix
services.phpfpm.pools.www = {
  user = lib.mkDefault "nginx";
  phpPackage = lib.mkDefault (pkgs.php.buildEnv { /* config */ });
};
```

## 🚀 Installation Process

### For Existing Installations
```bash
# Use the existing structure installer
./install-with-existing-structure.sh
```

**What it does:**
1. Analyzes your existing module structure
2. Backs up current configuration
3. Enhances existing service modules
4. Adds webserver-specific modules
5. Creates main webserver.nix orchestrator

### For New Installations
```bash
# Use the modular installer
./install-modular-webserver.sh
```

**What it does:**
1. Creates complete module structure
2. Installs all service and config modules
3. Sets up proper directory hierarchy

## 📁 Integration Steps

### 1. Import Main Module
Add to your main configuration or flake:
```nix
{
  imports = [
    ./webserver.nix
    # ... your other imports
  ];
}
```

### 2. Add Host Configuration
Edit `modules/hosts/king.nix`:
```nix
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

### 3. Rebuild System
```bash
sudo nixos-rebuild switch
```

## 🎯 Benefits of This Structure

### 1. **Separation of Concerns**
- Services handle core functionality
- Webserver modules handle application-specific config
- Host modules handle networking

### 2. **Conflict Resolution**
- Uses `lib.mkDefault` for overrideable settings
- Uses `lib.mkMerge` for combining configurations
- Uses `lib.mkAfter` for appending to lists

### 3. **Maintainability**
- Clear module boundaries
- Easy to modify individual components
- Preserves existing configurations

### 4. **Reusability**
- Service modules can be used by other applications
- Webserver modules are self-contained
- Easy to enable/disable features

## 🔍 Customization Examples

### Adding a New Virtual Host
Edit `modules/webserver/nginx-vhosts.nix`:
```nix
services.nginx.virtualHosts = lib.mkMerge [
  {
    # ... existing hosts
    "newsite.local" = {
      root = "/var/www/newsite";
      # ... configuration
    };
  }
];
```

### Modifying PHP Settings
Edit `modules/webserver/php-optimization.nix`:
```nix
services.phpfpm.pools.www.phpPackage = lib.mkDefault (pkgs.php.buildEnv {
  extraConfig = ''
    # Your custom PHP settings
    memory_limit = 512M
    # ... other settings
  '';
});
```

### Overriding MySQL Package
In your existing `modules/services/servers.nix`:
```nix
services.mysql.package = lib.mkForce pkgs.mariadb_1011;  # Override webserver default
```

## ✅ Summary

This modular structure provides:
- **🏗️ Clean Architecture**: Logical separation of services and configuration
- **🛡️ Conflict Resolution**: Safe integration with existing setups
- **🔧 Flexibility**: Easy customization and maintenance
- **��� Organization**: Follows your existing directory structure
- **🚀 Performance**: Optimized configurations for PHP 8.4 and modern web serving

The webserver functionality integrates seamlessly with your existing NixOS configuration while maintaining modularity and avoiding conflicts! 🎯