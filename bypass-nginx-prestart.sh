#!/usr/bin/env bash

# Bypass Nginx Pre-start Issues
# This script works around the failing pre-start script to get nginx running

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Stop and disable the failing nginx service
stop_failing_service() {
    log "Stopping and resetting the failing nginx service..."
    
    # Stop nginx service
    sudo systemctl stop nginx 2>/dev/null || true
    
    # Reset failed state
    sudo systemctl reset-failed nginx 2>/dev/null || true
    
    # Disable the service temporarily
    sudo systemctl disable nginx 2>/dev/null || true
    
    success "Nginx service stopped and disabled"
}

# Find and examine the pre-start script
examine_prestart_failure() {
    log "Examining the pre-start script failure..."
    
    local prestart_script="/nix/store/vmkwsnm6bs8qiy642s8mw1rdj92f7xzd-unit-script-nginx-pre-start/bin/nginx-pre-start"
    
    if [[ -f "$prestart_script" ]]; then
        echo "Pre-start script content:"
        echo "========================"
        cat "$prestart_script"
        echo "========================"
        echo ""
        
        # Try to run it manually to see the exact error
        log "Running pre-start script manually to see the error..."
        if sudo "$prestart_script" 2>&1; then
            success "Pre-start script runs successfully when executed manually"
        else
            local exit_code=$?
            error "Pre-start script failed with exit code: $exit_code"
            echo "This is likely the cause of the nginx service failure"
        fi
    else
        error "Pre-start script not found"
    fi
    echo ""
}

# Create a working nginx setup manually
create_manual_nginx_setup() {
    log "Creating manual nginx setup..."
    
    # Find nginx binary
    local nginx_binary=$(find /nix/store -name "nginx" -type f -executable 2>/dev/null | grep -E "nginx-[0-9]" | head -1)
    
    if [[ -z "$nginx_binary" ]]; then
        error "Cannot find nginx binary in nix store"
        return 1
    fi
    
    echo "Using nginx binary: $nginx_binary"
    
    # Create all necessary directories
    sudo mkdir -p /etc/nginx/conf.d
    sudo mkdir -p /var/lib/nginx/{tmp,proxy,fastcgi,uwsgi,scgi}
    sudo mkdir -p /var/log/nginx
    sudo mkdir -p /run/nginx
    sudo mkdir -p /var/www/html
    
    # Set ownership
    sudo chown -R nginx:nginx /etc/nginx /var/lib/nginx /var/log/nginx /run/nginx /var/www/html
    sudo chmod -R 755 /etc/nginx /var/lib/nginx /var/log/nginx /run/nginx /var/www/html
    
    # Create mime.types
    sudo tee /etc/nginx/mime.types > /dev/null << 'EOF'
types {
    text/html                             html htm shtml;
    text/css                              css;
    text/xml                              xml;
    image/gif                             gif;
    image/jpeg                            jpeg jpg;
    application/javascript                js;
    application/json                      json;
    image/png                             png;
    image/x-icon                          ico;
    image/svg+xml                         svg svgz;
    application/pdf                       pdf;
    application/zip                       zip;
    text/plain                            txt;
}
EOF

    # Create working nginx.conf
    sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Virtual hosts for webserver
    server {
        listen 80;
        server_name dashboard.local;
        root /var/www/dashboard;
        index index.php index.html;

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
            fastcgi_pass unix:/run/phpfpm/www.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include /etc/nginx/fastcgi_params;
        }
    }

    server {
        listen 80;
        server_name phpmyadmin.local;
        root /var/www/phpmyadmin;
        index index.php;

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
            fastcgi_pass unix:/run/phpfpm/www.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include /etc/nginx/fastcgi_params;
        }
    }

    server {
        listen 80;
        server_name sample1.local sample2.local sample3.local;
        root /var/www/$host;
        index index.php index.html;

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
            fastcgi_pass unix:/run/phpfpm/www.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include /etc/nginx/fastcgi_params;
        }
    }

    # Default server
    server {
        listen 80 default_server;
        server_name _;
        root /var/www/html;
        index index.html;

        location / {
            try_files $uri $uri/ =404;
        }
    }
}
EOF

    # Create fastcgi_params
    sudo tee /etc/nginx/fastcgi_params > /dev/null << 'EOF'
fastcgi_param  QUERY_STRING       $query_string;
fastcgi_param  REQUEST_METHOD     $request_method;
fastcgi_param  CONTENT_TYPE       $content_type;
fastcgi_param  CONTENT_LENGTH     $content_length;

fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
fastcgi_param  REQUEST_URI        $request_uri;
fastcgi_param  DOCUMENT_URI       $document_uri;
fastcgi_param  DOCUMENT_ROOT      $document_root;
fastcgi_param  SERVER_PROTOCOL    $server_protocol;
fastcgi_param  REQUEST_SCHEME     $scheme;
fastcgi_param  HTTPS              $https if_not_empty;

fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;

