# Module Imports in NixOS

## ✅ Yes, modules can import other modules!

NixOS modules can absolutely import other modules using the `imports` attribute. This is a fundamental feature that enables modular, organized, and reusable configurations.

## 🏗️ Module Import Structure

### Basic Import Syntax

```nix
# webserver.nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    ./modules/services/mysql.nix
  ];
  
  # Additional configuration here
}
```

### Advanced Import Patterns

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    # Relative paths
    ./modules/services/nginx.nix
    ./modules/config/php-optimization.nix
    
    # Absolute paths
    /etc/nixos/shared-modules/common.nix
    
    # Parent directory
    ../shared/web-common.nix
    
    # Conditional imports
    (lib.mkIf (config.services.nginx.enable) ./modules/nginx-extras.nix)
    (lib.mkIf (config.networking.hostName == "king") ./modules/king-specific.nix)
    
    # Dynamic imports based on conditions
    (lib.optional (builtins.pathExists ./local-overrides.nix) ./local-overrides.nix)
  ];
}
```

## 📁 Recommended Module Structure

### For Your Web Server Setup

```
webserver.nix                    # Main web server module
├── modules/
│   ├── services/
│   │   ├── nginx.nix           # Nginx service configuration
│   │   ├── php.nix             # PHP-FPM configuration
│   │   ├── mysql.nix           # MySQL/MariaDB configuration
│   │   └── monitoring.nix      # Optional monitoring
│   ├── config/
│   │   ├── nginx-vhosts.nix    # Virtual hosts definitions
│   │   ├── php-optimization.nix # PHP performance tuning
│   │   └── security.nix        # Security configurations
│   ├── features/
│   │   ├── ssl.nix             # SSL/TLS configuration
│   │   ├── caching.nix         # Caching setup
│   │   └── backup.nix          # Backup configurations
│   └── hosts/
│       ├── king-specific.nix   # Host-specific overrides
│       └── common.nix          # Common host settings
```

## 🔧 Benefits of Modular Imports

### 1. **Separation of Concerns**
```nix
# webserver.nix - Main orchestrator
{ config, pkgs, lib, ... }:
{
  imports = [
    ./modules/services/nginx.nix     # Just nginx config
    ./modules/services/php.nix       # Just PHP config
    ./modules/services/mysql.nix     # Just MySQL config
  ];
  
  # Only high-level coordination here
}
```

### 2. **Conflict Resolution**
```nix
# modules/services/mysql.nix
{ config, pkgs, lib, ... }:
{
  services.mysql = {
    enable = lib.mkDefault true;
    package = lib.mkDefault pkgs.mariadb;  # Can be overridden
  };
}
```

### 3. **Conditional Features**
```nix
# webserver.nix
{
  imports = [
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    
    # Only import MySQL if not already configured
    (lib.mkIf (!config.services.mysql.enable) ./modules/services/mysql.nix)
    
    # SSL only for production
    (lib.mkIf (config.networking.hostName != "dev") ./modules/features/ssl.nix)
  ];
}
```

### 4. **Reusability**
```nix
# Can be imported by multiple web server setups
# modules/config/php-optimization.nix
{ config, pkgs, lib, ... }:
{
  services.phpfpm.pools.www.phpPackage = pkgs.php.buildEnv {
    extraConfig = ''
      opcache.enable = 1
      opcache.memory_consumption = 128
      # ... optimization settings
    '';
  };
}
```

## 🎯 Practical Examples

### Example 1: Service-Specific Modules

```nix
# webserver.nix
{ config, pkgs, lib, ... }:
{
  imports = [
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    ./modules/services/mysql.nix
    ./modules/config/nginx-vhosts.nix
  ];
  
  # Only coordination and high-level settings
  environment.systemPackages = with pkgs; [ tree htop ];
}
```

### Example 2: Feature-Based Modules

```nix
# webserver.nix
{ config, pkgs, lib, ... }:
{
  imports = [
    # Core services
    ./modules/services/web-stack.nix
    
    # Features
    ./modules/features/ssl.nix
    ./modules/features/monitoring.nix
    ./modules/features/backup.nix
    
    # Host-specific
    (lib.mkIf (config.networking.hostName == "king") ./modules/hosts/king.nix)
  ];
}
```

### Example 3: Conflict-Aware Imports

```nix
# webserver.nix
{ config, pkgs, lib, ... }:
{
  imports = [
    # Always import these
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    
    # Only import MySQL if not already configured elsewhere
    (lib.mkIf (!config.services.mysql.enable) ./modules/services/mysql.nix)
    
    # Import host-specific overrides last
    ./modules/hosts/${config.networking.hostName}.nix
  ];
}
```

## 🔄 Module Merging Behavior

### Configuration Merging
```nix
# Module A
services.nginx.virtualHosts."site1.local" = { /* config */ };

# Module B  
services.nginx.virtualHosts."site2.local" = { /* config */ };

# Result: Both virtual hosts are merged
services.nginx.virtualHosts = {
  "site1.local" = { /* config from A */ };
  "site2.local" = { /* config from B */ };
};
```

### List Merging
```nix
# Module A
networking.firewall.allowedTCPPorts = [ 80 443 ];

# Module B
networking.firewall.allowedTCPPorts = lib.mkAfter [ 3306 ];

# Result: [ 80 443 3306 ]
```

## 🛡️ Best Practices

### 1. **Use lib.mkDefault for Overrideable Settings**
```nix
# In imported modules
services.mysql.package = lib.mkDefault pkgs.mariadb;
```

### 2. **Use lib.mkMerge for Complex Merging**
```nix
services.nginx.virtualHosts = lib.mkMerge [
  { "site1.local" = { /* config */ }; }
  { "site2.local" = { /* config */ }; }
];
```

### 3. **Use lib.mkAfter for Appending**
```nix
networking.firewall.allowedTCPPorts = lib.mkAfter [ 3306 ];
```

### 4. **Conditional Imports for Flexibility**
```nix
imports = [
  (lib.mkIf condition ./optional-module.nix)
];
```

## 🚀 Integration with Your Setup

For your flake-based setup with existing modules, you can:

### Option 1: Import into webserver.nix
```nix
# webserver.nix
{ config, pkgs, lib, ... }:
{
  imports = [
    ./modules/services/nginx.nix
    ./modules/services/php.nix
    ./modules/services/mysql.nix
    ./modules/config/nginx-vhosts.nix
  ];
}
```

### Option 2: Import webserver.nix into your main config
```nix
# In your main configuration or flake
{
  imports = [
    ./webserver.nix  # Which itself imports other modules
  ];
}
```

### Option 3: Parallel module structure
```nix
# In your flake.nix or main config
{
  imports = [
    ./modules/services/existing-servers.nix
    ./modules/services/webserver.nix  # New web server module
    ./modules/hosts/king.nix
  ];
}
```

## ✅ Summary

**Yes, modules can absolutely import other modules!** This enables:

- 🏗️ **Modular architecture** - Separate concerns into focused modules
- 🔄 **Reusability** - Share modules across different configurations  
- 🛡️ **Conflict resolution** - Use lib.mkDefault, lib.mkMerge for safe integration
- 🎯 **Conditional logic** - Import modules based on conditions
- 📁 **Organization** - Keep configurations clean and maintainable

This approach is perfect for your complex flake-based setup and will help avoid the MySQL package conflicts you encountered! 🚀