# Hosts Configuration Instructions

## ✅ Problem Resolved

The networking.hosts configuration has been **removed** from `configuration.nix` to prevent conflicts with your existing flake setup.

## 🎯 Next Steps

You need to add the networking.hosts configuration to your host-specific file:

### 1. Edit your king.nix file

Open your host configuration file:
```bash
sudo nano /home/mark/etc/nixos/modules/hosts/king.nix
```

### 2. Add the networking.hosts section

Add this configuration to your `king.nix` file (merge with existing networking configuration if present):

```nix
{
  # Web server hosts configuration
  networking.hosts = {
    "127.0.0.1" = [ "localhost" "dashboard.local" "phpmyadmin.local" "sample1.local" "sample2.local" "sample3.local" ];
    "127.0.0.2" = [ "king" ];
  };
}
```

### 3. If you already have networking.hosts in king.nix

If your `king.nix` already has a `networking.hosts` section, **merge** the entries:

```nix
{
  networking.hosts = {
    "127.0.0.1" = [ 
      "localhost" 
      # ... your existing entries ...
      "dashboard.local" 
      "phpmyadmin.local" 
      "sample1.local" 
      "sample2.local" 
      "sample3.local" 
    ];
    "127.0.0.2" = [ "king" ];
    # ... any other IP mappings you have ...
  };
}
```

### 4. Rebuild your system

After updating `king.nix`:
```bash
sudo nixos-rebuild switch
```

## 📋 What This Achieves

- **Separates concerns**: Web server config in this project, host-specific networking in your host config
- **Prevents conflicts**: No duplicate networking.hosts definitions
- **Maintains modularity**: Follows your flake-based modular structure
- **Preserves existing setup**: Keeps your existing host configuration intact

## 🔍 Verification

After rebuilding, verify the hosts are working:
```bash
ping -c 1 dashboard.local
ping -c 1 phpmyadmin.local
```

## 📁 Files in This Project

- `configuration.nix` - ✅ Web server configuration (networking.hosts removed)
- `king-hosts-config.nix` - Reference file with the exact configuration to add
- This instruction file

The web server configuration is now properly separated from your host-specific networking configuration!