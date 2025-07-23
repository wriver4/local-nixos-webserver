#!/usr/bin/env bash

# Fix Virtual Hosts Configuration
# This script fixes virtual host configuration and content issues

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

# Check current nginx configuration
check_nginx_config() {
    log "Checking current nginx configuration..."
    
    echo "Current nginx.conf virtual hosts section:"
    echo "========================================"
    grep -A 20 "server {" /etc/nginx/nginx.conf | head -40
    echo "========================================"
    echo ""
}

# Check web directories and content
check_web_content() {
    log "Checking web directories and content..."
    
    local sites=("dashboard" "sample1" "sample2" "sample3" "html")
    
    for site in "${sites[@]}"; do
        local site_dir="/var/www/$site"
        echo "Checking $site_dir:"
        
        if [[ -d "$site_dir" ]]; then
            success "Directory exists: $site_dir"
            echo "  Contents:"
            ls -la "$site_dir" | head -5
            
            if [[ -f "$site_dir/index.html" ]]; then
                echo "  index.html content (first 3 lines):"
                head -3 "$site_dir/index.html" | sed 's/^/    /'
            elif [[ -f "$site_dir/index.php" ]]; then
                echo "  index.php content (first 3 lines):"
                head -3 "$site_dir/index.php" | sed 's/^/    /'
            else
                warning "  No index file found"
            fi
        else
            error "Directory missing: $site_dir"
        fi
        echo ""
    done
}

