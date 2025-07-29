# NixOS Web Server Packaging Guide

This document explains how to package and distribute the NixOS Web Server configuration.

## Packaging Options

### 1. Nix Flakes (Recommended)

The modern approach using Nix flakes provides reproducible builds and easy dependency management.

```bash
# Install with flakes
nix profile install github:your-username/nixos-webserver

# Or add to your flake.nix
inputs.nixos-webserver.url = "github:your-username/nixos-webserver";
```

### 2. Traditional Nix Package

Classic Nix package that can be installed system-wide or per-user.

```bash
# Install from local source
nix-env -i -f default.nix

# Install from GitHub
nix-env -i -f https://github.com/your-username/nixos-webserver/archive/main.tar.gz
```

### 3. NixOS Module

Direct integration as a NixOS module in your configuration.

```nix
# In your configuration.nix
imports = [
  (fetchTarball "https://github.com/your-username/nixos-webserver/archive/main.tar.gz")
];

services.nixos-webserver.enable = true;
```

## Distribution Methods

### GitHub Releases

1. Create a release on GitHub
2. Users can install with:
   ```bash
   nix-env -i -f https://github.com/your-username/nixos-webserver/archive/v1.0.0.tar.gz
   ```

### NixOS User Repository (NUR)

Submit to NUR for wider distribution:

1. Fork the NUR repository
2. Add your package to `pkgs/`
3. Submit a pull request

### Cachix Binary Cache

Speed up installations with pre-built binaries:

```bash
# Setup cachix
nix-env -iA cachix -f https://cachix.org/api/v1/install
cachix use your-cache-name

# Push builds
cachix push your-cache-name $(nix-build)
```

## Installation Methods

### Quick Install Script

```bash
curl -sSL https://raw.githubusercontent.com/your-username/nixos-webserver/main/install.sh | bash
```

### Manual Installation

```bash
git clone https://github.com/your-username/nixos-webserver.git
cd nixos-webserver
./install-on-existing-nixos.sh
```

### Flake Installation

```bash
# Temporary shell
nix shell github:your-username/nixos-webserver

# Permanent installation
nix profile install github:your-username/nixos-webserver
```

## Configuration Examples

### Basic Usage

```nix
# configuration.nix
{
  imports = [ ./modules/services/webserver.nix ];
  
  services.nixos-webserver = {
    enable = true;
    webRoot = "/srv/www";
    domains = [ "mysite.local" "api.local" ];
  };
}
```

### Advanced Configuration

```nix
# configuration.nix
{
  services.nixos-webserver = {
    enable = true;
    webRoot = "/var/www";
    phpVersion = pkgs.php84;
    
    nginx = {
      enableSSL = true;
      sslCertificate = "/path/to/cert.pem";
    };
    
    mysql = {
      initialDatabases = [
        { name = "myapp"; }
        { name = "staging"; }
      ];
    };
    
    redis = {
      maxmemory = "1gb";
      maxmemoryPolicy = "allkeys-lru";
    };
  };
}
```

## Development Workflow

### Local Development

```bash
# Enter development shell
nix-shell

# Build package
nix-build

# Test installation
make dev-install

# Test sites
make dev-test-sites
```

### Testing

```bash
# Dry run rebuild
make test

# Full rebuild
make dev-rebuild

# Check services
systemctl status nginx phpfpm-www mysql redis-main
```

## Publishing Checklist

- [ ] Update version numbers
- [ ] Test on clean NixOS installation
- [ ] Update documentation
- [ ] Create GitHub release
- [ ] Update flake.lock
- [ ] Test installation methods
- [ ] Update examples

## Support

For issues and questions:
- GitHub Issues: https://github.com/your-username/nixos-webserver/issues
- Documentation: https://github.com/your-username/nixos-webserver/wiki
- NixOS Discourse: https://discourse.nixos.org/
