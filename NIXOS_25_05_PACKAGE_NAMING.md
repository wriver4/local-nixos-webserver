# NixOS 25.05 Package Naming Updates

## 📋 **Package Naming Changes**

In NixOS 25.05, the PHP package naming convention has been updated according to the official package repository at [search.nixos.org/packages?channel=25.05](https://search.nixos.org/packages?channel=25.05).

### 🔄 **Key Changes Made**

#### **1. PHP Package Name**
**Before (NixOS 24.x):**
```nix
environment.systemPackages = with pkgs; [
  php84  # Explicit version
];
```

**After (NixOS 25.05):**
```nix
environment.systemPackages = with pkgs; [
  php  # In NixOS 25.05, 'php' = PHP 8.4
];
```

#### **2. PHP-FPM Package Reference**
**Before:**
```nix
phpPackage = pkgs.php84.buildEnv {
```

**After:**
```nix
phpPackage = pkgs.php.buildEnv {  # 'php' = PHP 8.4 in NixOS 25.05
```

#### **3. PHP Extensions Naming**
**Before:**
```nix
extensions = ({ enabled, all }: enabled ++ (with all; [
  mysqli
  pdo_mysql
  # ... other extensions
]));
```

**After:**
```nix
extensions = ({ enabled, all }: enabled ++ (with pkgs.php84Extensions; [
  mysqli
  pdo_mysql
  # ... other extensions
]));
```

## 🎯 **NixOS 25.05 Package Naming Convention**

### **Core PHP Package**
- **Package Name**: `php`
- **Version**: PHP 8.4 (default)
- **Usage**: `pkgs.php`

### **PHP Extensions**
- **Naming Pattern**: `php84Extensions.*`
- **Examples**:
  - `pkgs.php84Extensions.mysqli`
  - `pkgs.php84Extensions.pdo_mysql`
  - `pkgs.php84Extensions.mbstring`
  - `pkgs.php84Extensions.gd`
  - `pkgs.php84Extensions.curl`

### **Available Extensions in NixOS 25.05**
```nix
with pkgs.php84Extensions; [
  # Database
  mysqli
  pdo_mysql
  pdo_pgsql
  pdo_sqlite
  
  # String/Text Processing
  mbstring
  intl
  iconv
  
  # File/Archive
  zip
  fileinfo
  
  # Graphics
  gd
  exif
  
  # Network
  curl
  openssl
  
  # Core
  json
  session
  filter
  
  # Performance
  opcache
  
  # Development
  xdebug
]
```

## 📦 **Updated Configuration Structure**

### **Complete PHP-FPM Configuration**
```nix
services.phpfpm = {
  pools.www = {
    user = "nginx";
    group = "nginx";
    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "listen.mode" = "0600";
      "pm" = "dynamic";
      "pm.max_children" = 75;
      "pm.start_servers" = 10;
      "pm.min_spare_servers" = 5;
      "pm.max_spare_servers" = 20;
      "pm.max_requests" = 500;
    };
    # NixOS 25.05: 'php' = PHP 8.4, extensions = php84Extensions.*
    phpPackage = pkgs.php.buildEnv {
      extensions = ({ enabled, all }: enabled ++ (with pkgs.php84Extensions; [
        mysqli
        pdo_mysql
        mbstring
        zip
        gd
        curl
        json
        session
        filter
        openssl
        fileinfo
        intl
        exif
      ]));
      extraConfig = ''
        memory_limit = 256M
        upload_max_filesize = 64M
        post_max_size = 64M
        max_execution_time = 300
        max_input_vars = 3000
        date.timezone = UTC
        
        ; PHP 8.4 optimizations
        opcache.enable = 1
        opcache.memory_consumption = 128
        opcache.interned_strings_buffer = 8
        opcache.max_accelerated_files = 4000
        opcache.revalidate_freq = 2
        opcache.fast_shutdown = 1
        
        ; Security settings
        expose_php = Off
        display_errors = Off
        log_errors = On
        error_log = /var/log/php_errors.log
      '';
    };
  };
};
```

## ✅ **Verification Commands**

### **Check PHP Version**
```bash
nix-instantiate --eval --expr 'let pkgs = import <nixpkgs> {}; in pkgs.php.version'
# Expected: "8.4.8" (or latest 8.4.x)
```

### **List Available PHP Extensions**
```bash
nix-env -qaP | grep php84Extensions
```

### **Verify Configuration Syntax**
```bash
nix-instantiate --parse configuration.nix
```

## 🔍 **Package Search**

To find PHP-related packages in NixOS 25.05:

1. **Visit**: [search.nixos.org/packages?channel=25.05](https://search.nixos.org/packages?channel=25.05)
2. **Search for**: `php` or `php84Extensions`
3. **Filter by**: Package name contains your desired extension

## 🎉 **Benefits of Updated Naming**

1. **Consistency**: Follows NixOS 25.05 package repository standards
2. **Clarity**: Clear distinction between core PHP and extensions
3. **Maintainability**: Easier to manage and update
4. **Future-Proof**: Aligned with NixOS development direction
5. **Documentation**: Matches official NixOS documentation

## 📚 **References**

- [NixOS 25.05 Package Search](https://search.nixos.org/packages?channel=25.05)
- [NixOS PHP Documentation](https://nixos.org/manual/nixos/stable/index.html#sec-php)
- [PHP 8.4 Release Notes](https://www.php.net/releases/8.4/en.php)

The configuration has been updated to use the correct NixOS 25.05 package naming conventions and is ready for deployment!