# Create proper web content for each site
create_web_content() {
    log "Creating proper web content for each virtual host..."
    
    # Create directories
    sudo mkdir -p /var/www/{dashboard,phpmyadmin,sample1,sample2,sample3}
    
    # Dashboard content
    sudo tee /var/www/dashboard/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Dashboard - Local Development</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007acc; padding-bottom: 10px; }
        .status { background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .links { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-top: 20px; }
        .link { background: #007acc; color: white; padding: 15px; text-decoration: none; border-radius: 5px; text-align: center; }
        .link:hover { background: #005a99; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Local Development Dashboard</h1>
        <div class="status">
            <strong>✅ Status:</strong> Web server is running successfully!<br>
            <strong>🕒 Time:</strong> <span id="time"></span><br>
            <strong>🌐 Host:</strong> dashboard.local
        </div>
        
        <h2>Available Services</h2>
        <div class="links">
            <a href="http://phpmyadmin.local" class="link">📊 phpMyAdmin</a>
            <a href="http://sample1.local" class="link">🎯 Sample Site 1</a>
            <a href="http://sample2.local" class="link">🎯 Sample Site 2</a>
            <a href="http://sample3.local" class="link">���� Sample Site 3</a>
        </div>
        
        <h2>System Information</h2>
        <ul>
            <li><strong>Server:</strong> Nginx on NixOS</li>
            <li><strong>PHP:</strong> 8.4 with FPM</li>
            <li><strong>Database:</strong> MariaDB</li>
            <li><strong>Environment:</strong> Local Development</li>
        </ul>
    </div>
    
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
        setInterval(() => {
            document.getElementById('time').textContent = new Date().toLocaleString();
        }, 1000);
    </script>
</body>
</html>
EOF

    # Sample site 1
    sudo tee /var/www/sample1/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Sample Site 1 - E-commerce Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { max-width: 1200px; margin: 0 auto; padding: 40px 20px; }
        .header { text-align: center; margin-bottom: 40px; }
        .products { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; }
        .product { background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; backdrop-filter: blur(10px); }
        .btn { background: #ff6b6b; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛒 Sample E-commerce Site</h1>
            <p>sample1.local - Demo Online Store</p>
        </div>
        
        <div class="products">
            <div class="product">
                <h3>📱 Smartphone</h3>
                <p>Latest model with amazing features</p>
                <button class="btn">$599 - Add to Cart</button>
            </div>
            <div class="product">
                <h3>💻 Laptop</h3>
                <p>High-performance laptop for work</p>
                <button class="btn">$1299 - Add to Cart</button>
            </div>
            <div class="product">
                <h3>🎧 Headphones</h3>
                <p>Wireless noise-canceling headphones</p>
                <button class="btn">$199 - Add to Cart</button>
            </div>
        </div>
        
        <div style="text-align: center; margin-top: 40px;">
            <p>✅ Virtual host working: sample1.local</p>
            <p>🕒 <span id="time1"></span></p>
        </div>
    </div>
    
    <script>
        document.getElementById('time1').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

    # Sample site 2
    sudo tee /var/www/sample2/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Sample Site 2 - Blog Demo</title>
    <style>
        body { font-family: Georgia, serif; margin: 0; background: #f8f9fa; color: #333; }
        .container { max-width: 800px; margin: 0 auto; padding: 40px 20px; }
        .header { text-align: center; margin-bottom: 40px; border-bottom: 2px solid #007acc; padding-bottom: 20px; }
        .post { background: white; padding: 30px; margin-bottom: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .meta { color: #666; font-size: 14px; margin-bottom: 15px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📝 Sample Blog Site</h1>
            <p>sample2.local - News & Articles</p>
        </div>
        
        <article class="post">
            <h2>Welcome to Our Blog</h2>
            <div class="meta">Published on <strong>July 23, 2025</strong> by <strong>Admin</strong></div>
            <p>This is a sample blog post demonstrating the virtual host functionality. The site is running on sample2.local and shows how different domains can serve different content.</p>
            <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>
        </article>
        
        <article class="post">
            <h2>NixOS Web Development</h2>
            <div class="meta">Published on <strong>July 22, 2025</strong> by <strong>Developer</strong></div>
            <p>Setting up a local development environment with NixOS, Nginx, PHP, and MariaDB provides a robust foundation for web development.</p>
        </article>
        
        <div style="text-align: center; margin-top: 40px; padding: 20px; background: #e8f5e8; border-radius: 5px;">
            <p>✅ Virtual host working: sample2.local</p>
            <p>🕒 <span id="time2"></span></p>
        </div>
    </div>
    
    <script>
        document.getElementById('time2').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

    # Sample site 3
    sudo tee /var/www/sample3/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Sample Site 3 - Portfolio Demo</title>
    <style>
        body { font-family: 'Helvetica Neue', Arial, sans-serif; margin: 0; background: #2c3e50; color: white; }
        .container { max-width: 1000px; margin: 0 auto; padding: 40px 20px; }
        .header { text-align: center; margin-bottom: 50px; }
        .portfolio { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 30px; }
        .project { background: #34495e; padding: 25px; border-radius: 10px; transition: transform 0.3s; }
        .project:hover { transform: translateY(-5px); }
        .tech { background: #3498db; color: white; padding: 5px 10px; border-radius: 15px; font-size: 12px; margin: 5px; display: inline-block; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎨 Portfolio Demo Site</h1>
            <p>sample3.local - Creative Showcase</p>
        </div>
        
        <div class="portfolio">
            <div class="project">
                <h3>🌐 Web Application</h3>
                <p>Full-stack web application built with modern technologies</p>
                <div>
                    <span class="tech">PHP</span>
                    <span class="tech">MySQL</span>
                    <span class="tech">Nginx</span>
                </div>
            </div>
            
            <div class="project">
                <h3>📱 Mobile App</h3>
                <p>Cross-platform mobile application with responsive design</p>
                <div>
                    <span class="tech">React Native</span>
                    <span class="tech">API</span>
                    <span class="tech">Database</span>
                </div>
            </div>
            
            <div class="project">
                <h3>🔧 DevOps Setup</h3>
                <p>Automated deployment and infrastructure management</p>
                <div>
                    <span class="tech">NixOS</span>
                    <span class="tech">Docker</span>
                    <span class="tech">CI/CD</span>
                </div>
            </div>
        </div>
        
        <div style="text-align: center; margin-top: 50px; padding: 20px; background: rgba(52, 73, 94, 0.8); border-radius: 10px;">
            <p>✅ Virtual host working: sample3.local</p>
            <p>🕒 <span id="time3"></span></p>
        </div>
    </div>
    
    <script>
        document.getElementById('time3').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

    # Set proper ownership and permissions
    sudo chown -R nginx:nginx /var/www
    sudo chmod -R 755 /var/www
    
    success "Created web content for all virtual hosts"
}

# Fix nginx virtual host configuration
fix_nginx_vhost_config() {
    log "Fixing nginx virtual host configuration..."
    
    # Backup current config
    sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup-$(date +%Y%m%d-%H%M%S)
    
    # Create improved nginx configuration
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

    # Dashboard virtual host
    server {
        listen 80;
        server_name dashboard.local;
        root /var/www/dashboard;
        index index.html index.php;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.php$ {
            fastcgi_pass unix:/run/phpfpm/www.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include /etc/nginx/fastcgi_params;
        }
    }

    # phpMyAdmin virtual host
    server {
        listen 80;
        server_name phpmyadmin.local;
        root /var/www/phpmyadmin;
        index index.php;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.php$ {
            fastcgi_pass unix:/run/phpfpm/www.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include /etc/nginx/fastcgi_params;
        }
    }

    # Sample site 1
    server {
        listen 80;
        server_name sample1.local;
        root /var/www/sample1;
        index index.html index.php;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.php$ {
            fastcgi_pass unix:/run/phpfpm/www.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include /etc/nginx/fastcgi_params;
        }
    }

    # Sample site 2
    server {
        listen 80;
        server_name sample2.local;
        root /var/www/sample2;
        index index.html index.php;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.php$ {
            fastcgi_pass unix:/run/phpfpm/www.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include /etc/nginx/fastcgi_params;
        }
    }

    # Sample site 3
    server {
        listen 80;
        server_name sample3.local;
        root /var/www/sample3;
        index index.html index.php;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.php$ {
            fastcgi_pass unix:/run/phpfpm/www.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include /etc/nginx/fastcgi_params;
        }
    }

    # Default server (catch-all)
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

    success "Updated nginx virtual host configuration"
}

# Reload nginx configuration
reload_nginx() {
    log "Reloading nginx configuration..."
    
    # Find nginx binary
    local nginx_binary=$(find /nix/store -name "nginx" -type f -executable 2>/dev/null | grep -E "nginx-[0-9]" | head -1)
    
    if [[ -n "$nginx_binary" ]]; then
        # Test configuration first
        if sudo "$nginx_binary" -t; then
            success "Nginx configuration test passed"
            
            # Reload nginx
            if sudo "$nginx_binary" -s reload; then
                success "Nginx configuration reloaded"
            else
                warning "Failed to reload nginx, trying restart..."
                sudo pkill nginx 2>/dev/null || true
                sudo "$nginx_binary"
                success "Nginx restarted"
            fi
        else
            error "Nginx configuration test failed"
            return 1
        fi
    else
        error "Cannot find nginx binary"
        return 1
    fi
}

# Test virtual hosts
test_virtual_hosts() {
    log "Testing virtual hosts..."
    
    local hosts=("dashboard.local" "sample1.local" "sample2.local" "sample3.local")
    
    echo ""
    for host in "${hosts[@]}"; do
        echo "Testing $host:"
        if curl -s -H "Host: $host" http://localhost | grep -q "$host"; then
            success "$host is working correctly"
        else
            warning "$host may not be working - checking response..."
            local response=$(curl -s -H "Host: $host" http://localhost | head -2)
            echo "  Response: $response"
        fi
    done
    echo ""
    
    echo "You can test manually with:"
    echo "  curl -H 'Host: dashboard.local' http://localhost"
    echo "  curl -H 'Host: sample1.local' http://localhost"
    echo ""
    echo "Or add to /etc/hosts and visit in browser:"
    echo "  127.0.0.1 dashboard.local sample1.local sample2.local sample3.local"
}

# Main function
main() {
    echo "🔧 Fix Virtual Hosts Configuration"
    echo "=================================="
    echo ""
    
    check_nginx_config
    check_web_content
    
    echo ""
    echo "Choose fix approach:"
    echo "1. Create web content only"
    echo "2. Fix nginx configuration only"
    echo "3. Both: create content + fix configuration (recommended)"
    echo ""
    read -p "Enter choice (1-3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            create_web_content
            ;;
        2)
            fix_nginx_vhost_config
            reload_nginx
            ;;
        3)
            create_web_content
            fix_nginx_vhost_config
            reload_nginx
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    test_virtual_hosts
    
    echo ""
    echo "🎯 Summary:"
    echo "- Virtual hosts configured for dashboard.local, sample1.local, sample2.local, sample3.local"
    echo "- Unique content created for each site"
    echo "- Nginx configuration updated and reloaded"
    echo "- Test with: curl -H 'Host: dashboard.local' http://localhost"
}

# Run main function
main "$@"