#!/usr/bin/env bash

# Redis management utility
# Usage: manage-redis [status|flushall|flushdb|info] [database]

case "$1" in
    status)
        redis-cli ping 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "Redis Status: Connected"
            redis-cli info server | grep redis_version
            redis-cli info memory | grep used_memory_human
            redis-cli info stats | grep keyspace_hits
            redis-cli info stats | grep keyspace_misses
        else
            echo "Redis Status: Not connected"
        fi
        ;;
        
    flushall)
        echo "Flushing all Redis databases..."
        redis-cli flushall
        echo "All databases flushed"
        ;;
        
    flushdb)
        DB=${2:-0}
        echo "Flushing Redis database $DB..."
        redis-cli -n $DB flushdb
        echo "Database $DB flushed"
        ;;
        
    info)
        redis-cli info
        ;;
        
    *)
        echo "Usage: manage-redis [status|flushall|flushdb|info] [database]"
        echo ""
        echo "Commands:"
        echo "  status           - Show Redis connection status"
        echo "  flushall         - Flush all Redis databases"
        echo "  flushdb [db]     - Flush specific database (default: 0)"
        echo "  info             - Show detailed Redis information"
        echo ""
        echo "Examples:"
        echo "  manage-redis status"
        echo "  manage-redis flushall"
        echo "  manage-redis flushdb 1"
        ;;
esac
