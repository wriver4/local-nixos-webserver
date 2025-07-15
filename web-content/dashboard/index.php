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
                            // Insert new site
                            $stmt = $pdo->prepare("INSERT INTO sites (name, domain, database_name, ssl_enabled) VALUES (?, ?, ?, ?)");
                            $stmt->execute([$name, $domain, $database_name ?: null, $ssl_enabled]);
                            $site_id = $pdo->lastInsertId();
                            
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
                            
                            // Add to /etc/hosts
                            $hosts_entry = "127.0.0.1 {$domain}\n";
                            file_put_contents('/etc/hosts', $hosts_entry, FILE_APPEND | LOCK_EX);
                            
                            $log_stmt = $pdo->prepare("INSERT INTO logs (site_id, action, details) VALUES (?, 'Site added', 'New virtual host created: {$domain}')");
                            $log_stmt->execute([$site_id]);
                            
                            if (empty($message)) {
                                $message = 'Site added successfully! Remember to rebuild NixOS configuration.';
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
                                // Remove from database
                                $delete_stmt = $pdo->prepare("DELETE FROM sites WHERE id = ?");
                                $delete_stmt->execute([$site_id]);
                                
                                // Log the removal
                                $log_stmt = $pdo->prepare("INSERT INTO logs (site_id, action, details) VALUES (NULL, 'Site removed', 'Virtual host removed: {$site['domain']}')");
                                $log_stmt->execute();
                                
                                // Remove from /etc/hosts
                                $hosts_content = file_get_contents('/etc/hosts');
                                $hosts_content = preg_replace("/127\.0\.0\.1\s+{$site['domain']}\n?/", '', $hosts_content);
                                file_put_contents('/etc/hosts', $hosts_content);
                                
                                $message = 'Site removed successfully! Remember to rebuild NixOS configuration and manually remove the directory if needed.';
                                $message_type = 'success';
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
if (isset($pdo)) {
    $sites = $pdo->query("SELECT * FROM sites ORDER BY created_at DESC")->fetchAll(PDO::FETCH_ASSOC);
    $logs = $pdo->query("SELECT l.*, s.name as site_name FROM logs l LEFT JOIN sites s ON l.site_id = s.id ORDER BY l.timestamp DESC LIMIT 15")->fetchAll(PDO::FETCH_ASSOC);
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
            <p>Manage your NixOS web server with nginx, PHP-FPM, MySQL and Virtual Host Management</p>
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
                <h2>🌐 Quick Links</h2>
                <div class="quick-links">
                    <a href="http://phpmyadmin.local" class="quick-link" target="_blank">phpMyAdmin</a>
                    <a href="http://sample1.local" class="quick-link" target="_blank">Sample Site 1</a>
                    <a href="http://sample2.local" class="quick-link" target="_blank">Sample Site 2</a>
                    <a href="http://sample3.local" class="quick-link" target="_blank">Sample Site 3</a>
                </div>
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
                        <input type="text" id="site_domain" name="site_domain" required placeholder="mysite.local">
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
                                <button onclick="confirmRemove(<?php echo $site['id']; ?>, '<?php echo htmlspecialchars($site['name']); ?>')" class="btn btn-danger">Remove</button>
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
        function confirmRemove(siteId, siteName) {
            document.getElementById('removeSiteId').value = siteId;
            document.getElementById('siteName').textContent = siteName;
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
    </script>
</body>
</html>
