#!/usr/bin/env bash

# Hosts file management utility for .local domains
# Usage: manage-hosts [add|remove|list|backup|restore] [domain]

HOSTS_FILE="/etc/hosts"
BACKUP_DIR="/etc/hosts-backups"

case "$1" in
    add)
        if [ -z "$2" ]; then
            echo "Usage: manage-hosts add <domain>"
            exit 1
        fi
        
        DOMAIN="$2"
        
        # Check if domain ends with .local
        if [[ ! "$DOMAIN" =~ \.local$ ]]; then
            echo "Warning: Domain '$DOMAIN' is not a .local domain"
        fi
        
        # Check if entry already exists
        if grep -q "127.0.0.1.*$DOMAIN" "$HOSTS_FILE"; then
            echo "Domain '$DOMAIN' already exists in hosts file"
            exit 0
        fi
        
        # Create backup
        cp "$HOSTS_FILE" "$BACKUP_DIR/hosts.backup.$(date +%Y%m%d-%H%M%S)"
        
        # Add entry
        echo "127.0.0.1 $DOMAIN" >> "$HOSTS_FILE"
        echo "Added '$DOMAIN' to hosts file"
        ;;
        
    remove)
        if [ -z "$2" ]; then
            echo "Usage: manage-hosts remove <domain>"
            exit 1
        fi
        
        DOMAIN="$2"
        
        # Create backup
        cp "$HOSTS_FILE" "$BACKUP_DIR/hosts.backup.$(date +%Y%m%d-%H%M%S)"
        
        # Remove entry
        sed -i "/^127\.0\.0\.1.*$DOMAIN$/d" "$HOSTS_FILE"
        echo "Removed '$DOMAIN' from hosts file"
        ;;
        
    list)
        echo "Current .local domains in hosts file:"
        grep "127.0.0.1.*\.local" "$HOSTS_FILE" || echo "No .local domains found"
        ;;
        
    backup)
        BACKUP_FILE="$BACKUP_DIR/hosts.manual.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$HOSTS_FILE" "$BACKUP_FILE"
        echo "Hosts file backed up to: $BACKUP_FILE"
        ;;
        
    restore)
        if [ -z "$2" ]; then
            echo "Available backups:"
            ls -la "$BACKUP_DIR/"
            echo "Usage: manage-hosts restore <backup_filename>"
            exit 1
        fi
        
        BACKUP_FILE="$BACKUP_DIR/$2"
        if [ ! -f "$BACKUP_FILE" ]; then
            echo "Backup file not found: $BACKUP_FILE"
            exit 1
        fi
        
        cp "$BACKUP_FILE" "$HOSTS_FILE"
        echo "Hosts file restored from: $BACKUP_FILE"
        ;;
        
    *)
        echo "Usage: manage-hosts [add|remove|list|backup|restore] [domain|backup_file]"
        echo ""
        echo "Commands:"
        echo "  add <domain>     - Add domain to hosts file (127.0.0.1)"
        echo "  remove <domain>  - Remove domain from hosts file"
        echo "  list             - List all .local domains in hosts file"
        echo "  backup           - Create manual backup of hosts file"
        echo "  restore <file>   - Restore hosts file from backup"
        echo ""
        echo "Examples:"
        echo "  manage-hosts add mysite.local"
        echo "  manage-hosts remove mysite.local"
        echo "  manage-hosts list"
        echo "  manage-hosts backup"
        ;;
esac
