# NixOS Nginx Configuration Fix Summary

## Problem Identified

The error `The option 'services.nginx.virtualHosts."dashboard.local".index' does not exist` was occurring because the nginx configuration was incorrectly placing the `index` directive at the virtual host level, which is not supported in the NixOS nginx module.

## Root Cause

In NixOS nginx module, the `index` directive cannot be placed directly at the virtual host level like this:

```nix
# ❌ INCORRECT - This causes the error
"dashboard.local" = {
  root = "/var/www/dashboard";
  index = "index.php index.html";  # This is invalid in NixOS
  locations = {
    "/" = {
      tryFiles = "$uri $uri/ /index.php?$query_string";
    };
  };
};
```

## Solution Applied

The `index` directive must be placed within the location blocks:

```nix
# ✅ CORRECT - Fixed version
"dashboard.local" = {
  root = "/var/www/dashboard";
  locations = {
    "/" = {
      tryFiles = "$uri $uri/ /index.php?$query_string";
      index = "index.php index.html";  # Moved inside location block
    };
  };
};
```

## Files Fixed

1. **configuration.nix** - Main configuration file
2. **install-on-existing-nixos.sh** - Installation script that generates webserver.nix
3. **webserver-fixed.nix** - Created as a reference for the correct configuration

## Virtual Hosts Fixed

All virtual hosts were corrected:
- `dashboard.local`
- `phpmyadmin.local` 
- `sample1.local`
- `sample2.local`
- `sample3.local`

## Verification

After applying these fixes, the configuration should pass validation:

```bash
sudo nixos-rebuild dry-build  # Test configuration syntax
sudo nixos-rebuild switch     # Apply the changes
```

## Key Takeaway

In NixOS nginx module configuration:
- Use `index` directive inside `locations` blocks, not at the virtual host level
- This is different from standard nginx configuration syntax
- Always test with `nixos-rebuild dry-build` before applying changes

The fix ensures compatibility with NixOS nginx module while maintaining the intended functionality of serving index files for each virtual host.