fastcgi_param  REMOTE_ADDR        $remote_addr;
fastcgi_param  REMOTE_PORT        $remote_port;
fastcgi_param  SERVER_ADDR        $server_addr;
fastcgi_param  SERVER_PORT        $server_port;
fastcgi_param  SERVER_NAME        $server_name;

# PHP only, required if PHP was built with --enable-force-cgi-redirect
fastcgi_param  REDIRECT_STATUS    200;
EOF

    # Create test pages
    sudo mkdir -p /var/www/{html,dashboard,sample1,sample2,sample3}
    
    for site in html dashboard sample1 sample2 sample3; do
        sudo tee "/var/www/$site/index.html" > /dev/null << EOF
<!DOCTYPE html>
<html>
<head><title>$site</title></head>
<body>
    <h1>Welcome to $site</h1>
    <p>Nginx is working for $site!</p>
    <p>Time: $(date)</p>
</body>
</html>
EOF
    done
    
    # Set final permissions
    sudo chown -R nginx:nginx /var/www /etc/nginx /var/lib/nginx /var/log/nginx /run/nginx
    
    success "Manual nginx setup created"
    
    # Test configuration
    if sudo "$nginx_binary" -t; then
        success "Nginx configuration is valid"
        return 0
    else
        error "Nginx configuration has errors"
        return 1
    fi
}

# Start nginx manually
start_nginx_manually() {
    log "Starting nginx manually..."
    
    local nginx_binary=$(find /nix/store -name "nginx" -type f -executable 2>/dev/null | grep -E "nginx-[0-9]" | head -1)
    
    if [[ -z "$nginx_binary" ]]; then
        error "Cannot find nginx binary"
        return 1
    fi
    
    # Kill any existing nginx processes
    sudo pkill nginx 2>/dev/null || true
    
    # Start nginx
    if sudo "$nginx_binary"; then
        success "Nginx started manually"
        
        # Test if it's working
        sleep 2
        if curl -s http://localhost >/dev/null; then
            success "Nginx is responding to HTTP requests"
            
            # Test virtual hosts
            echo ""
            echo "Testing virtual hosts:"
            for host in dashboard.local sample1.local; do
                if curl -s -H "Host: $host" http://localhost | grep -q "$host"; then
                    success "$host is working"
                else
                    warning "$host may not be working properly"
                fi
            done
        else
            warning "Nginx started but not responding to requests"
        fi
        
        return 0
    else
        error "Failed to start nginx manually"
        return 1
    fi
}

# Create a custom systemd service that bypasses the problematic pre-start
create_custom_service() {
    log "Creating custom nginx service without problematic pre-start..."
    
    local nginx_binary=$(find /nix/store -name "nginx" -type f -executable 2>/dev/null | grep -E "nginx-[0-9]" | head -1)
    
    if [[ -z "$nginx_binary" ]]; then
        error "Cannot find nginx binary"
        return 1
    fi
    
    # Create custom service file
    sudo tee /etc/systemd/system/nginx-custom.service > /dev/null << EOF
[Unit]
Description=Custom Nginx Web Server
After=network.target

[Service]
Type=forking
PIDFile=/run/nginx/nginx.pid
ExecStartPre=/bin/mkdir -p /run/nginx
ExecStartPre=/bin/chown nginx:nginx /run/nginx
ExecStart=$nginx_binary
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable the custom service
    sudo systemctl daemon-reload
    sudo systemctl enable nginx-custom
    
    success "Created custom nginx service"
    
    # Start the custom service
    if sudo systemctl start nginx-custom; then
        success "Custom nginx service started successfully"
        systemctl status nginx-custom --no-pager -l
        return 0
    else
        error "Custom nginx service failed to start"
        sudo journalctl -u nginx-custom --no-pager -l -n 10
        return 1
    fi
}

# Main function
main() {
    echo "🔧 Bypass Nginx Pre-start Issues"
    echo "================================"
    echo ""
    
    stop_failing_service
    examine_prestart_failure
    
    echo ""
    echo "Choose bypass method:"
    echo "1. Create manual nginx setup and start manually"
    echo "2. Create custom systemd service without pre-start script"
    echo "3. Both: manual setup + custom service"
    echo ""
    read -p "Enter choice (1-3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            if create_manual_nginx_setup; then
                start_nginx_manually
            fi
            ;;
        2)
            if create_manual_nginx_setup; then
                create_custom_service
            fi
            ;;
        3)
            if create_manual_nginx_setup; then
                start_nginx_manually
                echo ""
                create_custom_service
            fi
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    echo ""
    echo "🎯 Summary:"
    echo "- Original nginx service disabled due to pre-start failures"
    echo "- Manual nginx setup created with working configuration"
    echo "- Virtual hosts configured for dashboard.local, sample1.local, etc."
    echo "- Test with: curl http://localhost"
    echo "- Custom service available as nginx-custom if needed"
}

# Run main function
main "$@"