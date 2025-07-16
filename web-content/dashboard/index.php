<?php
session_start();

// Database configuration
$db_config = [
    'host' => 'localhost',
    'username' => 'webuser',
    'password' => 'webpass123',
    'database' => 'dashboard_db'
];

// Connect to database
try {
    $pdo = new PDO("mysql:host={$db_config['host']};dbname={$db_config['database']}", 
                   $db_config['username'], $db_config['password']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch(PDOException $e) {
    $db_error = "Connection failed: " . $e->getMessage();
}

// Initialize database tables if they don't exist
if (isset($pdo)) {
    $pdo->exec("CREATE TABLE IF NOT EXISTS sites (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        domain VARCHAR(255) NOT NULL UNIQUE,
        status ENUM('active', 'inactive') DEFAULT 'active',
        document_root VARCHAR(500) DEFAULT '/var/www',
        database_name VARCHAR(100),
        ssl_enabled BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )");
    
    $pdo->exec("CREATE TABLE IF NOT EXISTS logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        site_id INT,
        action VARCHAR(255),
        details TEXT,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE SET NULL
    )");
    
    // Insert sample data if table is empty
    $count = $pdo->query("SELECT COUNT(*) FROM sites")->fetchColumn();
    if ($count == 0) {
        $pdo->exec("INSERT INTO sites (name, domain, status, database_name) VALUES 
            ('Dashboard', 'dashboard.local', 'active', 'dashboard_db'),
            ('phpMyAdmin', 'phpmyadmin.local', 'active', NULL),
            ('Sample Site 1', 'sample1.local', 'active', 'sample1_db'),
            ('Sample Site 2', 'sample2.local', 'active', 'sample2_db'),
            ('Sample Site 3', 'sample3.local', 'active', 'sample3_db')");
    }
}

// Function to check if domain is .local
function isLocalDomain($domain) {
    return substr($domain, -6) === '.local';
}

// Function to backup hosts file
function backupHostsFile() {
    $hosts_file = '/etc/hosts';
    $backup_file = '/etc/hosts.backup.' . date('Y-m-d-H-i-s');
    
    if (file_exists($hosts_file)) {
        if (copy($hosts_file, $backup_file)) {
            return $backup_file;
        }
    }
    return false;
}

// Function to add domain to hosts file
function addToHostsFile($domain) {
    if (!isLocalDomain($domain)) {
        return ['success' => true, 'message' => 'Non-local domain, hosts file not modified'];
    }
    
    $hosts_file = '/etc/hosts';
    
    // Check if entry already exists
    if (file_exists($hosts_file)) {
        $hosts_content = file_get_contents($hosts_file);
        if (strpos($hosts_content, $domain) !== false) {
            return ['success' => true, 'message' => 'Domain already exists in hosts file'];
        }
    }
    
    // Create backup
    $backup_file = backupHostsFile();
    if (!$backup_file) {
        return ['success' => false, 'message' => 'Failed to create hosts file backup'];
    }
    
    // Add entry to hosts file
    $hosts_entry = "127.0.0.1 $domain\n";
    
    if (file_put_contents($hosts_file, $hosts_entry, FILE_APPEND | LOCK_EX) === false) {
        return ['success' => false, 'message' => 'Failed to write to hosts file'];
    }
    
    return [
        'success' => true, 
        'message' => "Added $domain to hosts file",
        'backup' => $backup_file
    ];
}

// Function to remove domain from hosts file
function removeFromHostsFile($domain) {
    if (!isLocalDomain($domain)) {
        return ['success' => true, 'message' => 'Non-local domain, hosts file not modified'];
    }
    
    $hosts_file = '/etc/hosts';
    
    if (!file_exists($hosts_file)) {
        return ['success' => true, 'message' => 'Hosts file does not exist'];
    }
    
    // Create backup
    $backup_file = backupHostsFile();
    if (!$backup_file) {
        return ['success' => false, 'message' => 'Failed to create hosts file backup'];
    }
    
    // Read current hosts file
    $hosts_content = file_get_contents($hosts_file);
    
    // Remove the domain entry (handle various formats)
    $patterns = [
        "/^127\.0\.0\.1\s+$domain\s*$/m",
        "/^127\.0\.0\.1\s+$domain\s*\n/m",
        "/\n127\.0\.0\.1\s+$domain\s*$/m",
        "/\n127\.0\.0\.1\s+$domain\s*\n/m"
    ];
    
    $original_content = $hosts_content;
    foreach ($patterns as $pattern) {
        $hosts_content = preg_replace($pattern, '', $hosts_content);
    }
    
    // Check if anything was actually removed
    if ($hosts_content === $original_content) {
        return ['success' => true, 'message' => 'Domain not found in hosts file'];
    }
    
    // Write updated content back to hosts file
    if (file_put_contents($hosts_file, $hosts_content, LOCK_EX) === false) {
        return ['success' => false, 'message' => 'Failed to write updated hosts file'];
    }
    
    return [
        'success' => true, 
        'message' => "Removed $domain from hosts file",
        'backup' => $backup_file
    ];
}

// Function to get current hosts file entries for .local domains
function getLocalHostsEntries() {
    $hosts_file = '/etc/hosts';
    $local_entries = [];
    
    if (!file_exists($hosts_file)) {
        return $local_entries;
    }
    
    $hosts_content = file_get_contents($hosts_file);
    $lines = explode("\n", $hosts_content);
    
    foreach ($lines as $line) {
        $line = trim($line);
        if (empty($line) || $line[0] === '#') {
            continue;
        }
        
        if (preg_match('/^127\.0\.0\.1\s+(.+\.local)\s*$/', $line, $matches)) {
            $local_entries[] = $matches[1];
        }
    }
    
    return $local_entries;
}

// Function to validate hosts file permissions
function validateHostsPermissions() {
    $hosts_file = '/etc/hosts';
    
    if (!file_exists($hosts_file)) {
        return ['success' => false, 'message' => 'Hosts file does not exist'];
    }
    
    if (!is_readable($hosts_file)) {
        return ['success' => false, 'message' => 'Cannot read hosts file'];
    }
    
    if (!is_writable($hosts_file)) {
        return ['success' => false, 'message' => 'Cannot write to hosts file. Check permissions.'];
    }
    
    return ['success' => true, 'message' => 'Hosts file is accessible'];
}

// Function to get OPcache status
function getOPcacheStatus() {
    if (!function_exists('opcache_get_status')) {
        return ['enabled' => false];
    }
    
    $status = opcache_get_status();
    if (!$status) {
        return ['enabled' => false];
    }
    
    $stats = $status['opcache_statistics'];
    $memory = $status['memory_usage'];
    
    $hits = $stats['hits'];
    $misses = $stats['misses'];
    $total = $hits + $misses;
    $hit_rate = $total > 0 ? ($hits / $total) * 100 : 0;
    
    $used_memory = $memory['used_memory'];
    $free_memory = $memory['free_memory'];
    $wasted_memory = $memory['wasted_memory'];
    $total_memory = $used_memory + $free_memory + $wasted_memory;
    $memory_usage = $total_memory > 0 ? ($used_memory / $total_memory) * 100 : 0;
    
    return [
        'enabled' => true,
        'hit_rate' => $hit_rate,
        'cached_scripts' => $stats['num_cached_scripts'],
        'memory_usage' => $memory_usage,
        'used_memory' => $used_memory,
        'total_memory' => $total_memory
    ];
}

// Function to get Redis status
function getRedisStatus() {
    if (!class_exists('Redis')) {
        return ['available' => false, 'error' => 'Redis extension not installed'];
    }
    
    try {
        $redis = new Redis();
        $redis->connect('127.0.0.1', 6379);
        
        $info = $redis->info();
        
        $hits = intval($info['keyspace_hits'] ?? 0);
        $misses = intval($info['keyspace_misses'] ?? 0);
        $total = $hits + $misses;
        $hit_rate = $total > 0 ? ($hits / $total) * 100 : 0;
        
        // Count active databases
        $active_dbs = 0;
        for ($i = 0; $i < 16; $i++) {
            $redis->select($i);
            if ($redis->dbSize() > 0) {
                $active_dbs++;
            }
        }
        
        return [
            'available' => true,
            'connected' => true,
            'hit_rate' => $hit_rate,
            'active_databases' => $active_dbs,
            'used_memory' => $info['used_memory'] ?? 0,
            'connected_clients' => $info['connected_clients'] ?? 0,
            'version' => $info['redis_version'] ?? 'Unknown'
        ];
    } catch (Exception $e) {
        return ['available' => true, 'connected' => false, 'error' => $e->getMessage()];
    }
}

// Function to generate nginx virtual host configuration
function generateNginxConfig($domain, $document_root = '/var/www', $ssl_enabled = false) {
    $config = "      # {$domain}\n";
    $config .= "      \"{$domain}\" = {\n";
    $config .= "        root = \"{$document_root}/{$domain}\";\n";
    $config .= "        index = \"index.php index.html\";\n";
    
    if ($ssl_enabled) {
        $config .= "        enableACME = true;\n";
        $config .= "        forceSSL = true;\n";
    }
    
    $config .= "        locations = {\n";
    $config .= "          \"/\" = {\n";
    $config .= "            tryFiles = \"\$uri \$uri/ /index.php?\$query_string\";\n";
    $config .= "          };\n";
    $config .= "          \"~ \\\\.php\$\" = {\n";
    $config .= "            extraConfig = ''\n";
    $config .= "              fastcgi_pass unix:\${config.services.phpfpm.pools.www.socket};\n";
    $config .= "              fastcgi_index index.php;\n";
    $config .= "              fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;\n";
    $config .= "              include \${pkgs.nginx}/conf/fastcgi_params;\n";
    $config .= "              \n";
    $config .= "              # FastCGI caching\n";
    $config .= "              fastcgi_cache WORDPRESS;\n";
    $config .= "              fastcgi_cache_valid 200 30m;\n";
    $config .= "              fastcgi_cache_bypass \$skip_cache;\n";
    $config .= "              fastcgi_no_cache \$skip_cache;\n";
    $config .= "              add_header X-FastCGI-Cache \$upstream_cache_status;\n";
    $config .= "            '';\n";
    $config .= "          };\n";
    $config .= "        };\n";
    $config .= "      };\n\n";
    
    return $config;
}

// Function to update NixOS configuration
function updateNixOSConfig($sites) {
    $config_path = '/etc/nixos/configuration.nix';
    $backup_path = '/etc/nixos/configuration.nix.backup.' . date('Y-m-d-H-i-s');
    
    // Read current configuration
    if (!file_exists($config_path)) {
        return ['success' => false, 'message' => 'NixOS configuration file not found'];
    }
    
    $current_config = file_get_contents($config_path);
    
    // Create backup
    file_put_contents($backup_path, $current_config);
    
    // Generate new virtual hosts section
    $virtual_hosts = "    virtualHosts = {\n";
    foreach ($sites as $site) {
        if ($site['status'] === 'active') {
            $virtual_hosts .= generateNginxConfig(
                $site['domain'], 
                $site['document_root'], 
                $site['ssl_enabled']
            );
        }
    }
    $virtual_hosts .= "    };";
    
    // Replace virtual hosts section in configuration
    $pattern = '/virtualHosts\s*=\s*\{.*?\};/s';
    $new_config = preg_replace($pattern, $virtual_hosts, $current_config);
    
    if ($new_config === null) {
        return ['success' => false, 'message' => 'Failed to update configuration'];
    }
    
    // Write updated configuration
    if (file_put_contents($config_path, $new_config) === false) {
        return ['success' => false, 'message' => 'Failed to write configuration file'];
    }
    
    return ['success' => true, 'message' => 'Configuration updated successfully', 'backup' => $backup_path];
}

// Function to create database for new site
function createSiteDatabase($database_name, $pdo) {
    try {
        // Create database
        $pdo->exec("CREATE DATABASE IF NOT EXISTS `{$database_name}`");
        
        // Grant permissions to webuser
        $pdo->exec("GRANT ALL PRIVILEGES ON `{$database_name}`.* TO 'webuser'@'localhost'");
        $pdo->exec("FLUSH PRIVILEGES");
        
        return ['success' => true, 'message' => 'Database created successfully'];
    } catch (Exception $e) {
        return ['success' => false, 'message' => 'Database creation failed: ' . $e->getMessage()];
    }
}

// Handle form submissions
$message = '';
$message_type = '';

if ($_POST) {
    if (isset($_POST['action'])) {
        switch ($_POST['action']) {
            case 'toggle_status':
                if (isset($_POST['site_id'])) {
                    $site_id = $_POST['site_id'];
                    $stmt = $pdo->prepare("UPDATE sites SET status = CASE WHEN status = 'active' THEN 'inactive' ELSE 'active' END WHERE id = ?");
                    $stmt->execute([$site_id]);
                    
                    $log_stmt = $pdo->prepare("INSERT INTO logs (site_id, action, details) VALUES (?, 'Status toggled', 'Site status changed via dashboard')");
                    $log_stmt->execute([$site_id]);
                    
                    $message = 'Site status updated successfully';
                    $message_type = 'success';
                }
                break;
                
            case 'add_site':
                $name = trim($_POST['site_name']);
                $domain = trim($_POST['site_domain']);
                $database_name = trim($_POST['database_name']);
                $ssl_enabled = isset($_POST['ssl_enabled']) ? 1 : 0;
                
                if (empty($name) || empty($domain)) {
                    $message = 'Site name and domain are required';
                    $message_type = 'error';
                } else {
                    try {
                        // Check if domain already exists
                        $check_stmt = $pdo->prepare("SELECT COUNT(*) FROM sites WHERE domain = ?");
                        $check_stmt->execute([$domain]);
                        
                        if ($check_stmt->fetchColumn() > 0) {
                            $message = 'Domain already exists';
                            $message_type = 'error';
                        } else {
                            // Validate hosts file permissions for .local domains
                            if (isLocalDomain($domain)) {
                                $hosts_check = validateHostsPermissions();
                                if (!$hosts_check['success']) {
                                    $message = 'Hosts file error: ' . $hosts_check['message'];
                                    $message_type = 'error';
                                    break;
                                }
                            }
                            
                            // Insert new site
                            $stmt = $pdo->prepare("INSERT INTO sites (name, domain, database_name, ssl_enabled) VALUES (?, ?, ?, ?)");
                            $stmt->execute([$name, $domain, $database_name ?: null, $ssl_enabled]);
                            $site_id = $pdo->lastInsertId();
                            
                            $hosts_result = null;
                            $db_result = null;
                            
                            // Add to hosts file if .local domain
                            if (isLocalDomain($domain)) {
                                $hosts_result = addToHostsFile($domain);
                                if (!$hosts_result['success']) {
                                    // Rollback database insertion if hosts file update fails
                                    $pdo->prepare("DELETE FROM sites WHERE id = ?")->execute([$site_id]);
                                    $message = 'Failed to update hosts file: ' . $hosts_result['message'];
                                    $message_type = 'error';
                                    break;
                                }
                            }
                            
                            // Create database if specified
                            if (!empty($database_name)) {
                                $db_result = createSiteDatabase($database_name, $pdo);
                                if (!$db_result['success']) {
                                    $message = 'Site added but database creation failed: ' . $db_result['message'];
                                    $message_type = 'warning';
                                }
                            }
                            
                            // Create directory
                            $site_dir = "/var/www/{$domain}";
                            if (!is_dir($site_dir)) {
                                mkdir($site_dir, 0755, true);
                                
                                // Create basic index.php
                                $index_content = "<?php\n// {$name}\necho '<h1>Welcome to {$name}</h1><p>This site is hosted on {$domain}</p>';\n?>";
                                file_put_contents("{$site_dir}/index.php", $index_content);
                                
                                // Set proper ownership
                                exec("sudo chown -R nginx:nginx {$site_dir}");
                            }
                            
                            // Log the addition with hosts file info
                            $log_details = "New virtual host created: {$domain}";
                            if ($hosts_result && $hosts_result['success']) {
                                $log_details .= " | " . $hosts_result['message'];
                                if (isset($hosts_result['backup'])) {
                                    $log_details .= " | Backup: " . basename($hosts_result['backup']);
                                }
                            }
                            
                            $log_stmt = $pdo->prepare("INSERT INTO logs (site_id, action, details) VALUES (?, 'Site added', ?)");
                            $log_stmt->execute([$site_id, $log_details]);
                            
                            if (empty($message)) {
                                $success_msg = 'Site added successfully!';
                                if (isLocalDomain($domain)) {
                                    $success_msg .= ' Domain added to hosts file.';
                                }
                                $success_msg .= ' Remember to rebuild NixOS configuration.';
                                $message = $success_msg;
                                $message_type = 'success';
                            }
                        }
                    } catch (Exception $e) {
                        $message = 'Error adding site: ' . $e->getMessage();
                        $message_type = 'error';
                    }
                }
                break;
                
            case 'remove_site':
                if (isset($_POST['site_id'])) {
                    $site_id = $_POST['site_id'];
                    
                    // Get site info before deletion
                    $site_stmt = $pdo->prepare("SELECT * FROM sites WHERE id = ?");
                    $site_stmt->execute([$site_id]);
                    $site = $site_stmt->fetch(PDO::FETCH_ASSOC);
                    
                    if ($site) {
                        // Don't allow removal of core sites
                        $protected_domains = ['dashboard.local', 'phpmyadmin.local'];
                        if (in_array($site['domain'], $protected_domains)) {
                            $message = 'Cannot remove protected system sites';
                            $message_type = 'error';
                        } else {
                            try {
                                $hosts_result = null;
                                
                                // Remove from hosts file if .local domain
                                if (isLocalDomain($site['domain'])) {
                                    $hosts_result = removeFromHostsFile($site['domain']);
                                    if (!$hosts_result['success']) {
                                        $message = 'Warning: Failed to remove from hosts file: ' . $hosts_result['message'];
                                        $message_type = 'warning';
                                    }
                                }
                                
                                // Remove from database
                                $delete_stmt = $pdo->prepare("DELETE FROM sites WHERE id = ?");
                                $delete_stmt->execute([$site_id]);
                                
                                // Log the removal with hosts file info
                                $log_details = "Virtual host removed: {$site['domain']}";
                                if ($hosts_result && $hosts_result['success']) {
                                    $log_details .= " | " . $hosts_result['message'];
                                    if (isset($hosts_result['backup'])) {
                                        $log_details .= " | Backup: " . basename($hosts_result['backup']);
                                    }
                                }
                                
                                $log_stmt = $pdo->prepare("INSERT INTO logs (site_id, action, details) VALUES (NULL, 'Site removed', ?)");
                                $log_stmt->execute([$log_details]);
                                
                                if (empty($message)) {
                                    $success_msg = 'Site removed successfully!';
                                    if (isLocalDomain($site['domain'])) {
                                        $success_msg .= ' Domain removed from hosts file.';
                                    }
                                    $success_msg .= ' Remember to rebuild NixOS configuration and manually remove the directory if needed.';
                                    $message = $success_msg;
                                    $message_type = 'success';
                                }
                            } catch (Exception $e) {
                                $message = 'Error removing site: ' . $e->getMessage();
                                $message_type = 'error';
                            }
                        }
                    }
                }
                break;
                
            case 'rebuild_config':
                // Get all sites for configuration generation
                $sites = $pdo->query("SELECT * FROM sites ORDER BY created_at")->fetchAll(PDO::FETCH_ASSOC);
                $result = updateNixOSConfig($sites);
                
                if ($result['success']) {
                    $log_stmt = $pdo->prepare("INSERT INTO logs (site_id, action, details) VALUES (NULL, 'Config rebuilt', 'NixOS configuration updated')");
                    $log_stmt->execute();
                    
                    $message = 'Configuration updated! Run "sudo nixos-rebuild switch" to apply changes.';
                    $message_type = 'success';
                } else {
                    $message = 'Configuration update failed: ' . $result['message'];
                    $message_type = 'error';
                }
                break;
        }
    }
}

// Get sites data
$sites = [];
$logs = [];
$hosts_entries = [];
if (isset($pdo)) {
    $sites = $pdo->query("SELECT * FROM sites ORDER BY created_at DESC")->fetchAll(PDO::FETCH_ASSOC);
    $logs = $pdo->query("SELECT l.*, s.name as site_name FROM logs l LEFT JOIN sites s ON l.site_id = s.id ORDER BY l.timestamp DESC LIMIT 15")->fetchAll(PDO::FETCH_ASSOC);
    $hosts_entries = getLocalHostsEntries();
}

// Check hosts file permissions
$hosts_permissions = validateHostsPermissions();

// Get cache status
$opcache_status = getOPcacheStatus();
$redis_status = getRedisStatus();

// Format bytes
function formatBytes($bytes, $precision = 2) {
    $units = array('B', 'KB', 'MB', 'GB', 'TB');
    
    for ($i = 0; $bytes > 1024; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web Server Dashboard - Virtual Host Management</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
        }
        
        .header h1 {
            color: #2d3748;
            font-size: 2.5rem;
            font-weight: 700;
            margin-bottom: 10px;
        }
        
        .header p {
            color: #718096;
            font-size: 1.1rem;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 30px;
            margin-bottom: 30px;
        }
        
        .card {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 30px 60px rgba(0, 0, 0, 0.15);
        }
        
        .card h2 {
            color: #2d3748;
            font-size: 1.5rem;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .message {
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
            font-weight: 600;
        }
        
        .message.success {
            background: #c6f6d5;
            color: #22543d;
            border: 1px solid #9ae6b4;
        }
        
        .message.error {
            background: #fed7d7;
            color: #742a2a;
            border: 1px solid #feb2b2;
        }
        
        .message.warning {
            background: #fefcbf;
            color: #744210;
            border: 1px solid #f6e05e;
        }
        
        .hosts-status {
            padding: 10px 15px;
            border-radius: 8px;
            margin-bottom: 15px;
            font-size: 0.9rem;
        }
        
        .hosts-status.success {
            background: #c6f6d5;
            color: #22543d;
            border: 1px solid #9ae6b4;
        }
        
        .hosts-status.error {
            background: #fed7d7;
            color: #742a2a;
            border: 1px solid #feb2b2;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: 600;
            color: #2d3748;
        }
        
        .form-group input, .form-group select {
            width: 100%;
            padding: 12px;
            border: 2px solid #e2e8f0;
            border-radius: 8px;
            font-size: 1rem;
            transition: border-color 0.2s;
        }
        
        .form-group input:focus, .form-group select:focus {
            outline: none;
            border-color: #4299e1;
        }
        
        .checkbox-group {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .checkbox-group input[type="checkbox"] {
            width: auto;
        }
        
        .domain-hint {
            font-size: 0.85rem;
            color: #718096;
            margin-top: 5px;
        }
        
        .local-domain-info {
            background: #e6fffa;
            border: 1px solid #81e6d9;
            color: #234e52;
            padding: 10px;
            border-radius: 6px;
            font-size: 0.85rem;
            margin-top: 10px;
        }
        
        .status-badge {
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .status-active {
            background: #c6f6d5;
            color: #22543d;
        }
        
        .status-inactive {
            background: #fed7d7;
            color: #742a2a;
        }
        
        .site-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px;
            margin: 10px 0;
            background: #f7fafc;
            border-radius: 12px;
            transition: background 0.2s ease;
        }
        
        .site-item:hover {
            background: #edf2f7;
        }
        
        .site-info h3 {
            color: #2d3748;
            margin-bottom: 5px;
        }
        
        .site-info p {
            color: #718096;
            font-size: 0.9rem;
        }
        
        .local-badge {
            background: #bee3f8;
            color: #2a69ac;
            padding: 2px 8px;
            border-radius: 10px;
            font-size: 0.7rem;
            margin-left: 8px;
        }
        
        .site-actions {
            display: flex;
            gap: 8px;
            align-items: center;
        }
        
        .btn {
            padding: 8px 16px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.2s ease;
            text-decoration: none;
            display: inline-block;
            font-size: 0.9rem;
        }
        
        .btn-primary {
            background: #4299e1;
            color: white;
        }
        
        .btn-primary:hover {
            background: #3182ce;
        }
        
        .btn-secondary {
            background: #e2e8f0;
            color: #4a5568;
        }
        
        .btn-secondary:hover {
            background: #cbd5e0;
        }
        
        .btn-danger {
            background: #f56565;
            color: white;
        }
        
        .btn-danger:hover {
            background: #e53e3e;
        }
        
        .btn-success {
            background: #48bb78;
            color: white;
        }
        
        .btn-success:hover {
            background: #38a169;
        }
        
        .quick-links {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        
        .quick-link {
            display: block;
            padding: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            border-radius: 12px;
            text-align: center;
            font-weight: 600;
            transition: transform 0.2s ease;
        }
        
        .quick-link:hover {
            transform: scale(1.05);
        }
        
        .admin-link {
            background: linear-gradient(135deg, #f56565 0%, #e53e3e 100%);
        }
        
        .log-item {
            padding: 10px 15px;
            margin: 8px 0;
            background: #f7fafc;
            border-radius: 8px;
            border-left: 4px solid #4299e1;
        }
        
        .log-time {
            font-size: 0.8rem;
            color: #718096;
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .stat-item {
            text-align: center;
            padding: 20px;
            background: #f7fafc;
            border-radius: 12px;
        }
        
        .stat-number {
            font-size: 2rem;
            font-weight: 700;
            color: #4299e1;
        }
        
        .stat-label {
            color: #718096;
            font-size: 0.9rem;
            margin-top: 5px;
        }
        
        .hosts-entries {
            max-height: 200px;
            overflow-y: auto;
            background: #f7fafc;
            border-radius: 8px;
            padding: 15px;
            margin-top: 15px;
        }
        
        .hosts-entry {
            padding: 5px 0;
            border-bottom: 1px solid #e2e8f0;
            font-family: monospace;
            font-size: 0.9rem;
        }
        
        .hosts-entry:last-child {
            border-bottom: none;
        }
        
        .cache-status {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 15px;
        }
        
        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
        }
        
        .status-enabled {
            background: #48bb78;
        }
        
        .status-disabled {
            background: #f56565;
        }
        
        .status-error {
            background: #ed8936;
        }
        
        .progress-bar {
            width: 100%;
            height: 8px;
            background: #e2e8f0;
            border-radius: 4px;
            overflow: hidden;
            margin: 8px 0;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #48bb78, #38a169);
            transition: width 0.3s ease;
        }
        
        .cache-links {
            display: flex;
            gap: 10px;
            margin-top: 15px;
        }
        
        .modal {
            display: none;
            position: fixed;
            z-index: 1000;
            left: 0;
            top: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0,0,0,0.5);
        }
        
        .modal-content {
            background-color: white;
            margin: 5% auto;
            padding: 30px;
            border-radius: 20px;
            width: 90%;
            max-width: 500px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.3);
        }
        
        .close {
            color: #aaa;
            float: right;
            font-size: 28px;
            font-weight: bold;
            cursor: pointer;
        }
        
        .close:hover {
            color: #000;
        }
        
        .protected-site {
            opacity: 0.7;
        }
        
        .protected-badge {
            background: #fbb6ce;
            color: #97266d;
            padding: 2px 8px;
            border-radius: 10px;
            font-size: 0.7rem;
            margin-left: 8px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Web Server Dashboard</h1>
            <p>Manage your NixOS web server with nginx, PHP-FPM, MySQL, OPcache, and Redis</p>
            <p style="font-size: 0.9rem; margin-top: 10px; color: #4a5568;">
                <strong>Performance Optimization:</strong> OPcache and Redis enabled for maximum performance
            </p>
        </div>
        
        <?php if (!empty($message)): ?>
            <div class="message <?php echo $message_type; ?>">
                <?php echo htmlspecialchars($message); ?>
            </div>
        <?php endif; ?>
        
        <?php if (isset($db_error)): ?>
            <div class="message error">
                <strong>Database Error:</strong> <?php echo htmlspecialchars($db_error); ?>
            </div>
        <?php endif; ?>
        
        <div class="grid">
            <div class="card">
                <h2>📊 Server Statistics</h2>
                <div class="stats">
                    <div class="stat-item">
                        <div class="stat-number"><?php echo count($sites); ?></div>
                        <div class="stat-label">Total Sites</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-number"><?php echo count(array_filter($sites, fn($s) => $s['status'] == 'active')); ?></div>
                        <div class="stat-label">Active Sites</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-number"><?php echo count($hosts_entries); ?></div>
                        <div class="stat-label">Local Domains</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-number"><?php echo count($logs); ?></div>
                        <div class="stat-label">Recent Logs</div>
                    </div>
                </div>
                
                <form method="post" style="margin-top: 20px;">
                    <input type="hidden" name="action" value="rebuild_config">
                    <button type="submit" class="btn btn-success" style="width: 100%;">
                        🔄 Rebuild NixOS Configuration
                    </button>
                </form>
            </div>
            
            <div class="card">
                <h2>⚡ OPcache Status</h2>
                
                <div class="cache-status">
                    <span class="status-indicator <?php echo $opcache_status['enabled'] ? 'status-enabled' : 'status-disabled'; ?>"></span>
                    <span><?php echo $opcache_status['enabled'] ? 'Enabled' : 'Disabled'; ?></span>
                </div>
                
                <?php if ($opcache_status['enabled']): ?>
                    <div class="stats">
                        <div class="stat-item">
                            <div class="stat-number"><?php echo number_format($opcache_status['hit_rate'], 1); ?>%</div>
                            <div class="stat-label">Hit Rate</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-number"><?php echo number_format($opcache_status['cached_scripts']); ?></div>
                            <div class="stat-label">Cached Scripts</div>
                        </div>
                    </div>
                    
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: <?php echo $opcache_status['memory_usage']; ?>%"></div>
                    </div>
                    <p style="font-size: 0.9rem; color: #4a5568; text-align: center;">
                        Memory: <?php echo formatBytes($opcache_status['used_memory']); ?> / <?php echo formatBytes($opcache_status['total_memory']); ?>
                    </p>
                <?php endif; ?>
                
                <div class="cache-links">
                    <a href="/opcache-status.php?direct=1" class="btn btn-primary" target="_blank">
                        📈 Detailed Status
                    </a>
                </div>
            </div>
            
            <div class="card">
                <h2>🔴 Redis Status</h2>
                
                <div class="cache-status">
                    <span class="status-indicator <?php echo $redis_status['available'] && $redis_status['connected'] ? 'status-enabled' : ($redis_status['available'] ? 'status-error' : 'status-disabled'); ?>"></span>
                    <span>
                        <?php 
                        if (!$redis_status['available']) {
                            echo 'Not Available';
                        } elseif (!$redis_status['connected']) {
                            echo 'Connection Error';
                        } else {
                            echo 'Connected';
                        }
                        ?>
                    </span>
                </div>
                
                <?php if ($redis_status['available'] && $redis_status['connected']): ?>
                    <div class="stats">
                        <div class="stat-item">
                            <div class="stat-number"><?php echo number_format($redis_status['hit_rate'], 1); ?>%</div>
                            <div class="stat-label">Hit Rate</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-number"><?php echo $redis_status['active_databases']; ?></div>
                            <div class="stat-label">Active DBs</div>
                        </div>
                    </div>
                    
                    <p style="font-size: 0.9rem; color: #4a5568; text-align: center;">
                        Memory: <?php echo formatBytes($redis_status['used_memory']); ?> | 
                        Clients: <?php echo $redis_status['connected_clients']; ?> | 
                        Version: <?php echo $redis_status['version']; ?>
                    </p>
                <?php elseif (isset($redis_status['error'])): ?>
                    <p style="color: #e53e3e; font-size: 0.9rem;"><?php echo htmlspecialchars($redis_status['error']); ?></p>
                <?php endif; ?>
                
                <div class="cache-links">
                    <a href="/redis-status.php?direct=1" class="btn btn-primary" target="_blank">
                        📊 Manage Redis
                    </a>
                </div>
            </div>
        </div>
        
        <div class="grid">
            <div class="card">
                <h2>🌐 Quick Links</h2>
                <div class="quick-links">
                    <a href="http://phpmyadmin.local" class="quick-link" target="_blank">phpMyAdmin</a>
                    <a href="http://sample1.local" class="quick-link" target="_blank">Sample Site 1</a>
                    <a href="http://sample2.local" class="quick-link" target="_blank">Sample Site 2</a>
                    <a href="http://sample3.local" class="quick-link" target="_blank">Sample Site 3</a>
                    <a href="/cache-management-scripts/" class="quick-link admin-link" target="_blank">🛠️ Cache Management Scripts</a>
                </div>
            </div>
            
            <div class="card">
                <h2>📝 Hosts File Status</h2>
                
                <div class="hosts-status <?php echo $hosts_permissions['success'] ? 'success' : 'error'; ?>">
                    <?php echo $hosts_permissions['message']; ?>
                </div>
                
                <?php if (!empty($hosts_entries)): ?>
                    <h3 style="margin-bottom: 10px; color: #2d3748;">Current .local domains:</h3>
                    <div class="hosts-entries">
                        <?php foreach ($hosts_entries as $entry): ?>
                            <div class="hosts-entry">127.0.0.1 <?php echo htmlspecialchars($entry); ?></div>
                        <?php endforeach; ?>
                    </div>
                <?php else: ?>
                    <p style="color: #718096; font-style: italic;">No .local domains found in hosts file</p>
                <?php endif; ?>
            </div>
        </div>
        
        <div class="grid">
            <div class="card">
                <h2>➕ Add New Virtual Host</h2>
                <form method="post">
                    <input type="hidden" name="action" value="add_site">
                    
                    <div class="form-group">
                        <label for="site_name">Site Name</label>
                        <input type="text" id="site_name" name="site_name" required placeholder="My Awesome Site">
                    </div>
                    
                    <div class="form-group">
                        <label for="site_domain">Domain</label>
                        <input type="text" id="site_domain" name="site_domain" required placeholder="mysite.local" onchange="checkLocalDomain(this.value)">
                        <div class="domain-hint">Use .local for local development domains</div>
                        <div id="local-domain-info" class="local-domain-info" style="display: none;">
                            ℹ️ This .local domain will be automatically added to your hosts file (127.0.0.1)
                        </div>
                    </div>
                    
                    <div class="form-group">
                        <label for="database_name">Database Name (Optional)</label>
                        <input type="text" id="database_name" name="database_name" placeholder="mysite_db">
                    </div>
                    
                    <div class="form-group">
                        <div class="checkbox-group">
                            <input type="checkbox" id="ssl_enabled" name="ssl_enabled">
                            <label for="ssl_enabled">Enable SSL/HTTPS</label>
                        </div>
                    </div>
                    
                    <button type="submit" class="btn btn-primary" style="width: 100%;">Add Virtual Host</button>
                </form>
            </div>
            
            <div class="card">
                <h2>🏠 Managed Virtual Hosts</h2>
                <?php foreach ($sites as $site): ?>
                    <div class="site-item <?php echo in_array($site['domain'], ['dashboard.local', 'phpmyadmin.local']) ? 'protected-site' : ''; ?>">
                        <div class="site-info">
                            <h3>
                                <?php echo htmlspecialchars($site['name']); ?>
                                <?php if (in_array($site['domain'], ['dashboard.local', 'phpmyadmin.local'])): ?>
                                    <span class="protected-badge">PROTECTED</span>
                                <?php endif; ?>
                                <?php if (isLocalDomain($site['domain'])): ?>
                                    <span class="local-badge">.local</span>
                                <?php endif; ?>
                            </h3>
                            <p><?php echo htmlspecialchars($site['domain']); ?></p>
                            <?php if ($site['database_name']): ?>
                                <p style="font-size: 0.8rem; color: #4299e1;">DB: <?php echo htmlspecialchars($site['database_name']); ?></p>
                            <?php endif; ?>
                        </div>
                        <div class="site-actions">
                            <span class="status-badge status-<?php echo $site['status']; ?>">
                                <?php echo $site['status']; ?>
                            </span>
                            
                            <form method="post" style="display: inline;">
                                <input type="hidden" name="action" value="toggle_status">
                                <input type="hidden" name="site_id" value="<?php echo $site['id']; ?>">
                                <button type="submit" class="btn btn-secondary">Toggle</button>
                            </form>
                            
                            <a href="http://<?php echo $site['domain']; ?>" target="_blank" class="btn btn-primary">Visit</a>
                            
                            <?php if (!in_array($site['domain'], ['dashboard.local', 'phpmyadmin.local'])): ?>
                                <button onclick="confirmRemove(<?php echo $site['id']; ?>, '<?php echo htmlspecialchars($site['name']); ?>', '<?php echo htmlspecialchars($site['domain']); ?>')" class="btn btn-danger">Remove</button>
                            <?php endif; ?>
                        </div>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>
        
        <div class="card">
            <h2>📝 Recent Activity</h2>
            <?php foreach ($logs as $log): ?>
                <div class="log-item">
                    <strong><?php echo htmlspecialchars($log['site_name'] ?? 'System'); ?></strong>: 
                    <?php echo htmlspecialchars($log['action']); ?>
                    <?php if ($log['details']): ?>
                        <br><small><?php echo htmlspecialchars($log['details']); ?></small>
                    <?php endif; ?>
                    <div class="log-time"><?php echo date('M j, Y g:i A', strtotime($log['timestamp'])); ?></div>
                </div>
            <?php endforeach; ?>
        </div>
    </div>

    <!-- Remove Site Modal -->
    <div id="removeModal" class="modal">
        <div class="modal-content">
            <span class="close">&times;</span>
            <h2>⚠️ Confirm Removal</h2>
            <p>Are you sure you want to remove <strong id="siteName"></strong>?</p>
            <p id="localDomainWarning" style="color: #e53e3e; margin-top: 10px; display: none;">
                This .local domain will also be removed from your hosts file.
            </p>
            <p style="color: #e53e3e; margin-top: 10px;">This action cannot be undone. The site directory and database will need to be manually removed.</p>
            
            <form method="post" style="margin-top: 20px;">
                <input type="hidden" name="action" value="remove_site">
                <input type="hidden" name="site_id" id="removeSiteId">
                <div style="display: flex; gap: 10px; justify-content: flex-end;">
                    <button type="button" onclick="closeModal()" class="btn btn-secondary">Cancel</button>
                    <button type="submit" class="btn btn-danger">Remove Site</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        function checkLocalDomain(domain) {
            const info = document.getElementById('local-domain-info');
            if (domain.endsWith('.local')) {
                info.style.display = 'block';
            } else {
                info.style.display = 'none';
            }
        }
        
        function confirmRemove(siteId, siteName, domain) {
            document.getElementById('removeSiteId').value = siteId;
            document.getElementById('siteName').textContent = siteName;
            
            const localWarning = document.getElementById('localDomainWarning');
            if (domain.endsWith('.local')) {
                localWarning.style.display = 'block';
            } else {
                localWarning.style.display = 'none';
            }
            
            document.getElementById('removeModal').style.display = 'block';
        }
        
        function closeModal() {
            document.getElementById('removeModal').style.display = 'none';
        }
        
        // Close modal when clicking outside
        window.onclick = function(event) {
            const modal = document.getElementById('removeModal');
            if (event.target == modal) {
                modal.style.display = 'none';
            }
        }
        
        // Close modal with X button
        document.querySelector('.close').onclick = closeModal;
        
        // Auto-refresh cache status every 30 seconds
        setInterval(function() {
            // Only refresh if no modals are open
            if (document.getElementById('removeModal').style.display !== 'block') {
                location.reload();
            }
        }, 30000);
    </script>
</body>
</html>
