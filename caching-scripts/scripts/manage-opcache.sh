#!/usr/bin/env bash

# OPcache management utility
# Usage: manage-opcache [status|reset|invalidate] [file]

case "$1" in
    status)
        php -r "
        if (function_exists('opcache_get_status')) {
            \$status = opcache_get_status();
            if (\$status) {
                echo 'OPcache Status: Enabled\n';
                echo 'Hit Rate: ' . number_format((\$status['opcache_statistics']['hits'] / (\$status['opcache_statistics']['hits'] + \$status['opcache_statistics']['misses'])) * 100, 2) . '%\n';
                echo 'Cached Scripts: ' . \$status['opcache_statistics']['num_cached_scripts'] . '\n';
                echo 'Memory Usage: ' . number_format(\$status['memory_usage']['used_memory'] / 1024 / 1024, 2) . ' MB\n';
            } else {
                echo 'OPcache Status: Disabled\n';
            }
        } else {
            echo 'OPcache: Not available\n';
        }
        "
        ;;
        
    reset)
        php -r "
        if (function_exists('opcache_reset')) {
            if (opcache_reset()) {
                echo 'OPcache reset successfully\n';
            } else {
                echo 'Failed to reset OPcache\n';
            }
        } else {
            echo 'OPcache not available\n';
        }
        "
        ;;
        
    invalidate)
        if [ -z "$2" ]; then
            echo "Usage: manage-opcache invalidate <file_path>"
            exit 1
        fi
        
        php -r "
        if (function_exists('opcache_invalidate')) {
            if (opcache_invalidate('$2', true)) {
                echo 'File invalidated: $2\n';
            } else {
                echo 'Failed to invalidate: $2\n';
            }
        } else {
            echo 'OPcache not available\n';
        }
        "
        ;;
        
    *)
        echo "Usage: manage-opcache [status|reset|invalidate] [file]"
        echo ""
        echo "Commands:"
        echo "  status           - Show OPcache status"
        echo "  reset            - Reset OPcache (clear all cached files)"
        echo "  invalidate <file> - Invalidate specific file"
        echo ""
        echo "Examples:"
        echo "  manage-opcache status"
        echo "  manage-opcache reset"
        echo "  manage-opcache invalidate /var/www/mysite/index.php"
        ;;
esac
